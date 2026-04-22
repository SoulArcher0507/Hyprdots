#!/bin/bash

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    if [[ -n "${SUDO_USER-}" ]]; then
        exec sudo -H -u "$SUDO_USER" bash "$0" "$@"
    fi
    echo "Run this script as a regular user."
    exit 1
fi

if pacman -Qi yay &>/dev/null; then
    echo "yay (AUR) already installed"
    exit 0
fi

echo "=== Installing yay (AUR) ==="

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
(
    cd "$TMP_DIR/yay"
    makepkg -si --noconfirm
)

echo "yay has been installed successfully."
