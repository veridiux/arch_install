#!/bin/bash
set -e

source ./config.sh

echo "🛠️ Entering chroot environment to configure system..."

arch-chroot /mnt /bin/bash <<'EOF'

# --- Hostname ---
echo "🖥️ Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# --- Timezone ---
echo "🌐 Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# --- Locale ---
echo "🗣️ Configuring locale..."
sed -i "s/^#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# --- Keymap ---
echo "KEYMAP=us" > /etc/vconsole.conf

# --- Multilib (Optional) ---
if [ "$ENABLE_MULTILIB" = "true" ]; then
  echo "📦 Enabling multilib repository..."
  sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
  pacman -Sy
else
  echo "⏭️ Skipping multilib repository setup."
fi

# --- Initramfs ---
echo "🧰 Rebuilding initramfs..."
mkinitcpio -P

# --- Root password ---
echo "🔐 Set root password:"
passwd

# --- Bootloader ---
echo "💻 Installing bootloader: $BOOTLOADER..."

if [ "$BOOTLOADER" = "grub" ]; then

  command -v grub-install >/dev/null || {
    echo "❌ grub-install not found!"
    exit 1
  }

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    echo "🔧 Installing GRUB for UEFI..."
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  else
    echo "🔧 Installing GRUB for BIOS..."
    grub-install --target=i386-pc "$DRIVE"
  fi

  echo "📝 Generating GRUB configuration..."
  grub-mkconfig -o /boot/grub/grub.cfg

elif [ "$BOOTLOADER" = "systemd-boot" ]; then

  if [ "$FIRMWARE_MODE" != "UEFI" ] || [ ! -d /sys/firmware/efi ]; then
    echo "❌ systemd-boot is only supported on UEFI systems."
    exit 1
  fi

  echo "⚙️ Installing systemd-boot..."

  # Ensure efivarfs is mounted
  if ! mountpoint -q /sys/firmware/efi/efivars; then
    echo "🔧 Mounting efivarfs..."
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
  fi

  bootctl install || {
    echo "❌ bootctl install failed."
    exit 1
  }

  echo "📝 Creating systemd-boot configuration..."
  mkdir -p /boot/loader/entries

  cat > /boot/loader/loader.conf <<LOADER
default arch
timeout 3
editor no
LOADER

  PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PART")"
  cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$PARTUUID rw
ENTRY

  echo "💡 Configuring UEFI boot entry..."

  ESP_PART=$(findmnt -no SOURCE /boot/efi || findmnt -no SOURCE /boot)
  if [[ -z "$ESP_PART" ]]; then
    echo "❌ Could not determine ESP partition."
    exit 1
  fi

  ESP_DISK=$(lsblk -no PKNAME "$ESP_PART" | head -n1)
  ESP_PART_NUM=$(lsblk -no PARTNUM "$ESP_PART" | head -n1)

  if [[ -z "$ESP_DISK" || -z "$ESP_PART_NUM" ]]; then
    echo "❌ Failed to extract disk or partition number for efibootmgr."
    echo "ESP_PART=$ESP_PART"
    lsblk
    exit 1
  fi

  efibootmgr --create \
    --disk "/dev/$ESP_DISK" \
    --part "$ESP_PART_NUM" \
    --label "Linux Boot Manager" \
    --loader '\EFI\systemd\systemd-bootx64.efi' || {
      echo "❌ efibootmgr failed to create boot entry."
      exit 1
    }

  # (Optional) Secure /boot/efi to silence random seed warnings
  chmod o-rwx /boot/efi || true

  echo "✅ systemd-boot installed and configured."

else
  echo "❌ Unknown bootloader: $BOOTLOADER"
  exit 1
fi

EOF

echo "✅ System configuration complete."
