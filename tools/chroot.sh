#!/bin/bash
set -e

echo "🔧 Auto Chroot Tool (Arch Linux)"
echo "1) Chroot into system"
echo "2) Unmount and clean up"
read -rp "Select option [1-2]: " OPTION

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

do_chroot() {
  detect_root_partition

  FS_TYPE=$(blkid -o value -s TYPE "$ROOT_PART")

  echo "📦 Filesystem on root: $FS_TYPE"

  mkdir -p /mnt

  if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo "🔍 Mounting Btrfs root temporarily to inspect subvolumes..."
    mount "$ROOT_PART" /mnt
    if btrfs subvolume list /mnt | grep -q "path @"; then
      echo "✅ Subvolume @ found. Re-mounting with subvol=@"
      umount /mnt
      mount -o subvol=@ "$ROOT_PART" /mnt
    else
      echo "⚠️ Subvolume @ not found. Using full Btrfs root."
      # Already mounted
    fi
  else
    echo "🔍 Mounting root (non-Btrfs)"
    mount "$ROOT_PART" /mnt
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

  INSTALLED_HOSTNAME=$(chroot /mnt hostnamectl status --static 2>/dev/null)
  chroot /mnt /bin/bash

  echo "🧪 Checking if chroot was successful..."
  if [[ "$INSTALLED_HOSTNAME" != "archiso" && -n "$INSTALLED_HOSTNAME" ]]; then
    echo "✅ You were inside your installed system with hostname: $INSTALLED_HOSTNAME"
  else
    echo "⚠️ The chroot environment looks like the live environment or hostname is empty."
  fi
}

do_unmount() {
  echo "🔻 Unmounting all partitions..."
  umount -R /mnt || echo "⚠️ Some mounts failed to unmount"
  echo "✅ All cleaned up."
}

case "$OPTION" in
  1) do_chroot ;;
  2) do_unmount ;;
  *) echo "❌ Invalid option." && exit 1 ;;
esac
