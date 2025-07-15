#!/bin/bash
set -e

source ./config.sh

echo "🔍 Detected firmware: $FIRMWARE_MODE"

echo "💽 Filesystem options:"
echo "1) ext4"
echo "2) xfs"
echo "3) btrfs"
echo "4) zfs"
echo "5) reiser4"

read -rp "📂 Choose filesystem [1-5]: " FS_CHOICE
case "$FS_CHOICE" in
  1) FS_TYPE="ext4" ;;
  2) FS_TYPE="xfs" ;;
  3) FS_TYPE="btrfs" ;;
  4) FS_TYPE="zfs" ;;       # Warning: zfs needs additional setup
  5) FS_TYPE="reiser4" ;;   # Warning: uncommon, might need external repo
  *) echo "❌ Invalid choice"; exit 1 ;;
esac

echo "🖴 Available disks:"
lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"

echo ""
read -rp "📦 Enter the main drive for installation (e.g., /dev/sda): " DRIVE

if [[ ! -b "$DRIVE" ]]; then
  echo "❌ Invalid drive: $DRIVE"
  exit 1
fi

read -rp "⚙️ Use automatic partitioning? [y/n]: " AUTOPART

if [[ "$AUTOPART" == "y" ]]; then
  read -rp "📁 Create separate /home partition? [y/n]: " SEP_HOME
  read -rp "💾 Create a swap partition? [y/n]: " USE_SWAP
  if [[ "$USE_SWAP" == "y" ]]; then
    read -rp "🔢 Enter swap size (e.g., 2GiB or 2048MiB): " SWAP_SIZE
  fi

  echo "🧹 Wiping $DRIVE..."
  wipefs -af "$DRIVE"
  parted "$DRIVE" --script mklabel gpt

  echo "🧱 Creating boot partition..."
  parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
  parted "$DRIVE" --script set 1 esp on
  BOOT_PART="${DRIVE}1"

  echo "🧱 Creating root partition..."
  ROOT_START="512MiB"

  if [[ "$SEP_HOME" == "y" || "$USE_SWAP" == "y" ]]; then
    parted "$DRIVE" --script mkpart primary $FS_TYPE $ROOT_START 50%
    ROOT_PART="${DRIVE}2"
    NEXT_PART_NUM=3

    if [[ "$SEP_HOME" == "y" ]]; then
      echo "🧱 Creating /home partition..."
      parted "$DRIVE" --script mkpart primary $FS_TYPE 50% 90%
      HOME_PART="${DRIVE}$NEXT_PART_NUM"
      NEXT_PART_NUM=$((NEXT_PART_NUM + 1))
    fi

    if [[ "$USE_SWAP" == "y" ]]; then
      # Get total size of drive in MiB
      DRIVE_SIZE=$(lsblk -bno SIZE "$DRIVE")
      DRIVE_SIZE_MIB=$((DRIVE_SIZE / 1024 / 1024))

      # Convert swap size to MiB
      if [[ "$SWAP_SIZE" =~ ^([0-9]+)GiB$ ]]; then
        SWAP_SIZE_MIB=$((BASH_REMATCH[1] * 1024))
      elif [[ "$SWAP_SIZE" =~ ^([0-9]+)MiB$ ]]; then
        SWAP_SIZE_MIB=${BASH_REMATCH[1]}
      else
        echo "❌ Invalid swap size format."
        exit 1
      fi

      SWAP_START_MIB=$((DRIVE_SIZE_MIB - SWAP_SIZE_MIB))
      echo "🧱 Creating swap partition..."
      parted "$DRIVE" --script mkpart primary linux-swap "${SWAP_START_MIB}MiB" 100%
      SWAP_PART="${DRIVE}$NEXT_PART_NUM"
    fi
  else
    parted "$DRIVE" --script mkpart primary $FS_TYPE $ROOT_START 100%
    ROOT_PART="${DRIVE}2"
  fi

  echo "🔍 Formatting partitions..."
  mkfs.fat -F32 "$BOOT_PART"
  mkfs."$FS_TYPE" "$ROOT_PART"
  [[ -n "$HOME_PART" ]] && mkfs."$FS_TYPE" "$HOME_PART"
  [[ -n "$SWAP_PART" ]] && mkswap "$SWAP_PART"

else
  echo "🛠 Manual mode: You will be dropped into cfdisk."
  read -rp "Press Enter to launch cfdisk..."
  cfdisk "$DRIVE"

  read -rp "Enter root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "Enter boot partition (e.g., /dev/sda1): " BOOT_PART
  read -rp "Optional: enter /home partition (or leave blank): " HOME_PART
  read -rp "Optional: enter swap partition (or leave blank): " SWAP_PART

  echo "🔍 Formatting root partition..."
  mkfs."$FS_TYPE" "$ROOT_PART"

  echo "🔍 Formatting boot partition..."
  mkfs.fat -F32 "$BOOT_PART"

  [[ -n "$HOME_PART" ]] && mkfs."$FS_TYPE" "$HOME_PART"
  [[ -n "$SWAP_PART" ]] && mkswap "$SWAP_PART"
fi

echo "📂 Mounting root..."
mount "$ROOT_PART" /mnt

echo "📂 Mounting boot..."
mkdir -p /mnt/boot/efi
mount "$BOOT_PART" /mnt/boot/efi

if [[ -n "$HOME_PART" ]]; then
  echo "📂 Mounting home..."
  mkdir -p /mnt/home
  mount "$HOME_PART" /mnt/home
fi

if [[ -n "$SWAP_PART" ]]; then
  echo "📂 Enabling swap..."
  swapon "$SWAP_PART"
fi

# Save to config.sh
{
  echo "DRIVE=\"$DRIVE\""
  echo "ROOT_PART=\"$ROOT_PART\""
  echo "BOOT_PART=\"$BOOT_PART\""
  [[ -n "$HOME_PART" ]] && echo "HOME_PART=\"$HOME_PART\""
  [[ -n "$SWAP_PART" ]] && echo "SWAP_PART=\"$SWAP_PART\""
  echo "FS_TYPE=\"$FS_TYPE\""
} >> config.sh

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"
