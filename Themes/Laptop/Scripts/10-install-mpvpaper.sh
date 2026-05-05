#!/bin/bash

set -euo pipefail

PKG="mpvpaper"

if pacman -Qi "$PKG" >/dev/null 2>&1; then
    echo "$PKG (AUR) already installed"
    exit 0
fi

if ! command -v yay >/dev/null 2>&1; then
    echo "Error: yay is required to install $PKG from AUR." >&2
    exit 1
fi

if [[ -n "${SUDO_USER-}" && "$SUDO_USER" != "root" ]]; then
    echo "Installing $PKG from AUR with yay as $SUDO_USER..."
    sudo -H -u "$SUDO_USER" yay -S --noconfirm --needed "$PKG"
else
    echo "Installing $PKG from AUR with yay..."
    yay -S --noconfirm --needed "$PKG"
fi
