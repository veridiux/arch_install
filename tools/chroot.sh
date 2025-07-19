#!/bin/bash
set -e

echo "🔧 Auto Chroot Tool (Arch Linux)"
echo "1) Chroot into system"
echo "2) Unmount and clean up"
read -rp "Select option [1-2]: " OPTION

# Helper: Check if device is NVMe or SATA
detect_partitions() {
  if lsblk | grep -q "nvme0n1p"; then
    echo "Detected NVMe drive"
    BOOT_PART="/dev/nvme0n1p1"
    ROOT_PART="/dev/nvme0n1p2"
  elif lsblk | grep -q "sda"; then
    echo "Detected SATA/ATA drive"
    BOOT_PART="/dev/sda1"
    ROOT_PART="/dev/sda2"
  else
    echo "❌ Could not detect root partition."
    exit 1
  fi
}

# Mount logic
do_chroot() {
  detect_partitions

  echo "🔍 Mounting $ROOT_PART to /mnt (initial)"
  mount "$ROOT_PART" /mnt

  # Check for Btrfs
  FS_TYPE=$(lsblk -no FSTYPE "$ROOT_PART")
  if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo "📦 Detected Btrfs filesystem"

    if btrfs subvolume list /mnt | grep -q "path @"; then
      echo "✅ Found subvolume '@', remounting with subvol=@"
      umount /mnt
      mount -o subvol=@ "$ROOT_PART" /mnt
    else
      echo "ℹ️ No '@' subvolume found, using root of Btrfs volume"
    fi
  fi

  mkdir -p /mnt/boot
  echo "🔍 Mounting boot partition ($BOOT_PART)"
  mount "$BOOT_PART" /mnt/boot

  echo "🔗 Binding system directories..."
  mount --types proc /proc /mnt/proc
  mount --rbind /sys /mnt/sys
  mount --make-rslave /mnt/sys
  mount --rbind /dev /mnt/dev
  mount --make-rslave /mnt/dev
  mount --bind /run /mnt/run

  echo "✅ Environment prepared. Entering chroot..."

  # Get installed hostname (used to confirm chroot)
  INSTALLED_HOSTNAME=$(chroot /mnt hostnamectl status --static 2>/dev/null)

  # Enter chroot shell
  chroot /mnt /bin/bash

  echo "🧪 Checking if chroot was successful..."
  if [[ "$INSTALLED_HOSTNAME" != "archiso" && -n "$INSTALLED_HOSTNAME" ]]; then
    echo "✅ You were inside your installed system with hostname: $INSTALLED_HOSTNAME"
  else
    echo "⚠️ The chroot environment looks like the live ISO or hostname is not set."
  fi
}

# Unmounting
do_unmount() {
  echo "🔻 Unmounting all partitions..."
  umount -R /mnt || echo "⚠️ Some mounts failed to unmount"
  echo "✅ All cleaned up."
}

# Menu choice
case "$OPTION" in
  1) do_chroot ;;
  2) do_unmount ;;
  *) echo "❌ Invalid option." && exit 1 ;;
esac
