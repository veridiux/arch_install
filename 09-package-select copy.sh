#!/bin/bash
set -e

source ./config.sh

echo "🎁 Optional Package Sets"

declare -A PACKAGE_SETS

PACKAGE_SETS=(
  ["Dev Tools"]="git base-devel cmake python python-pip gcc make gdb pkgconf"
  ["Browsers"]="firefox chromium"
  ["Gaming"]="steam lutris mangohud gamemode wine winetricks"
  ["Media"]="vlc mpv ffmpeg obs-studio"
  ["Office"]="libreoffice-fresh hunspell-en_us evince"
  ["Bluetooth"]="bluez bluez-utils blueman"
  ["Utility"]="rsync zip unzip tar htop btop curl wget file"
  ["Custom"]="wget git networkmanager curl vim neovim network-manager-applet"
  ["Audio"]="pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol"
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
    # Use quotes to avoid word splitting issues
    SELECTED_PACKAGES+=(${PACKAGE_SETS[$SET_NAME]})
  else
    echo "❌ Invalid choice."
  fi
done

echo ""
read -rp "📦 Enter additional individual packages (space-separated), or press Enter to skip: " CUSTOM_INPUT

if [[ -n "$CUSTOM_INPUT" ]]; then
  IFS=' ' read -r -a CUSTOM_PACKS <<< "$CUSTOM_INPUT"
  SELECTED_PACKAGES+=("${CUSTOM_PACKS[@]}")
fi

# Remove duplicates
# Save old IFS, set to newline, sort unique, restore IFS
OLDIFS=$IFS
IFS=$'\n'
UNIQUE_PACKS=($(printf "%s\n" "${SELECTED_PACKAGES[@]}" | sort -u))
IFS=$OLDIFS

if [[ ${#UNIQUE_PACKS[@]} -gt 0 ]]; then
  echo "📦 Final package list:"
  for pkg in "${UNIQUE_PACKS[@]}"; do
    echo "  - $pkg"
  done

  echo "📥 Installing packages..."
  arch-chroot /mnt pacman -Sy --noconfirm "${UNIQUE_PACKS[@]}"
else
  echo "ℹ️ No extra packages selected."
fi

printf "%s\n" "${UNIQUE_PACKS[@]}" > /mnt/root/installed-extra-packages.txt

# Dynamically set enable flags based on selected packages
ENABLE_NETWORKMANAGER="no"
ENABLE_BLUETOOTH="no"
ENABLE_PRINTING="no"
ENABLE_VIRTUALIZATION="no"
ENABLE_AUDIO="no"

for pkg in "${UNIQUE_PACKS[@]}"; do
  case $pkg in
    networkmanager|network-manager-applet)
      ENABLE_NETWORKMANAGER="yes"
      ;;
    bluez|blueman)
      ENABLE_BLUETOOTH="yes"
      ;;
    cups|system-config-printer|gutenprint)
      ENABLE_PRINTING="yes"
      ;;
    libvirt|virt-manager|qemu)
      ENABLE_VIRTUALIZATION="yes"
      ;;
    pipewire|pipewire-pulse|wireplumber)
      ENABLE_AUDIO="yes"
      ;;
  esac
done

enable_services() {
  echo "🔧 Enabling services inside chroot..."

  if [[ "$ENABLE_NETWORKMANAGER" == "yes" ]]; then
    echo " - Enabling NetworkManager"
    arch-chroot /mnt systemctl enable NetworkManager
  fi

  if [[ "$ENABLE_BLUETOOTH" == "yes" ]]; then
    echo " - Enabling Bluetooth"
    arch-chroot /mnt systemctl enable bluetooth
  fi

  if [[ "$ENABLE_PRINTING" == "yes" ]]; then
    echo " - Enabling CUPS (printing)"
    arch-chroot /mnt systemctl enable cups
  fi

  if [[ "$ENABLE_VIRTUALIZATION" == "yes" ]]; then
    echo " - Enabling libvirtd (virtualization)"
    arch-chroot /mnt systemctl enable libvirtd
    if [[ -n "$USERNAME" ]]; then
      arch-chroot /mnt usermod -aG libvirt "$USERNAME"
    else
      echo "⚠️ USERNAME not set, skipping usermod for libvirt group"
    fi
  fi

  if [[ "$ENABLE_AUDIO" == "yes" ]]; then
    echo " - Enabling user audio services (PipeWire)"
    if [[ -n "$USERNAME" ]]; then
      arch-chroot /mnt sudo -u "$USERNAME" systemctl --user enable pipewire pipewire-pulse wireplumber || echo "⚠️ Could not enable pipewire user services (this may require user login)"
      arch-chroot /mnt sudo -u "$USERNAME" systemctl --user start pipewire pipewire-pulse wireplumber || echo "⚠️ Could not start pipewire user services"
    else
      echo "⚠️ USERNAME not set, skipping pipewire user services enabling"
    fi
  fi

  echo "✅ Service enabling complete."
}

enable_services

echo "✅ Extra package installation complete."
