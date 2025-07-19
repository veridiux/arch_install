#!/bin/bash
set -e

echo "🔧 Auto Chroot Tool (Arch Linux)"
echo "1) Chroot into system"
echo "2) Unmount and clean up"
read -rp "Select option [1-2]: " OPTION

# Helper: Check if device is NVMe or standard
detect_root_partition() {
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

# Helper: Mount and chroot
do_chroot() {
  detect_root_partition

  echo "🔍 Mounting $ROOT_PART to /mnt"
  mount "$ROOT_PART" /mnt

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
  chroot /mnt /bin/bash

  echo "🧪 Checking if chroot was successful..."
  if [[ "$(hostnamectl status 2>/dev/null | grep -i 'Static hostname')" != *archiso* ]]; then
    echo "✅ You are now in your installed system!"
  else
    echo "⚠️ Still in live environment. Chroot may have failed."
  fi
}

# Helper: Unmount
do_unmount() {
  echo "🔻 Unmounting all partitions..."
  umount -R /mnt || echo "⚠️ Some mounts failed to unmount"
  echo "✅ All cleaned up."
}

# Execute selected option
case "$OPTION" in
  1)
    do_chroot
    ;;
  2)
    do_unmount
    ;;
  *)
    echo "❌ Invalid option."
    exit 1
    ;;
esac
