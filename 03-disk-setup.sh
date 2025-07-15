#!/bin/bash
set -e

source ./config.sh

echo "🔧 Detected firmware mode: $FIRMWARE_MODE"

echo "🖴 Available disks:"
lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"
echo ""

read -rp "📦 Enter the drive you want to install Arch on (e.g., /dev/sda): " DRIVE

if [[ ! -b "$DRIVE" ]]; then
  echo "❌ Invalid drive: $DRIVE"
  exit 1
fi

read -rp "⚙️  Use automatic partitioning? [y/n]: " AUTOPART

if [[ "$AUTOPART" == "y" ]]; then
  echo "🧹 Wiping $DRIVE and creating partitions..."
  wipefs -af "$DRIVE"
  parted "$DRIVE" --script mklabel ${FIRMWARE_MODE == "UEFI" && echo "gpt" || echo "msdos"}

  if [ "$FIRMWARE_MODE" == "UEFI" ]; then
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"

    echo "📁 Formatting /boot (FAT32)..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"

    echo "📁 Formatting /boot (ext4)..."
    mkfs.ext4 "$BOOT_PART"
  fi

  echo "📁 Formatting / (ext4)..."
  mkfs.ext4 "$ROOT_PART"

else
  echo "🛠 Manual partitioning selected. You will be dropped into cfdisk..."
  read -rp "Press Enter to continue..."
  cfdisk "$DRIVE"

  read -rp "🔍 Enter your root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "🔍 Enter your boot partition (e.g., /dev/sda1): " BOOT_PART

  echo "📁 Formatting root partition..."
  mkfs.ext4 "$ROOT_PART"

  if [ "$FIRMWARE_MODE" == "UEFI" ]; then
    echo "📁 Formatting boot partition (FAT32)..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    echo "📁 Formatting boot partition (ext4)..."
    mkfs.ext4 "$BOOT_PART"
  fi
fi

echo "📂 Mounting root partition..."
mount "$ROOT_PART" /mnt

if [ "$FIRMWARE_MODE" == "UEFI" ]; then
  echo "📂 Mounting boot partition to /mnt/boot/efi..."
  mkdir -p /mnt/boot/efi
  mount "$BOOT_PART" /mnt/boot/efi
else
  echo "📂 Mounting boot partition to /mnt/boot..."
  mkdir -p /mnt/boot
  mount "$BOOT_PART" /mnt/boot
fi

# Save to config
sed -i "/^ROOT_PART=/c\ROOT_PART=\"$ROOT_PART\"" config.sh
sed -i "/^BOOT_PART=/c\BOOT_PART=\"$BOOT_PART\"" config.sh
sed -i "/^DRIVE=/c\DRIVE=\"$DRIVE\"" config.sh

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"
