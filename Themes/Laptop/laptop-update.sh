#!/bin/bash

set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$THEME_DIR/../.." && pwd)"

if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
    TARGET_HOME="$HOME"
fi

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR"

source "$REPO_ROOT/Resources/Scripts/hypr_conf_update_notice.sh"
source "$REPO_ROOT/Resources/Scripts/theme_update_scripts.sh"

cleanup_deprecated_hypr_configs() {
    local hypr_dir="$CONFIG_DIR/hypr"

    [[ -d "$hypr_dir" ]] || return 0
    rm -f -- "$hypr_dir/hyprland.conf" "$hypr_dir/colors.conf"

    if [[ -d "$hypr_dir/conf" ]]; then
        find "$hypr_dir/conf" -maxdepth 1 -type f -name "*.conf" -delete
    fi
}

ensure_custom_hypr_config() {
    local custom_file="$CONFIG_DIR/hypr/conf/custom.lua"

    mkdir -p "$(dirname "$custom_file")"
    if [[ ! -e "$custom_file" ]]; then
        printf '%s\n' \
            "-- Local Hyprland customizations." \
            "-- This file is loaded last and is never overwritten by Hyprdots update scripts." \
            > "$custom_file"
    fi
}

echo "=== Updating CorradsLaptop theme ==="
echo ""
echo "Choosing no keeps your current files. Pressing Enter chooses no."
read -r -p "Do you want to update ~/.config/hypr/hyprland.lua and ~/.config/hypr/conf/* from this theme? [y/N] " UPDATE_HYPR_CONF || UPDATE_HYPR_CONF=""

ensure_custom_hypr_config
RSYNC_EXCLUDES=(--exclude "hypr/conf/custom.lua")
case "${UPDATE_HYPR_CONF,,}" in
    y|yes)
        echo "Updating ~/.config/hypr/hyprland.lua and ~/.config/hypr/conf/* files, leaving custom.lua untouched."
        ;;
    *)
        RSYNC_EXCLUDES+=(--exclude "hypr/hyprland.lua")
        RSYNC_EXCLUDES+=(--exclude "hypr/conf/***")
        echo "Keeping current ~/.config/hypr/hyprland.lua and ~/.config/hypr/conf/* files."
        notify_skipped_hypr_conf_changes "$REPO_ROOT" "$THEME_DIR" "$CONFIG_DIR"
        ;;
esac

rsync -av --progress "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/Resources/Configs/" "$CONFIG_DIR/"
rsync -av --progress "${RSYNC_EXCLUDES[@]}" "$THEME_DIR/config/" "$CONFIG_DIR/"
cleanup_deprecated_hypr_configs
mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Icons"
rsync -av --progress "$REPO_ROOT/Resources/Wallpapers/" "$TARGET_HOME/Pictures/Wallpapers/"
rsync -av --progress "$REPO_ROOT/Resources/Icons/" "$TARGET_HOME/Pictures/Icons/"

run_cached_theme_update_scripts "$REPO_ROOT" "$THEME_DIR" "$TARGET_HOME"

echo ""
echo "CorradsLaptop update complete."
