#!/bin/bash
set -e

source ./config.sh

echo "👤 Creating a new user account..."

read -rp "Enter new username: " NEW_USER

if [[ -z "$NEW_USER" ]]; then
  echo "❌ Username cannot be empty."
  exit 1
fi

# Save to config for later use
echo "NEW_USER=\"$NEW_USER\"" >> config.sh

arch-chroot /mnt /bin/bash <<EOF

echo "📦 Creating user: $NEW_USER"
useradd -m -G wheel,audio,video,network -s /bin/bash "$NEW_USER"

echo "🔐 Set password for $NEW_USER:"
passwd "$NEW_USER"

echo "🛡️ Setting up sudo access for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

echo "✅ User $NEW_USER created and sudo enabled."
