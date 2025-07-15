#!/bin/bash
set -e

SCRIPTS=(
  "01-precheck.sh"
  "02-disk-setup.sh"
  "03-base-install.sh"
  "04-hardware-detect.sh"
  "05-system-config.sh"
  "06-de-install.sh"
  "07-user-setup.sh"
  "08-package-select.sh"
  "09-finalize.sh"
)

echo "🚀 Starting Arch Linux Automated Installer..."

for script in "${SCRIPTS[@]}"; do
  echo "----------------------------------------"
  echo "▶️ Running $script"
  ./"$script"
  echo "✅ Finished $script"
done

echo "🎉 Installation complete!"
