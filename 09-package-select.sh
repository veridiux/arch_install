#!/bin/bash
set -e

source ./config.sh

echo "🎁 Optional Package Sets"

declare -A PACKAGE_SETS

# Define named sets here for easy extension
# PACKAGE_SETS=(
#   ["Dev Tools"]="git base-devel cmake python python-pip"
#   ["Browsers"]="firefox chromium"
#   ["Gaming"]="steam lutris mangohud"
#   ["Media"]="vlc mpv ffmpeg"
#   ["Office"]="libreoffice-fresh hunspell-en_us"
#   ["Bluetooth"]="bluez bluez-utils blueman"
#   ["Utility"]="rsync zip unzip tar rsync"
#   ["Custom"]="wget git networkmanager curl vim neovim network-manager-applet"
#   ["Audio"]="pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol"
# )


PACKAGE_SETS=(
  ["Dev Tools"]="git base-devel cmake python python-pip gcc make gdb pkgconf"
  ["Browsers"]="firefox chromium"
  ["Gaming"]="steam lutris mangohud gamemode wine winetricks"
  ["Media"]="vlc mpv ffmpeg obs-studio"
  ["Office"]="libreoffice-fresh hunspell-en_us evince"
  ["Bluetooth"]="bluez bluez-utils blueman"
  ["Utility"]="rsync zip unzip tar htop btop curl wget file"
  ["Custom"]="wget git networkmanager curl vim neovim network-manager-applet"
  ["Audio"]="pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol alsa-utils"
  ["Fonts"]="ttf-dejavu ttf-liberation noto-fonts ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono"
  ["Printing"]="cups system-config-printer gutenprint"
  ["Virtualization"]="qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils libvirt"
  ["Development GUIs"]="code geany meld"
  ["Shell Tools"]="zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting"
  ["Theming"]="lxappearance papirus-icon-theme kvantum qt5ct"
)






SELECTED_PACKAGES=()

echo "📚 Choose package sets to install (multiple OK):"
i=1
for key in "${!PACKAGE_SETS[@]}"; do
  echo "$i) $key"
  SET_KEYS[$i]="$key"
  ((i++))
done
echo "0) Done selecting sets"

while true; do
  read -rp "Select a set by number (0 to finish): " SET_CHOICE
  if [[ "$SET_CHOICE" == "0" ]]; then
    break
  elif [[ -n "${SET_KEYS[$SET_CHOICE]}" ]]; then
    SET_NAME="${SET_KEYS[$SET_CHOICE]}"
    echo "✅ Added: $SET_NAME"
    SELECTED_PACKAGES+=(${PACKAGE_SETS[$SET_NAME]})
  else
    echo "❌ Invalid choice."
  fi
done

# Allow custom packages
echo ""
read -rp "📦 Enter additional individual packages (space-separated), or press Enter to skip: " CUSTOM_INPUT

if [[ -n "$CUSTOM_INPUT" ]]; then
  IFS=' ' read -r -a CUSTOM_PACKS <<< "$CUSTOM_INPUT"
  SELECTED_PACKAGES+=("${CUSTOM_PACKS[@]}")
fi

# Remove duplicates
UNIQUE_PACKS=($(echo "${SELECTED_PACKAGES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ ${#UNIQUE_PACKS[@]} -gt 0 ]]; then
  echo "📦 Final package list:"
  printf '  - %s\n' "${UNIQUE_PACKS[@]}"

  echo "📥 Installing packages..."
  arch-chroot /mnt pacman -Sy --noconfirm "${UNIQUE_PACKS[@]}"
else
  echo "ℹ️ No extra packages selected."
fi

# Optional: Save the list for auditing
printf "%s\n" "${UNIQUE_PACKS[@]}" > /mnt/root/installed-extra-packages.txt

echo "✅ Extra package installation complete."
