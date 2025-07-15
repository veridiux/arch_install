#!/bin/bash

# Load this in every module with: source config.sh

# Device & mount point
DRIVE=""
BOOT_PART=""
ROOT_PART=""
SWAP_SIZE=""  # e.g., 2G

# Filesystem
FS_TYPE="ext4"

# Hostname and locale
HOSTNAME="archlinux"
TIMEZONE="America/New_York"
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
