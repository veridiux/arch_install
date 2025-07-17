#!/bin/bash

# Load this in every module with: source config.sh

# Device & mount point

DRIVE=""
HOME_DRIVE=""
BOOT_PART=""
ROOT_PART=""
HOME_PART=""
SWAP_PART=""
SWAP_SIZE=""  # e.g., 2G

# Filesystem
FS_TYPE="ext4"

# Multilib support
ENABLE_MULTILIB=true  # Set to true to enable multilib repo (needed for Steam, Wine, etc)

# Hostname and locale
HOSTNAME="archlinux"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

# Desktop Environment options
DESKTOP_ENV=""
DE_PACKAGES=()

# GPU type
GPU_TYPE=""
GPU_DRIVER_PACKAGES=()

# Additional packages
EXTRA_PACKAGES=()

# Username
USERNAME="user"
PASSWORD=""

# Boot setup (set by 01-detect-boot.sh)
FIRMWARE_MODE=""
BOOTLOADER=""
