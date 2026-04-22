#!/usr/bin/env bash

MANAGER="${1:-}"
PKG_NAME="${2:-}"

if [[ -z "$PKG_NAME" ]]; then
    echo "No package specified."
    exit 1
fi

case "$MANAGER" in
    pacman)
        pacman -Si "$PKG_NAME"
        ;;
    yay)
        yay -Si "$PKG_NAME"
        ;;
    flatpak)
        flatpak info "$PKG_NAME"
        ;;
    *)
        yay -Si "$PKG_NAME" 2>/dev/null || pacman -Si "$PKG_NAME" 2>/dev/null || flatpak info "$PKG_NAME"
        ;;
esac
