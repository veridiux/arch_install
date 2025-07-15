#!/bin/bash
set -e

source ./config.sh

echo "🛠️ Entering chroot environment to configure system..."

arch-chroot /mnt /bin/bash <<EOF

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
  sed -i '/\\[multilib\\]/,/Include/ s/^#//' /etc/pacman.conf
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
if [ "$BOOTLOADER" = "grub" ]; then
  echo "💻 Installing GRUB bootloader..."

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  else
    grub-install --target=i386-pc $DRIVE
  fi

  echo "📝 Generating GRUB config..."
  grub-mkconfig -o /boot/grub/grub.cfg

elif [ "$BOOTLOADER" = "systemd-boot" ]; then
  if [ "$FIRMWARE_MODE" != "UEFI" ]; then
    echo "❌ systemd-boot is only supported on UEFI systems."
    exit 1
  fi

  echo "⚙️ Installing systemd-boot bootloader..."
  bootctl install

  echo "🔧 Creating loader.conf..."
  mkdir -p /boot/loader
  cat <<LOADER > /boot/loader/loader.conf
default arch
timeout 3
editor no
LOADER

  echo "🔧 Creating arch.conf..."
  mkdir -p /boot/loader/entries
  PARTUUID=\$(blkid -s PARTUUID -o value $ROOT_PART)
  cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$PARTUUID rw
ENTRY

else
  echo "❌ Unknown bootloader: \$BOOTLOADER"
  exit 1
fi

EOF

echo "✅ System configuration complete."
