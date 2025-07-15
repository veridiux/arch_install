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
echo "!!!! -- IF THE FOLLOWING OPTION IS USED IT WILL ERASE EVERYHTHING -- !!!!!"
read -rp "⚙️  Use automatic partitioning? [y/n]: " AUTOPART







if [[ "$AUTOPART" == "y" ]]; then
  echo "🧹 Wiping $DRIVE and creating partitions..."
  wipefs -af "$DRIVE"

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on

    BOOT_PART="${DRIVE}1"
    PART_NUM=2

    # Ask if user wants separate /home partition
    read -rp "Do you want a separate /home partition? [y/n]: " HOME_CHOICE

    # Ask if user wants swap partition and swap size
    read -rp "Do you want a swap partition? [y/n]: " SWAP_CHOICE
    if [[ "$SWAP_CHOICE" == "y" ]]; then
      read -rp "Enter swap size (e.g., 2G): " SWAP_SIZE
    else
      SWAP_SIZE=""
    fi

    if [[ "$HOME_CHOICE" == "y" && -n "$SWAP_SIZE" ]]; then
      # Need to create root, home, swap partitions
      # Ask user for root size
      read -rp "Enter root partition size (e.g., 20G): " ROOT_SIZE

      # Create root partition from 512MiB to ROOT_SIZE
      parted "$DRIVE" --script mkpart primary ext4 512MiB "$ROOT_SIZE"
      ROOT_PART="${DRIVE}${PART_NUM}"
      PART_NUM=$((PART_NUM + 1))

      # Calculate home partition start and end (from ROOT_SIZE to (100% - SWAP_SIZE))
      parted "$DRIVE" --script mkpart primary ext4 "$ROOT_SIZE" "-${SWAP_SIZE}"
      HOME_PART="${DRIVE}${PART_NUM}"
      PART_NUM=$((PART_NUM + 1))

      # Create swap partition at the end
      parted "$DRIVE" --script mkpart primary linux-swap "-${SWAP_SIZE}" 100%
      SWAP_PART="${DRIVE}${PART_NUM}"

    elif [[ "$HOME_CHOICE" == "y" ]]; then
      # Home but no swap
      read -rp "Enter root partition size (e.g., 20G): " ROOT_SIZE

      parted "$DRIVE" --script mkpart primary ext4 512MiB "$ROOT_SIZE"
      ROOT_PART="${DRIVE}${PART_NUM}"
      PART_NUM=$((PART_NUM + 1))

      parted "$DRIVE" --script mkpart primary ext4 "$ROOT_SIZE" 100%
      HOME_PART="${DRIVE}${PART_NUM}"
      SWAP_PART=""

    elif [[ -n "$SWAP_SIZE" ]]; then
      # Swap but no home
      parted "$DRIVE" --script mkpart primary ext4 512MiB "-${SWAP_SIZE}"
      ROOT_PART="${DRIVE}${PART_NUM}"
      PART_NUM=$((PART_NUM + 1))

      parted "$DRIVE" --script mkpart primary linux-swap "-${SWAP_SIZE}" 100%
      SWAP_PART="${DRIVE}${PART_NUM}"
      HOME_PART=""

    else
      # No home, no swap
      parted "$DRIVE" --script mkpart primary ext4 512MiB 100%
      ROOT_PART="${DRIVE}${PART_NUM}"
      HOME_PART=""
      SWAP_PART=""
    fi

    echo "📁 Formatting /boot (FAT32 EFI)..."
    mkfs.fat -F32 "$BOOT_PART"

    echo "📁 Formatting / (ext4)..."
    mkfs.ext4 "$ROOT_PART"

    if [[ -n "$HOME_PART" ]]; then
      echo "📁 Formatting /home (ext4)..."
      mkfs.ext4 "$HOME_PART"
    fi

    if [[ -n "$SWAP_PART" ]]; then
      echo "⚙️ Setting up swap partition..."
      mkswap "$SWAP_PART"
    fi

  else
    # BIOS partitioning fallback: similar logic can be applied here
    parted "$DRIVE" --script mklabel msdos
    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    BOOT_PART="${DRIVE}1"
    PART_NUM=2

    # You can add similar interactive logic for home and swap here if needed

    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%
    ROOT_PART="${DRIVE}2"

    echo "📁 Formatting /boot (ext4)..."
    mkfs.ext4 "$BOOT_PART"
    echo "📁 Formatting / (ext4)..."
    mkfs.ext4 "$ROOT_PART"

    HOME_PART=""
    SWAP_PART=""
  fi

  echo "📂 Mounting root partition..."
  mount "$ROOT_PART" /mnt

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    mkdir -p /mnt/boot/efi
    mount "$BOOT_PART" /mnt/boot/efi
  else
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
  fi

  if [[ -n "$HOME_PART" ]]; then
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
  fi

  if [[ -n "$SWAP_PART" ]]; then
    swapon "$SWAP_PART"
  fi

  # Save to config.sh
  echo "ROOT_PART=\"$ROOT_PART\"" >> config.sh
  echo "BOOT_PART=\"$BOOT_PART\"" >> config.sh
  echo "HOME_PART=\"$HOME_PART\"" >> config.sh
  echo "SWAP_PART=\"$SWAP_PART\"" >> config.sh
  echo "DRIVE=\"$DRIVE\"" >> config.sh

fi






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
