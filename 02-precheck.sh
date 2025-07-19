#!/bin/bash
set -e

source ./config.sh

echo "🔍 Checking internet connection..."
if ! ping -q -c 1 archlinux.org >/dev/null; then
  echo "❌ No internet connection. Please connect and rerun."
  echo "You can use iwctl to connect to wireless"
  echo "iwctl"
  echo "device list"
  echo "station YOURDEVICE scan"
  echo "station YOURDEVICE connect NETWORKNAME"
  exit 1
fi

echo "✅ Internet connected."

echo "🌐 Syncing time with NTP..."
timedatectl set-ntp true
echo "🕒 NTP enabled."

echo "✔️ Pre-checks complete."
