#!/bin/bash
set -euo pipefail

echo "🔍 Boot Diagnostics Script (Chroot-Aware)"
MNT="/mnt"

# Detect root partition if not set
ROOT_PART=$(findmnt "$MNT" -n -o SOURCE || lsblk -rpno NAME,MOUNTPOINT | grep "$MNT" | awk '{print $1}')
DISK=$(lsblk -no pkname "$ROOT_PART" | head -n1)

echo ""
echo "📦 Boot Device: $DISK"
echo "📁 Mounted Root: $ROOT_PART at $MNT"

### 1. Boot Mode
if [[ -d "$MNT/sys/firmware/efi" ]]; then
  echo "🧭 Boot Mode: UEFI"
  BOOT_MODE="UEFI"
else
  echo "🧭 Boot Mode: BIOS (Legacy)"
  BOOT_MODE="BIOS"
fi

### 2. Partition Table
PART_TABLE=$(parted "/dev/$DISK" print | grep 'Partition Table' | awk '{print $3}')
echo "💾 Partition Table: $PART_TABLE"

### 3. EFI Partition (if UEFI)
if [[ "$BOOT_MODE" == "UEFI" ]]; then
  EFI_PART=$(lsblk -rpno NAME,FSTYPE,MOUNTPOINT | grep -i 'vfat' | grep -Ei 'efi|boot')
  if [[ -z "$EFI_PART" ]]; then
    echo "❌ EFI partition not found! (Expected FAT32 with boot or esp flag)"
  else
    echo "✅ EFI Partition Found: $EFI_PART"
  fi
fi

### 4. Bootloader Detection
echo ""
echo "🚦 Bootloader Detection:"
[[ -d "$MNT/boot/grub" ]] && echo "🔹 GRUB detected in /boot/grub" || echo "⚠️ GRUB not detected"
[[ -d "$MNT/boot/loader" ]] && echo "🔹 systemd-boot detected in /boot/loader" || echo "⚠️ systemd-boot not detected"
[[ -f "$MNT/etc/lilo.conf" ]] && echo "🔹 LILO config found in /etc/lilo.conf" || echo "⚠️ LILO not detected"

### 5. EFI Boot Entries
if [[ "$BOOT_MODE" == "UEFI" ]]; then
  echo ""
  echo "📋 EFI Boot Entries:"
  if command -v efibootmgr &>/dev/null; then
    efibootmgr || echo "⚠️ efibootmgr could not retrieve entries (may need UEFI firmware)"
  else
    echo "⚠️ efibootmgr not available"
  fi
fi

### 6. Boot Files
echo ""
echo "📁 Boot File Check in $MNT/boot:"
[[ -f "$MNT/boot/vmlinuz-linux" ]] && echo "✅ Kernel: vmlinuz-linux found"
[[ -f "$MNT/boot/initramfs-linux.img" ]] && echo "✅ Initramfs: initramfs-linux.img found"
[[ -f "$MNT/boot/grub/grub.cfg" ]] && echo "✅ GRUB config found"
[[ -f "$MNT/boot/loader/loader.conf" ]] && echo "✅ systemd-boot loader.conf found"

### 7. BIOS Boot Code (if BIOS mode)
if [[ "$BOOT_MODE" == "BIOS" ]]; then
  echo ""
  echo "🔍 MBR Boot Code Check..."
  file -s "/dev/$DISK" | grep -q "boot sector" && echo "✅ MBR boot code present" || echo "⚠️ MBR boot code missing"
fi

echo ""
echo "✅ Boot diagnostics complete."
