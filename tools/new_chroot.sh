#!/bin/bash
set -e

ROOT_DEV="/dev/md126p6"
BOOT_DEV="/dev/md126p5"
MNT="/mnt"

# Mount main root subvolume (@)
mkdir -p "$MNT"
mount -o subvol=@ "$ROOT_DEV" "$MNT"

# Mount top-level subvolumes - adjust these if yours differ
mkdir -p "$MNT"/{home,root,srv,tmp,var/cache,var/log}
mount -o subvol=@home "$ROOT_DEV" "$MNT/home"
mount -o subvol=@root "$ROOT_DEV" "$MNT/root"
mount -o subvol=@srv "$ROOT_DEV" "$MNT/srv"
mount -o subvol=@tmp "$ROOT_DEV" "$MNT/tmp"
mount -o subvol=@cache "$ROOT_DEV" "$MNT/var/cache"
mount -o subvol=@log "$ROOT_DEV" "$MNT/var/log"

# Mount nested subvolumes inside @
mkdir -p "$MNT/var/lib/portables" "$MNT/var/lib/machines"
mount -o subvol=@/var/lib/portables "$ROOT_DEV" "$MNT/var/lib/portables"
mount -o subvol=@/var/lib/machines "$ROOT_DEV" "$MNT/var/lib/machines"

# Mount EFI partition (adjust mount point if needed)
mkdir -p "$MNT/boot/efi"
mount "$BOOT_DEV" "$MNT/boot/efi"

# Bind mount system directories
for dir in proc sys dev run; do
    mount --rbind "/$dir" "$MNT/$dir"
    mount --make-rslave "$MNT/$dir"
done

# Enter chroot
echo "Entering chroot environment..."
chroot "$MNT" /bin/bash
