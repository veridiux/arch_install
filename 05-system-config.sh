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
sed -i "s/#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# --- Keymap ---
echo "KEYMAP=us" > /etc/vconsole.conf

# --- Multilib (Optional) ---
if [ "$ENABLE_MULTILIB" = "true" ]; then
  echo "📦 Enabling multilib repository..."
  sed -i '/#\\[multilib\\]/,/#Include/ s/^#//' /etc/pacman.conf
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
echo "💻 Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

echo "📝 Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "✅ System configuration complete."
