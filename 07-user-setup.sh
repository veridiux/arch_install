#!/bin/bash
set -e

source ./config.sh

echo "👤 Creating a new user account..."

read -rp "Enter new username: " NEW_USER

if [[ -z "$NEW_USER" ]]; then
  echo "❌ Username cannot be empty."
  exit 1
fi

# Save to config for later use (optional if used later)
echo "USERNAME=\"$NEW_USER\"" >> config.sh

# Create user inside chroot (non-interactive stuff)
arch-chroot /mnt /bin/bash <<EOF
echo "📦 Creating user: $NEW_USER"
useradd -m -G wheel,audio,video,network -s /bin/bash "$NEW_USER"

echo "🛡️ Setting up sudo access for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# Set password interactively outside the heredoc
echo "🔐 Set password for $NEW_USER:"
arch-chroot /mnt passwd "$NEW_USER"

echo "✅ User $NEW_USER created and sudo enabled."
