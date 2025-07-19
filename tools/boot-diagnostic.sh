#!/bin/bash

echo "🔍 Boot Diagnostics (Chroot-Aware)"
echo

# Check chroot context
if mount | grep -q '/mnt'; then
    echo "⚠️ Warning: You may not be in a proper chroot environment."
else
    echo "✅ Chroot detected"
fi

# Detect UEFI vs BIOS
if [ -d /sys/firmware/efi ]; then
    echo "🧭 Boot Mode: UEFI"
    BOOT_MODE="UEFI"
else
    echo "🧭 Boot Mode: BIOS (Legacy)"
    BOOT_MODE="BIOS"
fi

# Detect Partition Table
DISK=$(lsblk -no pkname $(findmnt / -o SOURCE -n))
PART_TABLE=$(parted /dev/$DISK print | grep 'Partition Table' | awk '{print $3}')
echo "📦 Partition Table: $PART_TABLE"

# Match check
if [[ "$BOOT_MODE" == "UEFI" && "$PART_TABLE" != "gpt" ]]; then
    echo "⚠️ UEFI boot with non-GPT partitioning — this may not be supported!"
elif [[ "$BOOT_MODE" == "BIOS" && "$PART_TABLE" == "gpt" ]]; then
    echo "ℹ️ BIOS boot with GPT — this is valid but requires special boot setup (BIOS boot partition)"
else
    echo "✅ Boot mode and partition table seem compatible"
fi

# Check for bootloaders
echo
echo "🔍 Bootloader Check:"

# GRUB
if [[ -x /boot/grub/grub.cfg || -f /boot/grub/grub.cfg || -f /etc/default/grub ]]; then
    echo "✅ GRUB config found"
else
    echo "❌ No GRUB config found"
fi

# systemd-boot
if [[ -d /boot/loader || -d /boot/efi/loader ]]; then
    echo "✅ systemd-boot loader directory found"
else
    echo "❌ No systemd-boot loader directory found"
fi

# LILO
if [[ -f /etc/lilo.conf ]]; then
    echo "✅ LILO config found"
else
    echo "❌ No LILO config found"
fi

# Check initramfs + kernel
echo
echo "🧪 Kernel & Initramfs:"
[[ -f /boot/vmlinuz-linux ]] && echo "✅ Kernel found: /boot/vmlinuz-linux" || echo "❌ Kernel missing"
[[ -f /boot/initramfs-linux.img ]] && echo "✅ Initramfs found" || echo "❌ Initramfs missing"

# EFI partition mounted?
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    echo
    echo "🧬 UEFI Boot Partition Check:"
    if mount | grep -qE "/boot|/boot/efi"; then
        echo "✅ EFI partition appears to be mounted"
        find /boot /boot/efi -type f -iname "*.efi" 2>/dev/null | grep -qi . && echo "✅ EFI bootloader file present" || echo "❌ No EFI binaries found"
    else
        echo "❌ EFI partition not mounted"
    fi
fi

echo
echo "✅ Diagnostics complete."
