#!/bin/bash
set -e

source ./config.sh

# Utility function to update (or append) a variable in config.sh
update_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" config.sh; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|" config.sh
  else
    echo "${key}=\"${value}\"" >> config.sh
  fi
}

echo "🖥 Firmware detected: $FIRMWARE_MODE"
echo ""

# -- Filesystem Choice --
echo "📂 Choose a filesystem for partitions:"
select fs in "ext4" "xfs" "btrfs" "zfs" "reiser4"; do
  case "$fs" in
    ext4|xfs|btrfs|zfs|reiser4)
         FS_TYPE="$fs"
         update_config "FS_TYPE" "$FS_TYPE"
         break;;
    *) echo "❌ Invalid choice. Please try again." ;;
  esac
done

echo ""

# -- Partitioning Mode --
read -rp "⚙️ Use automated partitioning? [y/n]: " AUTO_PART

if [[ "$AUTO_PART" == "y" ]]; then
  echo "🖴 Available drives:"
  lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd"
  echo ""
  read -rp "📦 Enter primary drive (e.g., /dev/sda): " DRIVE
  if [[ ! -b "$DRIVE" ]]; then echo "❌ Invalid drive."; exit 1; fi
  
  # Ask about separate /home on the primary drive or on a separate drive.
  read -rp "🏠 Use a separate /home partition? [y/n]: " USE_HOME
  if [[ "$USE_HOME" == "y" ]]; then
    read -rp "📁 Use a separate drive for /home? [y/n]: " HOME_SEPARATE
    if [[ "$HOME_SEPARATE" == "y" ]]; then
      lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd" | grep -v "$DRIVE"
      read -rp "📦 Enter drive for /home (e.g., /dev/sdb): " HOME_DRIVE
      if [[ ! -b "$HOME_DRIVE" ]]; then echo "❌ Invalid drive."; exit 1; fi
    fi
  fi
  
  # Ask about swap partition
  read -rp "💤 Create swap partition? [y/n]: " USE_SWAP
  if [[ "$USE_SWAP" == "y" ]]; then
    read -rp "🔢 Enter swap size (e.g., 2G or 2048MiB): " SWAP_SIZE_RAW
    # Normalize input:
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
  
  echo ""
  echo "🧹 Wiping drives..."
  wipefs -af "$DRIVE"
  if [[ "$HOME_SEPARATE" == "y" ]]; then
    wipefs -af "$HOME_DRIVE"
  fi
  
  # --- Partitioning ---
  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    parted "$DRIVE" --script mklabel gpt
    # Partition 1: Boot partition (fixed 512MiB)
    parted "$DRIVE" --script mkpart primary fat32 1MiB 513MiB
    parted "$DRIVE" --script set 1 esp on
    
    if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" != "y" ]]; then
      if [[ "$USE_SWAP" == "y" ]]; then
         # Partition 2: Root (513MiB to 70%)
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 70%
         # Partition 3: Home (70% to 100%-swap)
         parted "$DRIVE" --script mkpart primary $FS_TYPE 70% "100%-${SWAP_SIZE}"
         # Partition 4: Swap (from "100%-swap" to 100%)
         parted "$DRIVE" --script mkpart primary linux-swap "100%-${SWAP_SIZE}" 100%
      else
         # Only boot, root, and home
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 70%
         parted "$DRIVE" --script mkpart primary $FS_TYPE 70% 100%
      fi
    else
      # No separate home on primary drive.
      if [[ "$USE_SWAP" == "y" ]]; then
         # Boot, then root (ending before swap), then swap.
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB "100%-${SWAP_SIZE}"
         parted "$DRIVE" --script mkpart primary linux-swap "100%-${SWAP_SIZE}" 100%
      else
         # Only boot and root.
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 100%
      fi
    fi
  else
    # BIOS mode (using msdos label)
    parted "$DRIVE" --script mklabel msdos
    # Partition 1: Boot (512MiB)
    parted "$DRIVE" --script mkpart primary $FS_TYPE 1MiB 513MiB
    if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" != "y" ]]; then
      if [[ "$USE_SWAP" == "y" ]]; then
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 70%
         parted "$DRIVE" --script mkpart primary $FS_TYPE 70% "100%-${SWAP_SIZE}"
         parted "$DRIVE" --script mkpart primary linux-swap "100%-${SWAP_SIZE}" 100%
      else
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 70%
         parted "$DRIVE" --script mkpart primary $FS_TYPE 70% 100%
      fi
    else
      if [[ "$USE_SWAP" == "y" ]]; then
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB "100%-${SWAP_SIZE}"
         parted "$DRIVE" --script mkpart primary linux-swap "100%-${SWAP_SIZE}" 100%
      else
         parted "$DRIVE" --script mkpart primary $FS_TYPE 513MiB 100%
      fi
    fi
  fi
  
  # Determine partition names (adjust for NVMe if necessary)
  if [[ "$DRIVE" =~ nvme ]]; then
    if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
      BOOT_PART="${DRIVE}p1"
      if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" != "y" ]]; then
        if [[ "$USE_SWAP" == "y" ]]; then
          ROOT_PART="${DRIVE}p2"
          HOME_PART="${DRIVE}p3"
          SWAP_PART="${DRIVE}p4"
        else
          ROOT_PART="${DRIVE}p2"
          HOME_PART="${DRIVE}p3"
        fi
      else
        if [[ "$USE_SWAP" == "y" ]]; then
          ROOT_PART="${DRIVE}p2"
          SWAP_PART="${DRIVE}p3"
        else
          ROOT_PART="${DRIVE}p2"
        fi
      fi
    else
      # In BIOS mode, partition naming is similar
      if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" != "y" ]]; then
        if [[ "$USE_SWAP" == "y" ]]; then
          BOOT_PART="${DRIVE}p1"
          ROOT_PART="${DRIVE}p2"
          HOME_PART="${DRIVE}p3"
          SWAP_PART="${DRIVE}p4"
        else
          BOOT_PART="${DRIVE}p1"
          ROOT_PART="${DRIVE}p2"
          HOME_PART="${DRIVE}p3"
        fi
      else
        if [[ "$USE_SWAP" == "y" ]]; then
          BOOT_PART="${DRIVE}p1"
          ROOT_PART="${DRIVE}p2"
          SWAP_PART="${DRIVE}p3"
        else
          BOOT_PART="${DRIVE}p1"
          ROOT_PART="${DRIVE}p2"
        fi
      fi
    fi
  else
    # SATA or similar drives: append partition numbers normally.
    if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" != "y" ]]; then
      if [[ "$USE_SWAP" == "y" ]]; then
        BOOT_PART="${DRIVE}1"
        ROOT_PART="${DRIVE}2"
        HOME_PART="${DRIVE}3"
        SWAP_PART="${DRIVE}4"
      else
        BOOT_PART="${DRIVE}1"
        ROOT_PART="${DRIVE}2"
        HOME_PART="${DRIVE}3"
      fi
    else
      if [[ "$USE_SWAP" == "y" ]]; then
        BOOT_PART="${DRIVE}1"
        ROOT_PART="${DRIVE}2"
        SWAP_PART="${DRIVE}3"
      else
        BOOT_PART="${DRIVE}1"
        ROOT_PART="${DRIVE}2"
      fi
    fi
  fi
  
  # If home is on a separate drive, partition that drive:
  if [[ "$USE_HOME" == "y" && "$HOME_SEPARATE" == "y" ]]; then
    parted "$HOME_DRIVE" --script mklabel gpt
    parted "$HOME_DRIVE" --script mkpart primary $FS_TYPE 1MiB 100%
    HOME_PART="${HOME_DRIVE}1"
  fi
  
