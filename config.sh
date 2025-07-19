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
ENABLE_MULTILIB=""  # Set to true to enable multilib repo (needed for Steam, Wine, etc)

# Hostname and locale
HOSTNAME=""
TIMEZONE=""
LOCALE=""

# Desktop Environment options
DESKTOP_ENV=""
DE_PACKAGES=()

# GPU type
GPU_TYPE=""
GPU_DRIVER_PACKAGES=()

# Additional packages
EXTRA_PACKAGES=()

ENABLE_NETWORKMANAGER=""
ENABLE_BLUETOOTH=""
ENABLE_PRINTING=""
ENABLE_VIRTUALIZATION=""
ENABLE_AUDIO=""




# Username
USERNAME=""
PASSWORD=""

# Boot setup (set by 01-detect-boot.sh)
FIRMWARE_MODE=""
BOOTLOADER=""

