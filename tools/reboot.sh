#!/bin/bash
set -e
# Testing

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
