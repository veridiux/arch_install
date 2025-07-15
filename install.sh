#!/bin/bash
set -e

SCRIPTS=(
  "01-precheck.sh"
  
  "01-disk-setup.sh"
  "02-base-install.sh"
  "03-hardware-detect.sh"
  "04-system-config.sh"
  "05-de-install.sh"
  "06-user-setup.sh"
  "07-package-select.sh"
  "08-finalize.sh"
)

echo "🚀 Starting Arch Linux Automated Installer..."

for script in "${SCRIPTS[@]}"; do
  echo "----------------------------------------"
  echo "▶️ Running $script"
  ./"$script"
  echo "✅ Finished $script"
done

echo "🎉 Installation complete!"
