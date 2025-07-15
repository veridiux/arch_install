#!/bin/bash
set -e

echo "🔍 Detecting firmware type..."

if [ -d /sys/firmware/efi ]; then
  echo "✅ UEFI system detected."
  FIRMWARE_MODE="UEFI"
else
  echo "⚠️ BIOS (Legacy) system detected."
  FIRMWARE_MODE="BIOS"
fi

# Ensure config.sh has FIRMWARE_MODE line; add if missing
if grep -q "^FIRMWARE_MODE=" config.sh; then
  sed -i "/^FIRMWARE_MODE=/c\FIRMWARE_MODE=\"$FIRMWARE_MODE\"" config.sh
else
  echo "FIRMWARE_MODE=\"$FIRMWARE_MODE\"" >> config.sh
fi

# Choose bootloader based on firmware
if [ "$FIRMWARE_MODE" = "UEFI" ]; then
  echo "💻 Choose a bootloader:"
  select bl in "GRUB" "systemd-boot"; do
    case "$bl" in
      GRUB ) BOOTLOADER="grub"; break ;;
      systemd-boot ) BOOTLOADER="systemd-boot"; break ;;
      * ) echo "Invalid choice. Please select 1 or 2." ;;
    esac
  done
else
  echo "⛔ Only GRUB is supported on BIOS systems."
  BOOTLOADER="grub"
fi

# Ensure config.sh has BOOTLOADER line; add if missing
if grep -q "^BOOTLOADER=" config.sh; then
  sed -i "/^BOOTLOADER=/c\BOOTLOADER=\"$BOOTLOADER\"" config.sh
else
  echo "BOOTLOADER=\"$BOOTLOADER\"" >> config.sh
fi

echo "✅ Bootloader: $BOOTLOADER"
echo "✅ Firmware: $FIRMWARE_MODE"
