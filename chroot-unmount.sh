#!/bin/bash
set -e

DEVICES=("/dev/sda1" "/dev/sda2")

echo "🔍 Checking and unmounting devices..."

for dev in "${DEVICES[@]}"; do
  echo "➡️ Processing $dev..."

  # Disable swap if active on device
  if swapon --show=NAME | grep -q "^$dev$"; then
    echo "💾 Disabling swap on $dev"
    sudo swapoff "$dev"
  fi

  # Find mountpoints and unmount
  mountpoints=$(mount | grep "^$dev " | awk '{print $3}')
  for mp in $mountpoints; do
    echo "📂 Unmounting $mp"
    sudo umount "$mp" || {
      echo "⚠️ Failed to unmount $mp"
      exit 1
    }
  done

  # Check for LVM logical volumes using this device and deactivate
  if command -v lvs >/dev/null 2>&1; then
    lvs --noheadings -o lv_path | grep "$dev" | while read -r lv; do
      echo "🛑 Deactivating logical volume $lv"
      sudo lvchange -an "$lv"
    done
  fi

done

echo "✅ All done. You can now safely run cfdisk on /dev/sda1 and /dev/sda2."
