#!/bin/bash

# Device to check — adjust if needed
DISK="/dev/sda"

echo "Checking disk: $DISK"

# Check partition table type
PART_TABLE=$(sudo parted $DISK print | grep "Partition Table" | awk '{print $3}')
echo "Partition table type detected: $PART_TABLE"

if [[ "$PART_TABLE" != "gpt" ]]; then
  echo "Warning: Disk is not GPT. This script is designed for GPT BIOS boot."
fi

# Check for BIOS Boot Partition (bios_grub flag)
echo "Checking for BIOS Boot Partition (bios_grub flag)..."
BIOS_BOOT_PART=$(sudo parted -m $DISK print | grep bios_grub | cut -d: -f1)
if [[ -z "$BIOS_BOOT_PART" ]]; then
  echo "No BIOS Boot Partition found."
else
  echo "BIOS Boot Partition found: Partition $BIOS_BOOT_PART"
fi

# Check for boot flag (legacy boot flag) presence (for info)
echo "Partitions with boot flag set:"
sudo parted -m $DISK print | grep boot || echo "None found"

# Check if MBR contains GRUB signature
echo "Checking MBR for GRUB signature..."
MBR_GRUB=$(sudo dd if=$DISK bs=512 count=1 2>/dev/null | strings | grep -i grub)
if [[ -z "$MBR_GRUB" ]]; then
  echo "No GRUB signature found in MBR."
else
  echo "GRUB signature found in MBR."
fi

# Check existence of grub.cfg
if [[ -f /boot/grub/grub.cfg ]]; then
  echo "/boot/grub/grub.cfg found."
else
  echo "Warning: /boot/grub/grub.cfg NOT found."
fi

# Check if /boot/grub directory exists and has files
if [[ -d /boot/grub ]]; then
  FILE_COUNT=$(ls -1 /boot/grub | wc -l)
  echo "/boot/grub directory exists with $FILE_COUNT files."
else
  echo "Warning: /boot/grub directory does NOT exist."
fi

# Final suggestions
echo ""
echo "=== Summary and Suggestions ==="
if [[ "$PART_TABLE" != "gpt" ]]; then
  echo "- Your disk is not GPT; verify your BIOS boot setup accordingly."
fi

if [[ -z "$BIOS_BOOT_PART" ]]; then
  echo "- No BIOS Boot Partition detected. On GPT disks with BIOS boot, create a 1MB bios_grub partition."
fi

if [[ -z "$MBR_GRUB" ]]; then
  echo "- GRUB does not appear installed in MBR. Try reinstalling GRUB on the disk MBR."
fi

if [[ ! -f /boot/grub/grub.cfg ]]; then
  echo "- Missing grub.cfg; run 'sudo grub-mkconfig -o /boot/grub/grub.cfg' to regenerate."
fi

echo "Check your BIOS boot order to ensure this disk is prioritized."
echo "If problems persist, consider booting a live USB and reinstalling GRUB with:"
echo "sudo grub-install --target=i386-pc $DISK"
echo "sudo grub-mkconfig -o /boot/grub/grub.cfg"
