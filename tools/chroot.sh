#!/bin/bash
set -euo pipefail

MNT_DIR="/mnt"

show_menu() {
  echo "🛠️ Chroot Manager"
  echo "1) 🔐 Mount & Chroot"
  echo "2) 🚪 Unmount & Exit Chroot"
  echo "0) ❌ Cancel"
  echo
  read -rp "Choose an option: " CHOICE
}

mount_and_chroot() {
  echo "🔍 Searching for root partition..."

  # Try auto-detection
  ROOT_PART=$(lsblk -rpno NAME,MOUNTPOINT | grep " /$" | cut -d' ' -f1)

  # Fallback: find the largest ext4/btrfs root partition
  if [[ -z "$ROOT_PART" ]]; then
    ROOT_PART=$(lsblk -rpno NAME,FSTYPE,SIZE | grep -E "ext4|btrfs" | sort -hk3 | tail -n1 | awk '{print $1}')
    echo "⚠️ No mounted / detected. Guessing largest ext4/btrfs: $ROOT_PART"
  fi

  if [[ -z "$ROOT_PART" ]]; then
    echo "❌ Could not determine root partition."
    exit 1
  fi

  echo "📦 Mounting root partition: $ROOT_PART"
  mount "$ROOT_PART" "$MNT_DIR"

  echo "🔧 Binding system directories..."
  for dir in proc sys dev run; do
    mount --bind /$dir "$MNT_DIR/$dir"
  done

  # Mount EFI if detected
  if [ -d "$MNT_DIR/boot/efi" ]; then
    EFI_PART=$(lsblk -rpno NAME,MOUNTPOINT | grep " /boot/efi$" | cut -d' ' -f1)
    if [[ -n "$EFI_PART" ]]; then
      echo "🔧 Mounting EFI: $EFI_PART"
      mount "$EFI_PART" "$MNT_DIR/boot/efi"
    fi
  fi

  echo "🚪 Entering chroot..."
  chroot "$MNT_DIR" /bin/bash
}

unmount_chroot() {
  echo "🔧 Unmounting system directories from $MNT_DIR..."
  for dir in run dev sys proc; do
    umount -R "$MNT_DIR/$dir" 2>/dev/null || echo "⚠️ Could not unmount $dir"
  done

  # Optional: try to unmount boot/efi and root
  umount "$MNT_DIR/boot/efi" 2>/dev/null || true
  umount "$MNT_DIR" 2>/dev/null || true

  echo "✅ Unmount complete. System clean."
}

### MAIN MENU LOOP
show_menu
case "$CHOICE" in
  1) mount_and_chroot ;;
  2) unmount_chroot ;;
  0) echo "❎ Cancelled." ;;
  *) echo "❌ Invalid choice." ;;
esac
