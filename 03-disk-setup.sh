#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"' ERR
exec > >(tee install.log) 2>&1


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

  # Ask about swap partition
  read -rp "Do you want a swap partition? [y/n]: " SWAP_CHOICE
  if [[ "$SWAP_CHOICE" == "y" ]]; then
    read -rp "Enter swap size in GiB (just number, e.g., 2): " SWAP_SIZE_GB
    SWAP_SIZE="${SWAP_SIZE_GB}GiB"
  else
    SWAP_SIZE=""
  fi

  # Ask about separate /home partition
  read -rp "Do you want a separate /home partition? [y/n]: " HOME_CHOICE
  if [[ "$HOME_CHOICE" == "y" ]]; then
    read -rp "Enter /home partition size in GiB (just number, e.g., 20): " HOME_SIZE_GB
    HOME_SIZE="${HOME_SIZE_GB}GiB"
  else
    HOME_SIZE=""
  fi
  
  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    BOOT_PART="${DRIVE}1"

    start_home=512MiB
    end_home=""
    start_swap=""
    end_swap=""

    if [[ -n "$HOME_SIZE" ]]; then
      # Calculate /home end based on start + size
      parted "$DRIVE" --script mkpart primary ext4 512MiB "$((512 + HOME_SIZE_GB * 1024))MiB"
      HOME_PART="${DRIVE}2"
      start_swap="$((512 + HOME_SIZE_GB * 1024))MiB"
      next_part=3
    else
      start_swap=512MiB
      next_part=2
    fi

    if [[ -n "$SWAP_SIZE" ]]; then
      # Calculate swap start as "end - swap size"
      # parted needs absolute positions or negative offsets for end partitions.
      # Using negative offset here:
      parted "$DRIVE" --script mkpart primary linux-swap "-$SWAP_SIZE" 100%
      SWAP_PART="${DRIVE}${next_part}"
      # Root partition is between /boot (and /home if exists) and swap
      parted "$DRIVE" --script mkpart primary ext4 "${HOME_CHOICE == y && echo "$((512 + HOME_SIZE_GB * 1024))MiB" || echo "512MiB"}" "-$SWAP_SIZE"
      ROOT_PART="${DRIVE}$((next_part + 1))"
    else
      # No swap, root takes all remaining space after /boot and optional /home
      parted "$DRIVE" --script mkpart primary ext4 "${HOME_CHOICE == y && echo "$((512 + HOME_SIZE_GB * 1024))MiB" || echo "512MiB"}" 100%
      ROOT_PART="${DRIVE}$((next_part))"
    fi

    echo "📁 Formatting /boot (FAT32 EFI)..."
    mkfs.fat -F32 "$BOOT_PART"

  else
    # BIOS mode - simpler scheme, no ESP partition
    parted "$DRIVE" --script mklabel msdos

    parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
    BOOT_PART="${DRIVE}1"

    start_home=512MiB
    next_part=2

    if [[ -n "$HOME_SIZE" ]]; then
      parted "$DRIVE" --script mkpart primary ext4 512MiB "$((512 + HOME_SIZE_GB * 1024))MiB"
      HOME_PART="${DRIVE}2"
      next_part=3
      start_swap="$((512 + HOME_SIZE_GB * 1024))MiB"
    else
      start_swap=512MiB
    fi

    if [[ -n "$SWAP_SIZE" ]]; then
      parted "$DRIVE" --script mkpart primary linux-swap "-$SWAP_SIZE" 100%
      SWAP_PART="${DRIVE}${next_part}"
      parted "$DRIVE" --script mkpart primary ext4 "$start_swap" "-$SWAP_SIZE"
      ROOT_PART="${DRIVE}$((next_part + 1))"
    else
      parted "$DRIVE" --script mkpart primary ext4 "$start_swap" 100%
      ROOT_PART="${DRIVE}${next_part}"
    fi

    echo "📁 Formatting /boot (ext4)..."
    mkfs.ext4 "$BOOT_PART"
  fi






  # Format partitions
  echo "📁 Formatting / (ext4)..."
  mkfs.ext4 "$ROOT_PART"

  if [[ -n "$HOME_PART" ]]; then
    echo "📁 Formatting /home (ext4)..."
    mkfs.ext4 "$HOME_PART"
  fi

  if [[ -n "$SWAP_PART" ]]; then
    echo "🛑 Creating swap partition..."
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
  fi








