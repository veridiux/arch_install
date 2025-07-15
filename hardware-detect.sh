#!/bin/bash
set -e

source ./config.sh

echo "🔍 Detecting GPU..."

GPU_VENDOR=$(lspci | grep -E "VGA|3D" | awk -F: '{print $3}' | tr '[:upper:]' '[:lower:]')

if echo "$GPU_VENDOR" | grep -q "nvidia"; then
  GPU_TYPE="nvidia"
  GPU_DRIVER_PACKAGES=("nvidia" "nvidia-utils" "nvidia-settings")
elif echo "$GPU_VENDOR" | grep -q "amd"; then
  GPU_TYPE="amd"
  GPU_DRIVER_PACKAGES=("xf86-video-amdgpu" "vulkan-radeon")
elif echo "$GPU_VENDOR" | grep -q "intel"; then
  GPU_TYPE="intel"
  GPU_DRIVER_PACKAGES=("xf86-video-intel" "vulkan-intel")
else
  echo "⚠️ Unknown or unsupported GPU. No specific drivers will be installed."
  GPU_TYPE="unknown"
  GPU_DRIVER_PACKAGES=()
fi

echo "✅ Detected GPU: $GPU_TYPE"
echo "📦 Driver packages to install:"
printf '  - %s\n' "${GPU_DRIVER_PACKAGES[@]}"

# Save for later scripts
echo "GPU_TYPE=\"$GPU_TYPE\"" >> config.sh

# Install inside chroot
if [[ ${#GPU_DRIVER_PACKAGES[@]} -gt 0 ]]; then
  echo "📥 Installing GPU drivers in chroot..."
  arch-chroot /mnt pacman -Sy --noconfirm "${GPU_DRIVER_PACKAGES[@]}"
else
  echo "🚫 Skipping GPU driver install due to unknown hardware."
fi

echo "✅ GPU driver installation complete."
