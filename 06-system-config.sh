#!/bin/bash
set -e

# Load your config variables (ROOT_PART, HOSTNAME, TIMEZONE, LOCALE, ENABLE_MULTILIB, BOOTLOADER, FIRMWARE_MODE, DRIVE)
source ./config.sh

# Export variables so they are available inside the heredoc in arch-chroot
export ROOT_PART HOSTNAME TIMEZONE LOCALE ENABLE_MULTILIB BOOTLOADER FIRMWARE_MODE DRIVE

echo "🛠️ Entering chroot environment to configure system..."





# --- Hostname ---
DEFAULT_HOSTNAME="Archlinux"
read -rp "❓ What is your hostname? [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
echo "$HOSTNAME" > /mnt/etc/hostname

# --- Timezone ---
DEFAULT_TIMEZONE="America/Chicago"
read -rp "🌍 What is your timezone? [$DEFAULT_TIMEZONE]: " TIMEZONE
TIMEZONE=${TIMEZONE:-$DEFAULT_TIMEZONE}
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime

# --- Locale ---
DEFAULT_LOCALE="en_US"
read -rp "🗣️ What locale do you want to use? [$DEFAULT_LOCALE]: " LOCALE
LOCALE=${LOCALE:-$DEFAULT_LOCALE}
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /mnt/etc/locale.gen
echo "LANG=${LOCALE}.UTF-8" > /mnt/etc/locale.conf

# --- Keyboard Layout ---
DEFAULT_KEYMAP="us"
read -rp "⌨️ What keyboard layout do you want? [$DEFAULT_KEYMAP]: " KEYMAP
KEYMAP=${KEYMAP:-$DEFAULT_KEYMAP}
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf

# --- Enable multilib repo ---
read -rp "📦 Enable multilib repo? [y/N]: " MULTILIB_CHOICE
MULTILIB_CHOICE=${MULTILIB_CHOICE:-n}
ENABLE_MULTILIB="$MULTILIB_CHOICE"

if [[ "$ENABLE_MULTILIB" =~ ^[Yy]$ ]]; then
  sed -i '/^\s*#\s*\[multilib\]/,/^$/{s/^#//}' /mnt/etc/pacman.conf
  echo "✅ Multilib repo enabled (will sync on first pacman run in chroot)."
fi

# Save configuration for later use
cat > config.sh <<EOF
ROOT_PART="$ROOT_PART"
HOSTNAME="$HOSTNAME"
TIMEZONE="$TIMEZONE"
LOCALE="$LOCALE"
KEYMAP="$KEYMAP"
ENABLE_MULTILIB="$ENABLE_MULTILIB"
BOOTLOADER="$BOOTLOADER"
FIRMWARE_MODE="$FIRMWARE_MODE"
DRIVE="$DRIVE"
EOF



# Save to config
echo "ENABLE_MULTILIB=\"$ENABLE_MULTILIB\"" >> config.sh





arch-chroot /mnt /bin/bash <<'EOF'

# --- Optiona: sync packages after anbling multilib ---
if [[ "$ENABLE_MULTILIB" =~ ^[Yy]$ ]]; then
  echo "🔄 Updating system (multilib enabled)..."
  pacman -Syu --noconfirm
fi


# --- Locale & Clock (deferred to chroot) ---
locale-gen
hwclock --systohc


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

#   echo "⚙️ Installing systemd-boot..."

#   # Ensure efivarfs is mounted
#   if ! mountpoint -q /sys/firmware/efi/efivars; then
#     echo "🔧 Mounting efivarfs..."
#     mount -t efivarfs efivarfs /sys/firmware/efi/efivars
#   fi

#   bootctl install || {
#     echo "❌ bootctl install failed."
#     exit 1
#   }

#   echo "📝 Creating systemd-boot configuration..."
#   mkdir -p /boot/loader/entries

#   cat > /boot/loader/loader.conf <<LOADER
# default arch
# timeout 3
# editor no
# LOADER

#   PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PART")"
#   cat > /boot/loader/entries/arch.conf <<ENTRY
# title   Arch Linux
# linux   /vmlinuz-linux
# initrd  /initramfs-linux.img
# options root=PARTUUID=$PARTUUID rw
# ENTRY

#   echo "💡 Configuring UEFI boot entry..."

#   ESP_PART=$(findmnt -no SOURCE /boot/efi || findmnt -no SOURCE /boot)
#   if [[ -z "$ESP_PART" ]]; then
#     echo "❌ Could not determine ESP partition."
#     exit 1
#   fi
















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

# Detect if root partition is Btrfs
FS_TYPE="$(blkid -s TYPE -o value "$ROOT_PART")"

# Set default rootflags (empty)
ROOTFLAGS=""

if [[ "$FS_TYPE" == "btrfs" ]]; then
  # Adjust this to your actual subvolume name
  SUBVOL="@"
  ROOTFLAGS="rootflags=subvol=$SUBVOL"
  echo "ℹ️ Detected Btrfs root, adding rootflags=subvol=$SUBVOL"
fi

cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$PARTUUID rw $ROOTFLAGS
ENTRY

echo "💡 Configuring UEFI boot entry..."

ESP_PART=$(findmnt -no SOURCE /boot/efi || findmnt -no SOURCE /boot)
if [[ -z "$ESP_PART" ]]; then
  echo "❌ Could not determine ESP partition."
  exit 1
fi










  ESP_DISK=$(lsblk -no PKNAME "$ESP_PART" | head -n1)

  # Extract partition number from ESP_PART
  ESP_PART_BASENAME=$(basename "$ESP_PART")  # e.g., sda1
  ESP_PART_NUM="${ESP_PART_BASENAME//[!0-9]/}"  # Strip non-digits


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
