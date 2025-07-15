#!/bin/bash
set -e

# === CONFIGURE THESE ===
ROOT_PART="/dev/sdX2"     # ← Your root partition
EFI_PART="/dev/sdX1"      # ← Your EFI/boot partition
HOME_PART=""              # ← Optional: /dev/sdX3
SWAP_PART=""              # ← Optional: /dev/sdX4

# === DO NOT EDIT BELOW UNLESS NEEDED ===
echo "🔧 Mounting root partition..."
mount "$ROOT_PART" /mnt

echo "🔧 Mounting EFI partition..."
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

if [[ -n "$HOME_PART" ]]; then
  echo "🔧 Mounting /home partition..."
  mkdir -p /mnt/home
  mount "$HOME_PART" /mnt/home
fi

if [[ -n "$SWAP_PART" ]]; then
  echo "💾 Enabling swap..."
  swapon "$SWAP_PART"
fi

echo "🔧 Mounting system files..."
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev
mount --bind /run /mnt/run || true  # in case /run is tmpfs

echo "🚪 Entering chroot..."
arch-chroot /mnt
