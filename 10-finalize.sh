#!/bin/bash
set -e

read -rp "🔁 Would you like to check some things over? [Y/n]: " FINISH_CHOICE

if [[ "$FINISH_CHOICE" =~ ^([Nn])$ ]]; then
  echo "💤 Exiting without reboot."
  echo "Make sure to run reboot.sh when you're done to finish unmounting everything"
  exit 0
fi

echo "🧹 Cleaning up and unmounting..."



# Disable swap if any
if swapon --show | grep -q '/mnt/swapfile'; then
  swapoff /mnt/swapfile
fi


# Unmount in reverse order
umount -R /mnt

sync

echo "✅ All partitions unmounted and synced."

read -rp "🔁 Reboot system now? [Y/n]: " REBOOT_CHOICE

if [[ "$REBOOT_CHOICE" =~ ^([Nn])$ ]]; then
  echo "💤 Exiting without reboot."
  exit 0
else
  echo "♻️ Rebooting..."
  reboot
fi
