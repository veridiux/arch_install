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
  parted "$DRIVE" --script mklabel gpt
  parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
  parted "$DRIVE" --script set 1 esp on
  parted "$DRIVE" --script mkpart primary ext4 512MiB 100%

  BOOT_PART="${DRIVE}1"
  ROOT_PART="${DRIVE}2"

  echo "📁 Formatting boot partition..."
  mkfs.fat -F32 "$BOOT_PART"

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
  echo "🔍 Formatting boot partition..."
  mkfs.fat -F32 "$BOOT_PART"
fi

echo "📂 Mounting root partition..."
mount "$ROOT_PART" /mnt

echo "📂 Creating /boot/efi and mounting boot partition..."
mkdir -p /mnt/boot/efi
mount "$BOOT_PART" /mnt/boot/efi

# Optional swap file
echo ""
read -rp "💾 Create swap file? [y/n]: " USE_SWAP

if [[ "$USE_SWAP" == "y" ]]; then
  read -rp "Swap file size (e.g., 2G, 512M): " SWAP_SIZE
  echo "📄 Creating swap file of size $SWAP_SIZE..."
  dd if=/dev/zero of=/mnt/swapfile bs=1M count=$(( $(echo $SWAP_SIZE | tr -d 'GgMm') * ( [[ "$SWAP_SIZE" == *G* ]] && echo 1024 || echo 1 ) )) status=progress
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
  echo "✔️ Swap file created and enabled."
  echo "$SWAP_SIZE" > ./swap.size
else
  echo "ℹ️ Skipping swap."
fi

# Save to config
echo "ROOT_PART=\"$ROOT_PART\"" >> config.sh
echo "BOOT_PART=\"$BOOT_PART\"" >> config.sh
echo "DRIVE=\"$DRIVE\"" >> config.sh

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"
