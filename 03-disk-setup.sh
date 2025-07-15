#!/bin/bash
set -e

source ./config.sh

# Function to update config.sh variables
update_config() {
  local key="$1"
  local value="$2"
  sed -i "/^$key=/c\\$key=\"$value\"" config.sh
}

echo "🖥 Firmware detected: $FIRMWARE_MODE"
echo ""

# Filesystem choice
echo "📂 Choose a filesystem:"
select fs in "ext4" "xfs" "btrfs" "zfs" "reiser4"; do
  case "$fs" in
    ext4|xfs|btrfs|zfs|reiser4) FS_TYPE="$fs"; break ;;
    *) echo "❌ Invalid choice. Try again." ;;
  esac
done
update_config "FS_TYPE" "$FS_TYPE"

echo ""
read -rp "⚙️  Use automatic partitioning? [y/n]: " AUTO_PART

if [[ "$AUTO_PART" == "y" ]]; then
  echo "🖴 Available disks:"
  lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"
  echo ""

  read -rp "📦 Enter primary drive (e.g., /dev/sda): " DRIVE
  [[ ! -b "$DRIVE" ]] && echo "❌ Invalid drive!" && exit 1

  read -rp "🏠 Use a separate /home partition? [y/n]: " USE_HOME
  if [[ "$USE_HOME" == "y" ]]; then
    read -rp "📁 Use a separate drive for /home? [y/n]: " HOME_SEPARATE
    if [[ "$HOME_SEPARATE" == "y" ]]; then
      echo "🖴 Other drives:"
      lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd" | grep -v "$DRIVE"
      read -rp "📦 Enter drive for /home (e.g., /dev/sdb): " HOME_DRIVE
      [[ ! -b "$HOME_DRIVE" ]] && echo "❌ Invalid drive!" && exit 1
    fi
  fi

  read -rp "💤 Create a swap partition? [y/n]: " USE_SWAP
  if [[ "$USE_SWAP" == "y" ]]; then
    read -rp "🔢 Enter swap size (e.g., 2G or 2048MiB): " SWAP_SIZE_RAW

	# Normalize input to parted format (MiB or GiB)
	if [[ "$SWAP_SIZE_RAW" =~ ^[0-9]+[Gg]$ ]]; then
	  SIZE_NUM="${SWAP_SIZE_RAW%[Gg]}"
	  SWAP_SIZE="${SIZE_NUM}GiB"
	elif [[ "$SWAP_SIZE_RAW" =~ ^[0-9]+[Mm]$ ]]; then
	  SIZE_NUM="${SWAP_SIZE_RAW%[Mm]}"
	  SWAP_SIZE="${SIZE_NUM}MiB"
	elif [[ "$SWAP_SIZE_RAW" =~ ^[0-9]+[MmIi][Bb]$ ]]; then
	  SWAP_SIZE="$SWAP_SIZE_RAW"
	else
	  echo "❌ Invalid swap size format."
	  exit 1
	fi

	update_config "SWAP_SIZE" "$SWAP_SIZE"

  fi

  echo "🧹 Wiping drives and setting up partitions..."
  wipefs -af "$DRIVE"
  [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" == "y" ]] && wipefs -af "$HOME_DRIVE"

  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart ESP fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    parted "$DRIVE" --script mkpart primary $FS_TYPE 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"
  else
    parted "$DRIVE" --script mklabel msdos
    parted "$DRIVE" --script mkpart primary $FS_TYPE 1MiB 512MiB
    parted "$DRIVE" --script mkpart primary $FS_TYPE 512MiB 100%

    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"
  fi

  if [[ "$USE_SWAP" == "y" ]]; then
    parted "$DRIVE" --script mkpart primary linux-swap -${SWAP_SIZE} 100%
    SWAP_PART="${DRIVE}3"
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
  fi

  if [[ "$USE_HOME" == "y" ]]; then
    if [[ "$HOME_SEPARATE" == "y" ]]; then
      parted "$HOME_DRIVE" --script mklabel gpt
      parted "$HOME_DRIVE" --script mkpart primary $FS_TYPE 1MiB 100%
      HOME_PART="${HOME_DRIVE}1"
    else
      parted "$DRIVE" --script mkpart primary $FS_TYPE 100% 100%
      HOME_PART="${DRIVE}4"
    fi
  fi

  # Format partitions
  echo "📁 Formatting boot partition..."
  [[ "$FIRMWARE_MODE" == "UEFI" ]] && mkfs.fat -F32 "$BOOT_PART" || mkfs."$FS_TYPE" "$BOOT_PART"
  echo "📁 Formatting root partition..."
  mkfs."$FS_TYPE" "$ROOT_PART"
  [[ "$USE_HOME" == "y" ]] && echo "📁 Formatting home partition..." && mkfs."$FS_TYPE" "$HOME_PART"

else
  echo "🛠 Manual partitioning selected. Launching cfdisk..."
  read -rp "📦 Enter the target drive (e.g., /dev/sda): " DRIVE
  cfdisk "$DRIVE"

  read -rp "📁 Enter root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "📁 Enter boot partition (e.g., /dev/sda1): " BOOT_PART
  read -rp "🏠 Enter home partition (optional): " HOME_PART
  read -rp "💤 Enter swap partition (optional): " SWAP_PART

  echo "📁 Formatting root..."
  mkfs."$FS_TYPE" "$ROOT_PART"

  echo "📁 Formatting boot..."
  [[ "$FIRMWARE_MODE" == "UEFI" ]] && mkfs.fat -F32 "$BOOT_PART" || mkfs."$FS_TYPE" "$BOOT_PART"

  [[ -n "$HOME_PART" ]] && echo "📁 Formatting home..." && mkfs."$FS_TYPE" "$HOME_PART"
  [[ -n "$SWAP_PART" ]] && mkswap "$SWAP_PART" && swapon "$SWAP_PART"
fi

# Mount everything
echo "📂 Mounting root..."
mount "$ROOT_PART" /mnt

if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
  mkdir -p /mnt/boot/efi
  mount "$BOOT_PART" /mnt/boot/efi
else
  mkdir -p /mnt/boot
  mount "$BOOT_PART" /mnt/boot
fi

[[ -n "$HOME_PART" ]] && mkdir -p /mnt/home && mount "$HOME_PART" /mnt/home

# Persist to config
update_config "ROOT_PART" "$ROOT_PART"
update_config "BOOT_PART" "$BOOT_PART"
update_config "DRIVE" "$DRIVE"
[[ -n "$HOME_PART" ]] && update_config "HOME_PART" "$HOME_PART"
[[ -n "$SWAP_PART" ]] && update_config "SWAP_PART" "$SWAP_PART"

echo "✅ Disk setup complete. Continue to 02-base-install.sh"
