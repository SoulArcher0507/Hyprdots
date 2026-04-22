#!/bin/bash

if pacman -Qi "yay" &>/dev/null; then
    echo "yay (AUR) already installed"
else
    echo "=== Installing yay (AUR) ==="
    SCRIPT=$(realpath "$0")
    temp_path=$(dirname "$SCRIPT")
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd $temp_path
    echo "yay has been installed successfully."
fi
