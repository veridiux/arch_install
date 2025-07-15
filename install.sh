#!/bin/bash
set -e

SCRIPTS=(
  "01-detect-boot.sh"
  "02-precheck.sh"
  "03-disk-setup.sh"
  "04-base-install.sh"
  "05-hardware-detect.sh"
  "06-system-config.sh"
  "07-de-install.sh"
  "08-user-setup.sh"
  "09-package-select.sh"
  "10-finalize.sh"
)

echo "🚀 Starting Arch Linux Automated Installer..."

for script in "${SCRIPTS[@]}"; do
  echo "----------------------------------------"
  echo "▶️ Running $script"
  ./"$script"
  echo "✅ Finished $script"
done

echo "🎉 Installation complete!"