else
  # -- Manual Partitioning --
  echo "🛠 Manual partitioning selected. Launching cfdisk on your target drive."
  read -rp "📦 Enter target drive (e.g., /dev/sda): " DRIVE
  cfdisk "$DRIVE"
  
  read -rp "📁 Enter your root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "📁 Enter your boot partition (e.g., /dev/sda1): " BOOT_PART
  read -rp "🏠 Enter your /home partition (optional): " HOME_PART
  read -rp "💤 Enter your swap partition (optional): " SWAP_PART
  
  echo "Formatting partitions..."
  mkfs."$FS_TYPE" "$ROOT_PART"
  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    mkfs.fat -F32 "$BOOT_PART"
  else
    mkfs."$FS_TYPE" "$BOOT_PART"
  fi
  [[ -n "$HOME_PART" ]] && mkfs."$FS_TYPE" "$HOME_PART"
  [[ -n "$SWAP_PART" ]] && mkswap "$SWAP_PART" && swapon "$SWAP_PART"
fi

# -- Mounting --
echo "Mounting root partition ($ROOT_PART) to /mnt..."
mount "$ROOT_PART" /mnt
if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
  mkdir -p /mnt/boot/efi
  echo "Mounting boot partition ($BOOT_PART) to /mnt/boot/efi..."
  mount "$BOOT_PART" /mnt/boot/efi
else
  mkdir -p /mnt/boot
  echo "Mounting boot partition ($BOOT_PART) to /mnt/boot..."
  mount "$BOOT_PART" /mnt/boot
fi
if [[ -n "$HOME_PART" ]]; then
  mkdir -p /mnt/home
  echo "Mounting home partition ($HOME_PART) to /mnt/home..."
  mount "$HOME_PART" /mnt/home
fi
if [[ -n "$SWAP_PART" ]]; then
  echo "Activating swap partition ($SWAP_PART)..."
  swapon "$SWAP_PART"
fi

# -- Update config.sh with chosen partition info --
update_config "ROOT_PART" "$ROOT_PART"
update_config "BOOT_PART" "$BOOT_PART"
update_config "DRIVE" "$DRIVE"
[[ -n "$HOME_PART" ]] && update_config "HOME_PART" "$HOME_PART"
[[ -n "$SWAP_PART" ]] && update_config "SWAP_PART" "$SWAP_PART"

echo "✅ Automated disk setup complete. Proceed to 02-base-install.sh"
