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
