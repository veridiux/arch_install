#!/bin/bash
set -e

DEVICES=("/dev/sda1" "/dev/sda2")

echo "🔍 Attempting to free devices..."

for dev in "${DEVICES[@]}"; do
  echo "➡️ Processing $dev..."

  # Disable swap if active on device
  if swapon --show=NAME | grep -q "^$dev$"; then
    echo "💾 Disabling swap on $dev"
    sudo swapoff "$dev"
  fi

  # Find and unmount all mount points on this device (recursively)
  mountpoints=$(mount | grep "^$dev " | awk '{print $3}' | sort -r)
  for mp in $mountpoints; do
    echo "📂 Unmounting $mp"
    sudo umount -Rl "$mp" || {
      echo "⚠️ Failed to unmount $mp"
    }
  done

  # Kill any process using the device
  pids=$(lsof "$dev" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
  if [[ -n "$pids" ]]; then
    echo "🛑 Killing processes using $dev: $pids"
    sudo kill -9 $pids || true
  fi

  # Deactivate any LVM logical volumes using this device
  if command -v lvs >/dev/null 2>&1; then
    lvs --noheadings -o lv_path | grep "$dev" | while read -r lv; do
      echo "🔧 Deactivating logical volume $lv"
      sudo lvchange -an "$lv" || true
    done
  fi

done

echo "✅ Cleanup complete. Try cfdisk again."
