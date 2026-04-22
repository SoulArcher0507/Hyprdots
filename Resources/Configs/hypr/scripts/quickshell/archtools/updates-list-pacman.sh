#!/usr/bin/env bash
set -euo pipefail

if command -v checkupdates >/dev/null 2>&1; then
  checkupdates 2>/dev/null | awk '{print $1}' | sort -u
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp"/{local,cache}
ln -s /var/lib/pacman/local "$tmp/local" 2>/dev/null || true

pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true

pacman -Qu --dbpath "$tmp" 2>/dev/null | awk '{print $1}' | sort -u || true

exit 0

