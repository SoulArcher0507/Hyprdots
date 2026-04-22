#!/usr/bin/env bash
set -euo pipefail

BASE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/quickshell/archtools/"

"${BASE}/updates-list-pacman.sh" 2>/dev/null || true
"${BASE}/updates-list-aur.sh" 2>/dev/null || true
"${BASE}/updates-list-flatpak.sh" 2>/dev/null || true

