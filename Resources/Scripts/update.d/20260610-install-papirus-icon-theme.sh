#!/bin/bash
set -euo pipefail

PKG="papirus-icon-theme"

if pacman -Q "$PKG" >/dev/null 2>&1; then
  echo "$PKG already installed"
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

pacman -S --noconfirm --needed "$PKG"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for theme_dir in /usr/share/icons/Papirus /usr/share/icons/Papirus-Dark; do
    [[ -d "$theme_dir" ]] && gtk-update-icon-cache -f -t "$theme_dir" >/dev/null 2>&1 || true
  done
fi

if command -v xdg-icon-resource >/dev/null 2>&1; then
  xdg-icon-resource forceupdate >/dev/null 2>&1 || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 >/dev/null 2>&1 || true
fi
