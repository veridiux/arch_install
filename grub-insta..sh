#!/usr/bin/env bash
# install_grub.sh
# This script installs GRUB with all modules on an EFI system.

set -euo pipefail

# Define all GRUB modules
GRUB_MODULES="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo cryptodisk luks lvm mdraid09 mdraid1x raid5rec raid6rec play cpuid tpm"

# EFI directory and GRUB bootloader ID
EFI_DIR="/efi"
BOOTLOADER_ID="GRUB"

echo "Installing GRUB with all modules..."
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory="$EFI_DIR" \
    --bootloader-id="$BOOTLOADER_ID" \
    --modules="$GRUB_MODULES" \
    --sbat /usr/share/grub/sbat.csv

echo "GRUB installation complete."
