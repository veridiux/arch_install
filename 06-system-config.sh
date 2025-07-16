#!/bin/bash
set -e

# Load your config variables (ROOT_PART, HOSTNAME, TIMEZONE, LOCALE, ENABLE_MULTILIB, BOOTLOADER, FIRMWARE_MODE, DRIVE)
source ./config.sh

# Export variables so they are available inside the heredoc in arch-chroot
export ROOT_PART HOSTNAME TIMEZONE LOCALE ENABLE_MULTILIB BOOTLOADER FIRMWARE_MODE DRIVE

echo "🛠️ Entering chroot environment to configure system..."

arch-chroot /mnt /bin/bash <<EOF

detect_esp() {
  local esp_part
  esp_part="\$(findmnt -no SOURCE /boot/efi 2>/dev/null || true)"

  if [ -z "\$esp_part" ]; then
    echo "⚠️ /boot/efi not mounted. Attempting to find ESP partition..."

    esp_part=\$(blkid -t PARTTYPE="c12a7328-f81f-11d2-ba4b-00a0c93ec93b" -o device | head -n1)

    if [ -z "\$esp_part" ]; then
      esp_part=\$(blkid -L EFI || blkid -L ESP || true)
    fi

    if [ -z "\$esp_part" ]; then
      echo "❌ Could not detect ESP partition automatically."
      return 1
    fi

    if ! mountpoint -q /boot/efi; then
      echo "🔧 Mounting ESP partition \$esp_part at /boot/efi..."
      mkdir -p /boot/efi
      mount "\$esp_part" /boot/efi || {
        echo "❌ Failed to mount ESP partition."
        return 1
      }
    fi
  fi

  echo "\$esp_part"
}

# --- Hostname ---
echo "🖥️ Setting hostname..."
echo "\$HOSTNAME" > /etc/hostname

# --- Timezone ---
echo "🌐 Setting timezone..."
ln -sf /usr/share/zoneinfo/\$TIMEZONE /etc/localtime
hwclock --systohc

# --- Locale ---
echo "🗣️ Configuring locale..."
sed -i "s/^#\$LOCALE UTF-8/\$LOCALE UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=\$LOCALE" > /etc/locale.conf

# --- Keymap ---
echo "KEYMAP=us" > /etc/vconsole.conf

# --- Multilib (Optional) ---
if [ "\$ENABLE_MULTILIB" = "true" ]; then
  echo "📦 Enabling multilib repository..."
  sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
  pacman -Sy --noconfirm
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
if [ "\$BOOTLOADER" = "grub" ]; then
  echo "💻 Installing GRUB bootloader..."

  if [ "\$FIRMWARE_MODE" = "UEFI" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  else
    grub-install --target=i386-pc "\$DRIVE"
  fi

  echo "📝 Generating GRUB config..."
  grub-mkconfig -o /boot/grub/grub.cfg

elif [ "\$BOOTLOADER" = "systemd-boot" ]; then
  if [ "\$FIRMWARE_MODE" != "UEFI" ] || [ ! -d /sys/firmware/efi ]; then
    echo "❌ systemd-boot is only supported on UEFI systems."
    exit 1
  fi

  echo "⚙️ Installing systemd-boot bootloader..."

  if ! mountpoint -q /sys/firmware/efi/efivars; then
    echo "🔧 Mounting efivarfs..."
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
  fi

  bootctl install || {
    echo "❌ bootctl install failed."
    exit 1
  }

  echo "🔧 Creating loader.conf..."
  mkdir -p /boot/loader
  cat <<LOADER > /boot/loader/loader.conf
default arch
timeout 3
editor no
LOADER

  echo "🔧 Creating arch.conf..."
  mkdir -p /boot/loader/entries
  PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
  cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$PARTUUID rw
ENTRY

  echo "💡 Adding UEFI boot entry manually..."

  ESP_PART=\$(detect_esp)
  if [ -z "\$ESP_PART" ]; then
    echo "❌ detect_esp failed or returned empty result. Cannot continue."
    exit 1
  fi

  ESP_DISK="/dev/\$(lsblk -no PKNAME "\$ESP_PART")"

  if [ -z "\$ESP_DISK" ]; then
    echo "❌ Could not determine disk for ESP partition: \$ESP_PART"
    exit 1
  fi

  ESP_PART_NUM=\$(echo "\$ESP_PART" | sed -E 's/.*[p]?([0-9]+)$/\1/')

  if ! [[ "\$ESP_PART_NUM" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not extract partition number from \$ESP_PART"
    exit 1
  fi

  echo "ESP_PART = \$ESP_PART"
  echo "ESP_DISK = \$ESP_DISK"
  echo "ESP_PART_NUM = \$ESP_PART_NUM"

  efibootmgr --create --disk "\$ESP_DISK" --part "\$ESP_PART_NUM" \
    --label "Linux Boot Manager" \
    --loader '\\EFI\\systemd\\systemd-bootx64.efi' || {
      echo "❌ Failed to create UEFI boot entry with efibootmgr."
      exit 1
    }

  echo "✅ systemd-boot installed and UEFI entry created."

else
  echo "❌ Unknown bootloader: \$BOOTLOADER"
  exit 1
fi

EOF

echo "✅ System configuration complete."
