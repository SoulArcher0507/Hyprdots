#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$USER"
fi

TARGET_HOME="$(eval echo "~$TARGET_USER")"
CONFIG_DIR="$TARGET_HOME/.config"

source "$SCRIPT_DIR/Resources/Scripts/hypr_conf_update_notice.sh"
source "$SCRIPT_DIR/Resources/Scripts/update_scripts.sh"

run_target_cmd() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SUDO_USER="$TARGET_USER" "$@"
    else
        "$@"
    fi
}

cleanup_deprecated_hypr_configs() {
    local hypr_dir="$CONFIG_DIR/hypr"

    run_target_cmd test -d "$hypr_dir" || return 0
    run_target_cmd rm -f -- "$hypr_dir/hyprland.conf" "$hypr_dir/colors.conf"

    if run_target_cmd test -d "$hypr_dir/conf"; then
        run_target_cmd find "$hypr_dir/conf" -maxdepth 1 -type f -name "*.conf" -delete
    fi
}

ensure_custom_hypr_config() {
    local custom_file="$CONFIG_DIR/hypr/conf/custom.lua"

    run_target_cmd mkdir -p "$(dirname "$custom_file")"
    if ! run_target_cmd test -e "$custom_file"; then
        run_target_cmd tee "$custom_file" >/dev/null <<'EOF'
-- Local Hyprland customizations.
-- This file is loaded last and is never overwritten by Hyprdots update scripts.
EOF
    fi
}

reload_hyprland() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

echo "=== Updating Hyprdots ==="
echo ""
echo "Choosing no keeps your current Hyprland Lua files. Pressing Enter chooses no."
read -r -p "Do you want to update ~/.config/hypr/hyprland.lua and ~/.config/hypr/conf/*? [y/N] " UPDATE_HYPR_CONF || UPDATE_HYPR_CONF=""

run_target_cmd mkdir -p "$CONFIG_DIR"
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
        notify_skipped_hypr_conf_changes "$SCRIPT_DIR" "$SCRIPT_DIR/Resources" "$CONFIG_DIR"
        ;;
esac

run_target_cmd rsync -av --progress "${RSYNC_EXCLUDES[@]}" "$SCRIPT_DIR/Resources/Configs/" "$CONFIG_DIR/"
cleanup_deprecated_hypr_configs

run_target_cmd mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Icons"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Wallpapers/" "$TARGET_HOME/Pictures/Wallpapers/"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Icons/" "$TARGET_HOME/Pictures/Icons/"

run_cached_update_scripts "$SCRIPT_DIR" "$TARGET_HOME"
reload_hyprland

echo ""
echo "Hyprdots update complete."