else
  echo "🛠 Manual partitioning selected. You will be dropped into cfdisk."
  read -rp "Press Enter to launch cfdisk..."
  cfdisk "$DRIVE"

  echo "📁 After partitioning, enter your root partition:"
  read -rp "Root partition (e.g., /dev/sda2): " ROOT_PART
  read -rp "Boot partition (e.g., /dev/sda1): " BOOT_PART

  # Prompt for root filesystem type
  echo "Choose filesystem type for root partition:"
  echo "1) ext4"
  echo "2) btrfs"
  echo "3) xfs"
  echo "4) f2fs"
  read -rp "Enter number [1-4]: " FS_CHOICE

  case "$FS_CHOICE" in
    1) FS_TYPE="ext4" ;;
    2) FS_TYPE="btrfs" ;;
    3) FS_TYPE="xfs" ;;
    4) FS_TYPE="f2fs" ;;
    *) echo "Invalid choice, defaulting to ext4"; FS_TYPE="ext4" ;;
  esac

  read -rp "⚙️  Would you like to use a separate HOME partition? [y/n]: " HOME_CHOICE
  if [[ "$HOME_CHOICE" =~ ^[Yy]$ ]]; then
    read -rp "Home partition (e.g., /dev/sda3): " HOME_PART

    # Prompt for home filesystem type
    echo "Choose filesystem type for home partition:"
    echo "1) ext4"
    echo "2) btrfs"
    echo "3) xfs"
    echo "4) f2fs"
    read -rp "Enter number [1-4]: " HOME_FS_CHOICE

    case "$HOME_FS_CHOICE" in
      1) HOME_FS_TYPE="ext4" ;;
      2) HOME_FS_TYPE="btrfs" ;;
      3) HOME_FS_TYPE="xfs" ;;
      4) HOME_FS_TYPE="f2fs" ;;
      *) echo "Invalid choice, defaulting to ext4"; HOME_FS_TYPE="ext4" ;;
    esac
  fi

  read -rp "⚙️  Would you like to use a SWAP partition? [y/n]: " SWAP_CHOICE
  if [[ "$SWAP_CHOICE" =~ ^[Yy]$ ]]; then
    read -rp "Swap partition (e.g., /dev/sda4): " SWAP_PART
  fi
  
  
  
  detect_fs() {
	  local part=$1
	  local fs=$(blkid -o value -s TYPE "$part")
	  echo "Detected filesystem on $part: $fs" >&2  # Debug log
	  echo "$fs"
	}


  mkfs_with_force() {
	  local fs_type=$1
	  local part=$2

	  # Try to unmount in case it's mounted
	  umount "$part" 2>/dev/null

	  echo "🧪 Running mkfs for $fs_type on $part..." >&2

	  case "$fs_type" in
		ext4)
		  mkfs.ext4 -F "$part" ;;
		xfs)
		  mkfs.xfs -f "$part" ;;
		f2fs)
		  mkfs.f2fs -f "$part" ;;
		btrfs)
		  mkfs.btrfs -f "$part" ;;
		*)
		  echo "❌ Unknown filesystem type: $fs_type" >&2
		  return 1
		  ;;
	  esac

	  if [ $? -ne 0 ]; then
		echo "❌ mkfs.$fs_type failed on $part" >&2
		exit 1
	  fi
	}



  
  
  
  
  
  
  # Format root partition with check
  current_fs=$(detect_fs "$ROOT_PART")
  if [ -n "$current_fs" ]; then
    echo "⚠️ Root partition $ROOT_PART already has filesystem: $current_fs"
    read -rp "Do you want to reformat it to $FS_TYPE? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "Formatting root partition with $FS_TYPE..."
      #mkfs_with_force "$FS_TYPE" "$ROOT_PART"
	  mkfs.btrfs -f "$ROOT_PART"
    else
      echo "Keeping existing filesystem on root partition."
    fi
  else
    echo "Formatting root partition with $FS_TYPE..."
    mkfs_with_force "$FS_TYPE" "$ROOT_PART"
  fi

  if [ "$FIRMWARE_MODE" = "UEFI" ]; then
    echo "🔍 Formatting boot partition as FAT32 EFI..."
    mkfs.fat -F32 "$BOOT_PART"
  else
    echo "🔍 Formatting boot partition as ext4..."
    mkfs.ext4 "$BOOT_PART"
  fi

  # Format home partition with check
  if [[ "$HOME_CHOICE" =~ ^[Yy]$ ]]; then
    current_fs=$(detect_fs "$HOME_PART")
    if [ -n "$current_fs" ]; then
      echo "⚠️ Home partition $HOME_PART already has filesystem: $current_fs"
      read -rp "Do you want to reformat it to $HOME_FS_TYPE? [y/N]: " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Formatting home partition with $HOME_FS_TYPE..."
        mkfs_with_force "$HOME_FS_TYPE" "$HOME_PART"
      else
        echo "Keeping existing filesystem on home partition."
      fi
    else
      echo "Formatting home partition with $HOME_FS_TYPE..."
      mkfs_with_force "$HOME_FS_TYPE" "$HOME_PART"
    fi
  fi

  if [[ "$SWAP_CHOICE" =~ ^[Yy]$ ]]; then
    echo "🔍 Creating swap partition..."
    mkswap "$SWAP_PART"
    echo "Activating swap partition..."
    swapon "$SWAP_PART"
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

  if [[ "$HOME_CHOICE" =~ ^[Yy]$ ]]; then
    echo "📂 Creating /home and mounting home partition..."
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
  fi

  # Save values to config.sh
  echo "ROOT_PART=\"$ROOT_PART\"" >> config.sh
  echo "BOOT_PART=\"$BOOT_PART\"" >> config.sh
  echo "DRIVE=\"$DRIVE\"" >> config.sh
  if [[ "$HOME_CHOICE" =~ ^[Yy]$ ]]; then
    echo "HOME_PART=\"$HOME_PART\"" >> config.sh
  fi
  if [[ "$SWAP_CHOICE" =~ ^[Yy]$ ]]; then
    echo "SWAP_PART=\"$SWAP_PART\"" >> config.sh
  fi

  echo "✅ Manual disk setup complete."

fi

echo "✅ Disk setup complete. Proceed to 02-base-install.sh"



fi
