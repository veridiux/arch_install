#!/bin/bash
set -euo pipefail

echo "🔧 Arch Auto-Chroot Tool"

# Let user choose action
PS3="Choose an option: "
options=("Chroot into system" "Unmount and exit" "Quit")
select opt in "${options[@]}"; do
  case $opt in
    "Chroot into system")
      break
      ;;
    "Unmount and exit")
      echo "📦 Unmounting /mnt..."
      umount -R /mnt && echo "✅ Unmounted successfully." || echo "⚠️ Failed to unmount /mnt."
      exit 0
      ;;
    "Quit")
      exit 0
      ;;
    *)
      echo "❌ Invalid option."
      ;;
  esac
done

echo "🔍 Detecting Linux root partition..."

# Try to auto-detect Linux root partition
ROOT_PART=$(lsblk -rpno NAME,MOUNTPOINT,FSTYPE | grep -E "ext4|btrfs|xfs" | grep -v "boot\|efi" | awk '!/\/mnt/{print $1}' | head -n 1)

if [[ -z "$ROOT_PART" ]]; then
  echo "❌ Could not auto-detect root partition. Please enter it manually (e.g. /dev/sda3 or /dev/nvme0n1p3):"
  read -r ROOT_PART
fi

echo "🔧 Mounting root: $ROOT_PART"
mount "$ROOT_PART" /mnt

# Optional: Try to mount boot and EFI if they exist
echo "🔍 Checking for separate boot or EFI partitions..."
for part in $(lsblk -rpno NAME,FSTYPE | grep -Ei 'fat|vfat|boot' | awk '{print $1}'); do
  if blkid "$part" | grep -qi efi; then
    echo "🧷 Mounting EFI partition: $part"
    mkdir -p /mnt/boot/efi
    mount "$part" /mnt/boot/efi
  elif blkid "$part" | grep -qi boot; then
    echo "🧷 Mounting boot partition: $part"
    mkdir -p /mnt/boot
    mount "$part" /mnt/boot
  fi
done

# Optional: Try mounting home
HOME_PART=$(lsblk -rpno NAME,MOUNTPOINT,FSTYPE | grep -i home | awk '{print $1}')
if [[ -n "$HOME_PART" ]]; then
  echo "🏠 Mounting home: $HOME_PART"
  mkdir -p /mnt/home
  mount "$HOME_PART" /mnt/home
fi

# Bind special filesystems
for dir in dev proc sys run; do
  mount --bind /$dir /mnt/$dir
done

# Enter chroot
echo "🚪 Entering chroot..."
chroot /mnt /bin/bash

# After exit
echo "📦 Cleaning up..."
for dir in dev proc sys run; do
  umount -lf /mnt/$dir || true
done
umount -R /mnt || true
echo "✅ Unmounted. Chroot session complete."
