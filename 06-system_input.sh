#!/bin/bash

# Ask and save configuration to config.sh
# --- Hostname ---
read -rp "❓ What is your hostname? [archlinux]: " HOSTNAME
HOSTNAME=${HOSTNAME:-Archlinux}
echo "$HOSTNAME" > /etc/hostname
echo "HOSTNAME=\"$HOSTNAME\"" >> config.sh

# --- Timezone ---
read -rp "🌍 What is your timezone? [UTC] (e.g., Europe/London): " TIMEZONE
TIMEZONE=${TIMEZONE:-America/Chicago}
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo "TIMEZONE=\"$TIMEZONE\"" >> config.sh

# --- Locale ---
read -rp "🗣️ What locale do you want to use? [en_US]: " LOCALE
LOCALE=${LOCALE:-en_US}
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}.UTF-8" > /etc/locale.conf
echo "LOCALE=\"$LOCALE\"" >> config.sh

# --- Keyboard Layout ---
read -rp "⌨️ What keyboard layout do you want? [us]: " KEYMAP
KEYMAP=${KEYMAP:-us}
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "KEYMAP=\"$KEYMAP\"" >> config.sh



