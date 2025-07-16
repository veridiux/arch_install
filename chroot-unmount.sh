#!/bin/bash
set -e

# === CONFIGURE THESE to match your setup ===
ROOT_PART="/dev/sda2"
EFI_PART="/dev/sda1"
HOME_PART=""   # e.g. "/dev/sda3"
SWAP_PART=""   # e.g. "/dev/sda4"

# Make sure you have exited chroot before running this script!

if [[ -n "$SWAP_PART" ]]; then
  echo "💾 Disabling swap..."
  swapoff "$SWAP_PART" || echo "Swap already off or not active"
fi

echo "🔧 Unmounting /run..."
umount /mnt/run || true

echo "🔧 Unmounting /dev..."
umount -R /mnt/dev || true

echo "🔧 Unmounting /sys..."
umount -R /mnt/sys || true

echo "🔧 Unmounting /proc..."
umount /mnt/proc || true

if [[ -n "$HOME_PART" ]]; then
  echo "🔧 Unmounting /home..."
  umount /mnt/home || true
fi

echo "🔧 Unmounting EFI partition..."
umount /mnt/boot/efi || true

echo "🔧 Unmounting root partition..."
umount /mnt || true

echo "✅ All partitions and mounts have been unmounted."
