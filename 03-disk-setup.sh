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

# Helper function to update or append key=value pairs in config.sh
update_or_append() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" config.sh; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|" config.sh
  else
    echo "${key}=\"${value}\"" >> config.sh
  fi
}

if [[ "$AUTOPART" == "y" ]]; then
  echo "🧹 Wiping $DRIVE and creating partitions..."

  wipefs -af "$DRIVE"

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    if [[ "$DRIVE" =~ nvme ]]; then
      BOOT_PART="${DRIVE}p1"
      ROOT_PART="${DRIVE}p2"
    else
      BOOT_PART="${DRIVE}1"
      ROOT_PART="${DRIVE}2"
    fi

    echo "📁 Formatting boot partition (FAT32 EFI)..."
    mkfs.fat -F32 "$BOOT_PART"

  else
    # BIOS partitioning - msdos label with boot + root
    parted "$DRIVE" --script mklabel msdos
    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

    if [[ "$DRIVE" =~ nvme ]]; then
      BOOT_PART="${DRIVE}p1"
      ROOT_PART="${DRIVE}p2"
    else
      BOOT_PART="${DRIVE}1"
      ROOT_PART="${DRIVE}2"
    fi

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

# Create swap file if SWAP_SIZE is set in config.sh
if [[ -n "$SWAP_SIZE" ]]; then
  echo "💤 Creating swap file of size $SWAP_SIZE..."

  fallocate -l "$SWAP_SIZE" /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile

  # Add swapfile entry to fstab
  echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
else
  echo "💤 No swap size specified; skipping swap file creation."
fi

# Update config.sh with partition info and drive
update_or_append "ROOT_PART" "$ROOT_PART"
update_or_append "BOOT_PART" "$BOOT_PART"
update_or_append "DRIVE" "$DRIVE"

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"
