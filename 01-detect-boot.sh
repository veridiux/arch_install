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

# Write firmware mode to config
sed -i "/^FIRMWARE_MODE=/c\FIRMWARE_MODE=\"$FIRMWARE_MODE\"" config.sh

# Choose bootloader
if [ "$FIRMWARE_MODE" = "UEFI" ]; then
  echo "💻 Choose a bootloader:"
  select bl in "GRUB" "systemd-boot"; do
    case "$bl" in
      GRUB ) BOOTLOADER="grub"; break ;;
      systemd-boot ) BOOTLOADER="systemd-boot"; break ;;
    esac
  done
else
  echo "⛔ Only GRUB is supported on BIOS systems."
  BOOTLOADER="grub"
fi

# Write bootloader to config
sed -i "/^BOOTLOADER=/c\BOOTLOADER=\"$BOOTLOADER\"" config.sh

echo "✅ Bootloader: $BOOTLOADER"
echo "✅ Firmware: $FIRMWARE_MODE"
