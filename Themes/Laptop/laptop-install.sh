#!/bin/bash

set -euo pipefail

THEME_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$THEME_DIR/../.." && pwd)"

if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
    TARGET_HOME="$HOME"
fi

CONFIG_DIR="$TARGET_HOME/.config"

cleanup_deprecated_hypr_configs() {
    local hypr_dir="$CONFIG_DIR/hypr"

    [[ -d "$hypr_dir" ]] || return 0
    rm -f -- "$hypr_dir/hyprland.conf" "$hypr_dir/colors.conf"

    if [[ -d "$hypr_dir/conf" ]]; then
        find "$hypr_dir/conf" -maxdepth 1 -type f -name "*.conf" -delete
    fi
}

echo "=== Package Installation ==="
bash "$REPO_ROOT/Resources/Scripts/packinstall.sh" laptop

mkdir -p "$CONFIG_DIR"
rsync -av --progress "$REPO_ROOT/Resources/Configs/" "$CONFIG_DIR/"
rsync -av --progress "$THEME_DIR/config/" "$CONFIG_DIR/"
cleanup_deprecated_hypr_configs

# GRUB theme installation is handled by the main install.sh flow.

sudo systemctl enable --now power-profiles-daemon.service
