#!/bin/bash
set -e

source ./config.sh

echo "🎨 Choose a desktop environment to install:"
echo "1) GNOME"
echo "2) KDE Plasma"
echo "3) XFCE"
echo "4) Cinnamon"
echo "5) MATE"
echo "6) i3 (tiling window manager)"
echo "7) Sway (Wayland i3 fork)"
echo "8) Hyprland (Wayland dynamic tiling WM)"
echo "0) Skip DE install (headless/server)"

read -rp "Enter choice [0-8]: " DE_CHOICE

case $DE_CHOICE in
  1)
    DESKTOP_ENV="gnome"
    DE_PACKAGES=("gnome" "gdm" "gnome-tweaks" "gnome-terminal")
    DISPLAY_MANAGER="gdm"
    ;;
  2)
    DESKTOP_ENV="kde"
    DE_PACKAGES=("plasma" "sddm" "konsole" "dolphin")
    DISPLAY_MANAGER="sddm"
    ;;
  3)
    DESKTOP_ENV="xfce"
    DE_PACKAGES=("xfce4" "xfce4-goodies" "lightdm" "lightdm-gtk-greeter")
    DISPLAY_MANAGER="lightdm"
    ;;
  4)
    DESKTOP_ENV="cinnamon"
    DE_PACKAGES=("cinnamon" "lightdm" "lightdm-gtk-greeter")
    DISPLAY_MANAGER="lightdm"
    ;;
  5)
    DESKTOP_ENV="mate"
    DE_PACKAGES=("mate" "mate-extra" "lightdm" "lightdm-gtk-greeter")
    DISPLAY_MANAGER="lightdm"
    ;;
  6)
    DESKTOP_ENV="i3"
    DE_PACKAGES=("i3-wm" "i3status" "dmenu" "xterm" "lightdm" "lightdm-gtk-greeter")
    DISPLAY_MANAGER="lightdm"
    ;;
  7)
    DESKTOP_ENV="sway"
    DE_PACKAGES=("sway" "swaybg" "foot" "waybar")
    DISPLAY_MANAGER=""  # TTY/greetd recommended
    ;;
  8)
    DESKTOP_ENV="hyprland"
    DE_PACKAGES=(
      "hyprland" "xdg-desktop-portal-hyprland" "waybar" "foot"
      "rofi" "dunst" "thunar" "pavucontrol" "brightnessctl"
      "network-manager-applet" "wl-clipboard" "hyprpaper" "swww"
    )
    DISPLAY_MANAGER=""  # TTY or greetd recommended
    ;;
  0)
    echo "⚠️ Skipping DE install."
    DESKTOP_ENV="none"
    DE_PACKAGES=()
    DISPLAY_MANAGER=""
    ;;
  *)
    echo "❌ Invalid choice. Aborting."
    exit 1
    ;;
esac


echo "📦 Installing DE: $DESKTOP_ENV"
if [[ ${#DE_PACKAGES[@]} -gt 0 ]]; then
  arch-chroot /mnt pacman -Sy --noconfirm "${DE_PACKAGES[@]}"
else
  echo "➡️ No DE packages selected."
fi

# Enable display manager if applicable
if [[ -n "$DISPLAY_MANAGER" ]]; then
  echo "⚙️ Enabling display manager: $DISPLAY_MANAGER"
  arch-chroot /mnt systemctl enable "$DISPLAY_MANAGER"
fi

# Save for future
echo "DESKTOP_ENV=\"$DESKTOP_ENV\"" >> config.sh
echo "DISPLAY_MANAGER=\"$DISPLAY_MANAGER\"" >> config.sh

echo "✅ Desktop environment installation complete."
