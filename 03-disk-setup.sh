#!/bin/bash
set -e

source ./config.sh

# Function to update or insert a variable in config.sh
update_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" config.sh; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|" config.sh
  else
    echo "${key}=\"${value}\"" >> config.sh
  fi
}

echo "💡 Detected firmware: $FIRMWARE_MODE"

echo ""
read -rp "🧠 Use automated partitioning? [y/n]: " AUTO_PART

lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"

if [[ "$AUTO_PART" == "y" ]]; then
  echo ""
  read -rp "📦 Enter the primary drive to install Arch on (e.g., /dev/sda): " DRIVE
  if [[ ! -b "$DRIVE" ]]; then
    echo "❌ Invalid drive: $DRIVE"
    exit 1
  fi

  echo ""
  read -rp "🏠 Use a separate /home partition? [y/n]: " SEP_HOME
  if [[ "$SEP_HOME" == "y" ]]; then
    echo ""
    read -rp "📁 Use a separate drive for /home? [y/n]: " SEP_HOME_DRIVE
    if [[ "$SEP_HOME_DRIVE" == "y" ]]; then
      lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd" | grep -v "$DRIVE"
      read -rp "🔧 Enter second drive for /home (e.g., /dev/sdb): " HOME_DRIVE
      if [[ ! -b "$HOME_DRIVE" ]]; then
        echo "❌ Invalid second drive: $HOME_DRIVE"
        exit 1
      fi
    fi
  fi

  echo ""
  read -rp "💤 Create swap partition? [y/n]: " ADD_SWAP
  if [[ "$ADD_SWAP" == "y" ]]; then
    read -rp "🔢 Enter swap size (e.g., 2G): " SWAP_SIZE
    update_config "SWAP_SIZE" "$SWAP_SIZE"
  fi

  echo "🧹 Wiping and partitioning selected drives..."
  wipefs -af "$DRIVE"
  parted "$DRIVE" --script mklabel gpt

  BOOT_PART=""
  ROOT_PART=""
  HOME_PART=""
  SWAP_PART=""

  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    parted "$DRIVE" --script mkpart primary fat32 1MiB 513MiB
    parted "$DRIVE" --script set 1 esp on
    parted "$DRIVE" --script mkpart primary ext4 513MiB 100%
    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"
    mkfs.fat -F32 "$BOOT_PART"
  else
    parted "$DRIVE" --script mklabel msdos
    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    parted "$DRIVE" --script mkpart primary ext4 512MiB 100%
    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"
    mkfs.ext4 "$BOOT_PART"
  fi

  mkfs.ext4 "$ROOT_PART"

  if [[ "$SEP_HOME" == "y" ]]; then
    if [[ "$SEP_HOME_DRIVE" == "y" ]]; then
      wipefs -af "$HOME_DRIVE"
      parted "$HOME_DRIVE" --script mklabel gpt
      parted "$HOME_DRIVE" --script mkpart primary ext4 1MiB 100%
      HOME_PART="${HOME_DRIVE}1"
    else
      parted "$DRIVE" --script mkpart primary ext4 100% 100%  # Placeholder for smarter logic
      HOME_PART="${DRIVE}3"
    fi
    mkfs.ext4 "$HOME_PART"
  fi

  if [[ "$ADD_SWAP" == "y" ]]; then
    parted "$DRIVE" --script mkpart primary linux-swap -${SWAP_SIZE} 100%
    SWAP_PART="${DRIVE}4"
    mkswap "$SWAP_PART"
  fi

else
  echo "🛠 Manual partitioning selected. You'll specify partitions next."
  read -rp "🧱 Enter root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "🧱 Enter boot partition (e.g., /dev/sda1): " BOOT_PART
  read -rp "🧱 Enter home partition (leave empty if not using one): " HOME_PART
  read -rp "🧱 Enter swap partition (leave empty if not using one): " SWAP_PART

  echo "💾 Formatting root partition..."
  mkfs.ext4 "$ROOT_PART"

  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    echo "💾 Formatting boot partition (FAT32)..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    echo "💾 Formatting boot partition (ext4)..."
    mkfs.ext4 "$BOOT_PART"
  fi

  if [[ -n "$HOME_PART" ]]; then
    echo "💾 Formatting home partition..."
    mkfs.ext4 "$HOME_PART"
  fi

  if [[ -n "$SWAP_PART" ]]; then
    echo "💾 Setting up swap partition..."
    mkswap "$SWAP_PART"
  fi
fi

# Mounting
echo "📂 Mounting root to /mnt..."
mount "$ROOT_PART" /mnt

if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
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

# Save to config
update_config "ROOT_PART" "$ROOT_PA_
