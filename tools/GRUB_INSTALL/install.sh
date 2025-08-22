#!/usr/bin/env bash
set -euo pipefail

# Install required tools
sudo pacman -S --needed sbsigntools sbctl efibootmgr grub

EFI_DIR="/efi"
BOOTLOADER_ID="GRUB"
GRUB_MODULES="all_video efi_gop efi_uga linux search normal test echo configfile loadenv gfxterm gfxmenu"

# Prepare EFI directories
sudo mkdir -p $EFI_DIR/EFI/BOOT
sudo mkdir -p $EFI_DIR/EFI/$BOOTLOADER_ID

# Copy shim if you have it
# (make sure shimx64.efi and mmx64.efi exist in ./shim-signed/)
sudo cp ./shim-signed/shimx64.efi $EFI_DIR/EFI/BOOT/BOOTX64.EFI
sudo cp ./shim-signed/mmx64.efi   $EFI_DIR/EFI/BOOT/

# Copy keys (assumes you already created them)
sudo cp -R ./KEY $EFI_DIR/EFI/

echo "Installing GRUB..."
sudo grub-install \
  --target=x86_64-efi \
  --efi-directory="$EFI_DIR" \
  --bootloader-id="$BOOTLOADER_ID" \
  --sbat /usr/share/grub/sbat.csv \
  --modules="$GRUB_MODULES" \
  --no-nvram

echo "Signing GRUB..."
sudo sbsign \
  --key $EFI_DIR/EFI/KEY/MOK.key \
  --cert $EFI_DIR/EFI/KEY/MOK.crt \
  --output $EFI_DIR/EFI/$BOOTLOADER_ID/grubx64.efi \
  $EFI_DIR/EFI/$BOOTLOADER_ID/grubx64.efi

# Copy signed GRUB into fallback BOOT dir as well
sudo cp $EFI_DIR/EFI/$BOOTLOADER_ID/grubx64.efi $EFI_DIR/EFI/BOOT/

echo "GRUB installation complete."
echo "Example efibootmgr command (replace disk/part!):"
echo "  sudo efibootmgr --unicode --disk /dev/nvme0n1 --part 1 --create --label \"Shim\" --loader '\\EFI\\BOOT\\BOOTX64.EFI'"

