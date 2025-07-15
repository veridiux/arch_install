#!/bin/bash
set -e

source ./config.sh

echo "🖴 Available disks:"
lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"

echo ""
read -rp "📦 Enter the drive you want to install Arch on (e.g., /dev/sda): " DRIVE

if [[ ! -b "$DRIVE" ]]; then
  echo "❌ Invalid drive: $DRIVE"
  exit 1
fi

echo ""
read -rp "⚙️  Use automatic partitioning? [y/n]: " AUTOPART

if [[ "$AUTOPART" == "y" ]]; then
  echo "🧹 Wiping $DRIVE and creating partitions..."

  wipefs -af "$DRIVE"

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"

    echo "📁 Formatting boot partition (FAT32 EFI)..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    # BIOS partitioning - use msdos label and one boot + root partition
    parted "$DRIVE" --script mklabel msdos
    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"

    echo "📁 Formatting boot partition (ext4)..."
    mkfs.ext4 "$BOOT_PART"
  fi

  echo "📁 Formatting root partition with $FS_TYPE..."
  mkfs."$FS_TYPE" "$ROOT_PART"

else
  echo "🛠 Manual partitioning selected. You will be dropped into cfdisk."
  read -rp "Press Enter to launch cfdisk..."
  cfdisk "$DRIVE"

  echo "📁 After partitioning, enter your root partition:"
  read -rp "Root partition (e.g., /dev/sda2): " ROOT_PART
  echo "Boot partition (e.g., /dev/sda1): "
  read -rp "Boot partition: " BOOT_PART

  echo "🔍 Formatting root partition with $FS_TYPE..."
  mkfs."$FS_TYPE" "$ROOT_PART"

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    echo "🔍 Formatting boot partition as FAT32 EFI..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    echo "🔍 Formatting boot partition as ext4..."
    mkfs.ext4 "$BOOT_PART"
  fi
fi

echo "📂 Mounting root partition..."
mount "$ROOT_PART" /mnt

if [ "$FIRMWARE_MODE" = "UEFI" ]; then
  echo "📂 Creating /boot/efi and mounting boot partition..."
  mkdir -p /mnt/boot/efi
  mount "$BOOT_PART" /mnt/boot/efi
else
  echo "📂 Creating /boot and mounting boot partition..."
  mkdir -p /mnt/boot
  mount "$BOOT_PART" /mnt/boot
fi

# Optional swap file (your existing swap code here)...

# Save to config
echo "ROOT_PART=\"$ROOT_PART\"" >> config.sh
echo "BOOT_PART=\"$BOOT_PART\"" >> config.sh
echo "DRIVE=\"$DRIVE\"" >> config.sh

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"
