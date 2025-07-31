#!/bin/bash

set -e

# Adjust as needed
ROOT_DEV="/dev/md126p6"
BOOT_DEV="/dev/md126p5"

# Mount root subvolume (@)
mount -o subvol=@ "$ROOT_DEV" /mnt

# Mount other subvolumes (optional, comment if not used)
mkdir -p /mnt/{home,cache,log,snapshots}
mount -o subvol=@home "$ROOT_DEV" /mnt/home
mount -o subvol=@cache "$ROOT_DEV" /mnt/cache
mount -o subvol=@log "$ROOT_DEV" /mnt/log
mount -o subvol=@snapshots "$ROOT_DEV" /mnt/snapshots

# Mount boot partition (adjust path if it's /boot/efi)
mkdir -p /mnt/boot
mount "$BOOT_DEV" /mnt/boot

# If using EFI and boot is under /boot/efi, uncomment:
# mkdir -p /mnt/boot/efi
# mount "$BOOT_DEV" /mnt/boot/efi

# Bind system directories
for dir in proc sys dev run; do
    mount --rbind "/$dir" "/mnt/$dir"
    mount --make-rslave "/mnt/$dir"
done

# Chroot in
echo "Entering chroot..."
chroot /mnt /bin/bash
