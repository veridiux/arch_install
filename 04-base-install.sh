#!/bin/bash

#read -rp "🔸 Starting script: $(basename "$0"). Press Enter to continue..."



set -e
trap 'echo "Error on line $LINENO"; exit 1' ERR

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
    DEFAULT_BASE_PACKAGES+=("systemd" "efibootmgr")  # or "bootctl" if installing manually
    ;;
  *)
    echo "Unknown BOOTLOADER: $BOOTLOADER"
    exit 1
    ;;
esac

# Pause here to inspect packages

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

# # Pause here to inspect packages
# echo "⏸️  Packages after bootloader selection:"
# printf '  - %s\n' "${BASE_PACKAGES[@]}"

# Copy over config.sh and swap info if it exists
cp ./config.sh /mnt/root/
[[ -f ./swap.size ]] && cp ./swap.size /mnt/root/

# Generate fstab
echo "🧾 Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab




# # --- Multilib (Optional) ---
# read -rp "📦 Do you want to enable the multilib repository? [y/N]: " MULTILIB_CHOICE
# MULTILIB_CHOICE=${MULTILIB_CHOICE:-n}

# if [[ "$MULTILIB_CHOICE" =~ ^[Yy]$ ]]; then
#   ENABLE_MULTILIB=true
#   echo "📦 Enabling multilib repository..."

#   # Uncomment the [multilib] section
#   sed -i '/^\s*#\s*\[multilib\]/s/^#//' /etc/pacman.conf

#   # Uncomment the Include line under [multilib]
#   sed -i '/^\s*#\s*Include\s*=.*\/etc\/pacman\.d\/mirrorlist/s/^#//' /etc/pacman.conf

#   # Refresh package database
#   # pacman -Sy

#   echo "✅ Multilib repository enabled."
# else
#   ENABLE_MULTILIB=false
#   echo "⏭️ Skipping multilib setup."
# fi


# Update package database
pacman -Sy

echo "✅ Base system installed and fstab generated."
echo "➡️ Ready to chroot in next step."
