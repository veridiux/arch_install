#!/bin/bash
set -e

# === CONFIGURE THESE ===
ROOT_PART="/dev/sda2"     # Your root partition (change as needed)
EFI_PART="/dev/sda1"      # Your EFI partition (change as needed)
BOOT_PART=""              # Optional: separate /boot partition, if any
HOME_PART=""              # Optional: /home partition, if any
SWAP_PART=""              # Optional: swap partition, if any

# === MOUNT ROOT ===
echo "🔧 Mounting root partition ($ROOT_PART)..."
mount "$ROOT_PART" /mnt

# === MOUNT BOOT & EFI ===
if [[ -n "$BOOT_PART" ]]; then
  echo "🔧 Mounting boot partition ($BOOT_PART)..."
  mkdir -p /mnt/boot
  mount "$BOOT_PART" /mnt/boot
fi

if [[ -n "$EFI_PART" ]]; then
  echo "🔧 Mounting EFI partition ($EFI_PART)..."
  mkdir -p /mnt/boot/efi
  mount "$EFI_PART" /mnt/boot/efi
fi

# === MOUNT HOME IF SET ===
if [[ -n "$HOME_PART" ]]; then
  echo "🔧 Mounting home partition ($HOME_PART)..."
  mkdir -p /mnt/home
  mount "$HOME_PART" /mnt/home
fi

# === ENABLE SWAP IF SET ===
if [[ -n "$SWAP_PART" ]]; then
  echo "💾 Enabling swap on $SWAP_PART..."
  swapon "$SWAP_PART"
fi

# === MOUNT SYSTEM FILESYSTEMS FOR CHROOT ===
echo "🔧 Mounting system pseudo-filesystems..."
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev

# Bind /run (sometimes tmpfs, needed for systemd inside chroot)
mount --bind /run /mnt/run || true

echo "🚪 Entering chroot environment..."
arch-chroot /mnt
