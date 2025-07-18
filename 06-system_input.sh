#!/bin/bash

# Prompt for user input
read -rp "Enter your username: " username

# Write the input to config.sh as a variable
echo "USERNAME=\"$username\"" >> config.sh


HOSTNAME="archlinux"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"