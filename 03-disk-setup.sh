#!/bin/bash
set -e
#set -euo pipefail
#trap 'echo "❌ Error on line $LINENO"' ERR
#exec > >(tee install.log) 2>&1


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







#!/bin/bash

# Assume variables $DRIVE, $AUTOPART, and $FIRMWARE_MODE are already set externally

if [[ "$AUTOPART" == "y" ]]; then
  echo "🔍 Detecting current partition table on $DRIVE..."
  PTTYPE=$(parted -s "$DRIVE" print 2>/dev/null | grep 'Partition Table' | awk '{print $3}')

  echo "💣 Wiping $DRIVE and creating new partitions..."
  wipefs -af "$DRIVE"

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

  # Ask about swap
  read -rp "Do you want a swap partition? [y/n]: " SWAP_CHOICE
  if [[ "$SWAP_CHOICE" == "y" ]]; then
    read -rp "Enter swap size in GiB (e.g., 2): " SWAP_SIZE_GB
    SWAP_SIZE="${SWAP_SIZE_GB}"
  fi

  # Ask about /home
  read -rp "Do you want a separate /home partition? [y/n]: " HOME_CHOICE
  if [[ "$HOME_CHOICE" == "y" ]]; then
    read -rp "Enter /home size in GiB (e.g., 20): " HOME_SIZE_GB
    HOME_SIZE="${HOME_SIZE_GB}"
  fi

  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    echo "⚙️ UEFI mode detected – using GPT and EFI System Partition..."
    parted "$DRIVE" --script mklabel gpt
    parted "$DRIVE" --script mkpart primary fat32 1MiB 512MiB
    parted "$DRIVE" --script set 1 esp on
    BOOT_PART="${DRIVE}1"
    next_part=2
    start_after_boot=512

  else
    echo "⚙️ BIOS mode detected – checking existing partition table type..."
    if [[ "$PTTYPE" == "gpt" ]]; then
      echo "📛 GPT on BIOS – creating BIOS Boot Partition..."
      parted "$DRIVE" --script mklabel gpt
      parted "$DRIVE" --script mkpart primary 1MiB 3MiB
      parted "$DRIVE" --script set 1 bios_grub on
      BIOS_GRUB_PART="${DRIVE}1"
      parted "$DRIVE" --script mkpart primary ext4 3MiB 512MiB
      BOOT_PART="${DRIVE}2"
      next_part=3
      start_after_boot=512
    else
      echo "📛 Using MBR (msdos)..."
      parted "$DRIVE" --script mklabel msdos
      parted "$DRIVE" --script mkpart primary ext4 1MiB 512MiB
      BOOT_PART="${DRIVE}1"
      next_part=2
      start_after_boot=512
    fi
  fi





  # Optional HOME partition
  if [[ -n "$HOME_SIZE" ]]; then
  # Calculate home partition end in MiB
  HOME_START=${start_after_boot}
  HOME_END=$((HOME_START + HOME_SIZE_GB * 1024))
  
  # Create home partition
  parted "$DRIVE" --script mkpart primary ext4 "${HOME_START}MiB" "${HOME_END}MiB"
  HOME_PART="${DRIVE}${next_part}"
  
  # Update pointers for next partition start and partition number
  start_after_home=${HOME_END}
  next_part=$((next_part + 1))
else
  start_after_home=${start_after_boot}
fi


  # Optional SWAP
  if [[ -n "$SWAP_SIZE" ]]; then
  # Calculate swap size in MiB
  SWAP_SIZE_MIB=$((SWAP_SIZE * 1024))
  
  # Calculate swap start and end
  SWAP_START=${start_after_home}
  SWAP_END=$((SWAP_START + SWAP_SIZE_MIB))
  
  # Create swap partition
  parted "$DRIVE" --script mkpart primary linux-swap "${SWAP_START}MiB" "${SWAP_END}MiB"
  SWAP_PART="${DRIVE}${next_part}"
  next_part=$((next_part + 1))
  
  # Create root partition from end of swap to 100%
  parted "$DRIVE" --script mkpart primary ext4 "${SWAP_END}MiB" 100%
  ROOT_PART="${DRIVE}${next_part}"
else
  # No swap, root partition from start_after_home to 100%
  parted "$DRIVE" --script mkpart primary ext4 "${start_after_home}MiB" 100%
  ROOT_PART="${DRIVE}${next_part}"
