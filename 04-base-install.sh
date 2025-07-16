#!/bin/bash
set -e

source ./config.sh

echo "📦 Installing Arch base system..."

# Ask user to confirm or modify base packages
DEFAULT_BASE_PACKAGES=("base" "linux" "linux-firmware" "vim" "nano" "networkmanager" "sudo")

# Set bootloader package based on config
case "$BOOTLOADER" in
  grub)
    DEFAULT_BASE_PACKAGES+=("grub" "efibootmgr")
    ;;
  systemd-boot|systems)
    DEFAULT_BASE_PACKAGES+=("systemd-boot" "efibootmgr")  # or "bootctl" if installing manually
    ;;
  *)
    echo "Unknown BOOTLOADER: $BOOTLOADER"
    exit 1
    ;;
esac

# Show result
echo "Final packages: ${DEFAULT_BASE_PACKAGES[@]}"






echo "🧱 Default base packages:"
printf '  - %s\n' "${DEFAULT_BASE_PACKAGES[@]}"

read -rp "➕ Do you want to add or remove packages from the list? [y/N]: " CUSTOMIZE_BASE

if [[ "$CUSTOMIZE_BASE" =~ ^[Yy]$ ]]; then
  read -rp "📋 Enter space-separated list of additional packages: " ADDITIONAL
  IFS=' ' read -r -a ADD_PACKAGES <<< "$ADDITIONAL"
  BASE_PACKAGES=("${DEFAULT_BASE_PACKAGES[@]}" "${ADD_PACKAGES[@]}")
else
  BASE_PACKAGES=("${DEFAULT_BASE_PACKAGES[@]}")
fi

echo "📦 Final package list:"
printf '  - %s\n' "${BASE_PACKAGES[@]}"

# Run pacstrap
echo "🚀 Installing base packages..."
pacstrap -K /mnt "${BASE_PACKAGES[@]}"

# Copy over config.sh and swap info if it exists
cp ./config.sh /mnt/root/
[[ -f ./swap.size ]] && cp ./swap.size /mnt/root/

# Generate fstab
echo "🧾 Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "✅ Base system installed and fstab generated."
echo "➡️ Ready to chroot in next step."
