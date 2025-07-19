#!/bin/bash

# Ask and save configuration to config.sh

# --- Hostname ---
DEFAULT_HOSTNAME="Archlinux"
read -rp "❓ What is your hostname? [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
echo "$HOSTNAME" > /etc/hostname
echo "HOSTNAME=\"$HOSTNAME\"" >> config.sh

# --- Timezone ---
DEFAULT_TIMEZONE="America/Chicago"
read -rp "🌍 What is your timezone? [$DEFAULT_TIMEZONE]: " TIMEZONE
TIMEZONE=${TIMEZONE:-$DEFAULT_TIMEZONE}
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo "TIMEZONE=\"$TIMEZONE\"" >> config.sh

# --- Locale ---
DEFAULT_LOCALE="en_US"
read -rp "🗣️ What locale do you want to use? [$DEFAULT_LOCALE]: " LOCALE
LOCALE=${LOCALE:-$DEFAULT_LOCALE}
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}.UTF-8" > /etc/locale.conf
echo "LOCALE=\"$LOCALE\"" >> config.sh

# --- Keyboard Layout ---
DEFAULT_KEYMAP="us"
read -rp "⌨️ What keyboard layout do you want? [$DEFAULT_KEYMAP]: " KEYMAP
KEYMAP=${KEYMAP:-$DEFAULT_KEYMAP}
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "KEYMAP=\"$KEYMAP\"" >> config.sh