fi







  mkfs_with_force() {
	  local fs_type=$1
	  local part=$2

	  echo "🧪 mkfs_with_force called with fs_type=$fs_type, part=$part" >&2

	  echo "🔧 Attempting to unmount $part..." >&2
	  if ! umount "$part" 2>/dev/null; then
		echo "⚠️  Warning: $part was not mounted or failed to unmount (not fatal)" >&2
	  fi

	  echo "💾 Formatting $part as $fs_type..." >&2

	  case "$fs_type" in
		ext4)
		  echo "+ Running: mkfs.ext4 -F $part" >&2
		  mkfs.ext4 -F "$part" ;;
		xfs)
		  echo "+ Running: mkfs.xfs -f $part" >&2
		  mkfs.xfs -f "$part" ;;
		f2fs)
		  echo "+ Running: mkfs.f2fs -f $part" >&2
		  mkfs.f2fs -f "$part" ;;
		btrfs)
		  echo "+ Running: mkfs.btrfs -f $part" >&2
		  mkfs.btrfs -f "$part" ;;
		*)
		  echo "❌ Unknown filesystem type: $fs_type" >&2
		  return 1
		  ;;
	  esac

	  local result=$?
	  if [ $result -ne 0 ]; then
		echo "❌ mkfs.$fs_type failed with exit code $result on $part" >&2
		exit $result
	  else
		echo "✅ mkfs.$fs_type succeeded on $part" >&2
	  fi
	}
  
  # Format root partition with check
  current_fs=$(detect_fs "$ROOT_PART")
  if [ -n "$current_fs" ]; then
    echo "⚠️ Root partition $ROOT_PART already has filesystem: $current_fs"
    read -rp "Do you want to reformat it to $FS_TYPE? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "Formatting root partition with $FS_TYPE..."
      mkfs_with_force "$FS_TYPE" "$ROOT_PART"
	  #mkfs.btrfs -f "$ROOT_PART"
    else
      echo "Keeping existing filesystem on root partition."
    fi
  else
    echo "Formatting root partition with $FS_TYPE...X"
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













  # Mount partitions
  echo "📂 Mounting partitions..."
  mount "$ROOT_PART" /mnt

  if [[ "$FIRMWARE_MODE" == "UEFI" ]]; then
    if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
      mkdir -p /mnt/boot
      mount "$BOOT_PART" /mnt/boot
    else
      mkdir -p /mnt/boot/efi
      mount "$BOOT_PART" /mnt/boot/efi
    fi
  else
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
  fi

  if [[ -n "$HOME_PART" ]]; then
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
  fi

  # Save to config.sh for next stages
  echo "📄 Saving partition info to config.sh..."
  echo "ROOT_PART=\"$ROOT_PART\"" >> config.sh
  echo "BOOT_PART=\"$BOOT_PART\"" >> config.sh
  echo "DRIVE=\"$DRIVE\"" >> config.sh
  [[ -n "$HOME_PART" ]] && echo "HOME_PART=\"$HOME_PART\"" >> config.sh
  [[ -n "$SWAP_PART" ]] && echo "SWAP_PART=\"$SWAP_PART\"" >> config.sh
  [[ -n "$BIOS_GRUB_PART" ]] && echo "BIOS_GRUB_PART=\"$BIOS_GRUB_PART\"" >> config.sh














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

	  echo "🧪 mkfs_with_force called with fs_type=$fs_type, part=$part" >&2

	  echo "🔧 Attempting to unmount $part..." >&2
	  if ! umount "$part" 2>/dev/null; then
		echo "⚠️  Warning: $part was not mounted or failed to unmount (not fatal)" >&2
	  fi

	  echo "💾 Formatting $part as $fs_type..." >&2

	  case "$fs_type" in
		ext4)
		  echo "+ Running: mkfs.ext4 -F $part" >&2
		  mkfs.ext4 -F "$part" ;;
		xfs)
		  echo "+ Running: mkfs.xfs -f $part" >&2
		  mkfs.xfs -f "$part" ;;
		f2fs)
		  echo "+ Running: mkfs.f2fs -f $part" >&2
		  mkfs.f2fs -f "$part" ;;
		btrfs)
		  echo "+ Running: mkfs.btrfs -f $part" >&2
		  mkfs.btrfs -f "$part" ;;
		*)
		  echo "❌ Unknown filesystem type: $fs_type" >&2
		  return 1
		  ;;
	  esac

	  local result=$?
	  if [ $result -ne 0 ]; then
		echo "❌ mkfs.$fs_type failed with exit code $result on $part" >&2
		exit $result
	  else
		echo "✅ mkfs.$fs_type succeeded on $part" >&2
	  fi
	}





  
  
  
  
  
  
  # Format root partition with check
  current_fs=$(detect_fs "$ROOT_PART")
  if [ -n "$current_fs" ]; then
    echo "⚠️ Root partition $ROOT_PART already has filesystem: $current_fs"
    read -rp "Do you want to reformat it to $FS_TYPE? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "Formatting root partition with $FS_TYPE..."
      mkfs_with_force "$FS_TYPE" "$ROOT_PART"
	  #mkfs.btrfs -f "$ROOT_PART"
    else
      echo "Keeping existing filesystem on root partition."
    fi
  else
    echo "Formatting root partition with $FS_TYPE...X"
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
    if [ "$BOOTLOADER" = "systemd-boot" ]; then
      echo "📂 Mounting EFI partition for systemd-boot to /boot..."
      mkdir -p /mnt/boot
      mount "$BOOT_PART" /mnt/boot
    else
      echo "📂 Mounting EFI partition for GRUB to /boot/efi..."
      mkdir -p /mnt/boot/efi
      mount "$BOOT_PART" /mnt/boot/efi
    fi
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


