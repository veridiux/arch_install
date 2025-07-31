#!/bin/bash

set -e

echo "==> Installing mdadm"
pacman -Sy --noconfirm mdadm

echo "==> Generating mdadm.conf"
mdadm --detail --scan > /etc/mdadm.conf

echo "==> Adding mdadm_udev to mkinitcpio.conf"
# This preserves everything before and after "block"
sed -i 's/\(HOOKS=.*\)block/\1mdadm_udev block/' /etc/mkinitcpio.conf

echo "==> Rebuilding initramfs"
mkinitcpio -P

echo "==> Updating GRUB config"
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Checking RAID status"
cat /proc/mdstat

echo "==> mdadm detail output:"
mdadm --detail --scan

echo "==> Done. If no errors above, mdadm is installed and working."
