#!/bin/bash
set -e

echo "🔧 Auto Chroot Tool (Arch Linux)"
echo "1) Chroot into system"
echo "2) Unmount and clean up"
read -rp "Select option [1-2]: " OPTION

BOOT_PART=""
ROOT_PART=""
IS_BTRFS=false
IS_UEFI=false

# Detect partitions based on device
detect_partitions() {
  if lsblk | grep -q "nvme0n1p"; then
    echo "📦 Detected NVMe drive"
    BOOT_PART="/dev/nvme0n1p1"
    ROOT_PART="/dev/nvme0n1p2"
  elif lsblk | grep -q "sda"; then
    echo "📦 Detected SATA/ATA drive"
    BOOT_PART="/dev/sda1"
    ROOT_PART="/dev/sda2"
  else
    echo "❌ Could not detect partitions"
    exit 1
  fi
}

# Detect if the system is UEFI
detect_firmware_type() {
  if [ -d /sys/firmware/efi ]; then
    IS_UEFI=true
    echo "🧭 UEFI system detected"
  else
    IS_UEFI=false
    echo "🧭 BIOS (Legacy) system detected"
  fi
}

# Check if Btrfs is used
detect_btrfs() {
  fstype=$(blkid -o value -s TYPE "$ROOT_PART")
  if [[ "$fstype" == "btrfs" ]]; then
    IS_BTRFS=true
    echo "📁 Btrfs filesystem detected on root"
  else
    IS_BTRFS=false
    echo "📁 Filesystem: $fstype"
  fi
}

mount_root() {
  echo "🔍 Probing root partition ($ROOT_PART)"

  mkdir -p /mnt

  if $IS_BTRFS; then
    echo "📦 Mounting temporarily to probe Btrfs subvolumes"
    mount "$ROOT_PART" /mnt

    echo "📋 Available Btrfs subvolumes:"
    btrfs subvolume list /mnt

    # Check for @ subvolume
    if btrfs subvolume list /mnt | grep -q " path @\$"; then
      echo "✅ Found subvolume @ — remounting properly"
      umount /mnt
      mount -o subvol=@ "$ROOT_PART" /mnt
    else
      echo "⚠️ Subvolume @ not found. Mounting root as-is"
      # Keep it mounted to /mnt as root
    fi
  else
    echo "📦 Mounting non-Btrfs root"
    mount "$ROOT_PART" /mnt
  fi
}


# Mount /boot and /boot/efi accordingly
mount_boot() {
  mkdir -p /mnt/boot

  if $IS_UEFI; then
    mkdir -p /mnt/boot/efi
    echo "🔍 Mounting EFI partition ($BOOT_PART) to /mnt/boot/efi"
    mount "$BOOT_PART" /mnt/boot/efi
  else
    echo "🔍 Mounting boot partition ($BOOT_PART) to /mnt/boot"
    mount "$BOOT_PART" /mnt/boot
  fi
}

# Perform the chroot
do_chroot() {
  detect_partitions
  detect_firmware_type
  detect_btrfs
  mount_root
  mount_boot

  echo "🔗 Binding system directories..."
  mount --types proc /proc /mnt/proc
  mount --rbind /sys /mnt/sys
  mount --make-rslave /mnt/sys
  mount --rbind /dev /mnt/dev
  mount --make-rslave /mnt/dev
  mount --bind /run /mnt/run

  echo "✅ Environment prepared. Entering chroot..."

  INSTALLED_HOSTNAME=$(chroot /mnt hostnamectl status --static 2>/dev/null || echo "unknown")

  chroot /mnt /bin/bash

  echo "🧪 Chroot exited. Hostname inside was: $INSTALLED_HOSTNAME"
  if [[ "$INSTALLED_HOSTNAME" != "archiso" && -n "$INSTALLED_HOSTNAME" ]]; then
    echo "✅ You were inside your installed system!"
  else
    echo "⚠️ Chroot may not have entered the installed system."
  fi
}

# Cleanup
do_unmount() {
  echo "🔻 Unmounting all partitions from /mnt"
  umount -R /mnt || echo "⚠️ Some mounts failed to unmount"
  echo "✅ All cleaned up."
}

# Run
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
