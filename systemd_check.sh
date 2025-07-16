#!/bin/bash
set -e

echo "🔍 Checking systemd health and troubleshooting boot issues..."

# 1. Check systemd version
echo -e "\n1️⃣ systemd version:"
systemctl --version || echo "⚠️ systemctl command not found!"

# 2. Check if systemd process is running (PID 1)
echo -e "\n2️⃣ Is systemd running as PID 1?"
if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
  echo "✅ systemd is running as PID 1"
else
  echo "❌ systemd is NOT running as PID 1! Found: $(ps -p 1 -o comm=)"
fi

# 3. Show failed services
echo -e "\n3️⃣ Failed systemd services:"
failed=$(systemctl --failed --no-legend)
if [[ -z "$failed" ]]; then
  echo "✅ No failed services detected."
else
  echo "$failed"
fi

# 4. Show last 30 journal log lines with priority errors/warnings
echo -e "\n4️⃣ Last 30 journal entries with errors or warnings:"
journalctl -p 3 -n 30 --no-pager || echo "⚠️ journalctl logs unavailable or no errors."

# 5. Check if /etc/fstab exists and is non-empty
echo -e "\n5️⃣ Checking /etc/fstab:"
if [[ -s /etc/fstab ]]; then
  echo "✅ /etc/fstab exists and has content."
else
  echo "❌ /etc/fstab missing or empty!"
fi

# 6. Verify systemd default target
echo -e "\n6️⃣ Current default systemd target:"
default_target=$(systemctl get-default)
echo "🔹 Default target: $default_target"

# 7. Check disk mounts (look for root and boot)
echo -e "\n7️⃣ Mounted file systems (focus on root and boot):"
mount | grep -E ' on /( |/boot|/boot/efi) '

# 8. Check initramfs presence (kernel init image)
echo -e "\n8️⃣ Checking initramfs files:"
initramfs_files=$(ls /boot/initramfs* 2>/dev/null || true)
if [[ -z "$initramfs_files" ]]; then
  echo "❌ No initramfs files found in /boot!"
else
  echo "✅ Found initramfs files:"
  echo "$initramfs_files"
fi

# 9. Verify GRUB configuration (if using grub)
echo -e "\n9️⃣ Checking grub configuration:"
if command -v grub-install &>/dev/null; then
  echo "🔹 grub-install version: $(grub-install --version)"
  grub_cfg="/boot/grub/grub.cfg"
  if [[ -f "$grub_cfg" ]]; then
    echo "✅ Found grub config at $grub_cfg"
  else
    echo "❌ grub config missing at $grub_cfg"
  fi
else
  echo "ℹ️ grub-install not found. Maybe not using GRUB?"
fi

# 10. Check SELinux/AppArmor status (common blockers)
echo -e "\n🔟 SELinux/AppArmor status:"
if command -v getenforce &>/dev/null; then
  echo "SELinux mode: $(getenforce)"
else
  echo "SELinux not installed or disabled."
fi

if command -v aa-status &>/dev/null; then
  echo "AppArmor status:"
  aa-status
else
  echo "AppArmor not installed or disabled."
fi

echo -e "\n✅ systemd diagnostics complete."
echo "Check the above outputs for errors or suspicious messages."
