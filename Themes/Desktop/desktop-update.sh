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

echo "=== Updating Desktop theme ==="
echo ""
echo "Choosing no keeps your current files, but keeping old Hypr config files can break something important."
read -r -p "Do you want to update ~/.config/hypr/conf/* from this theme? [Y/n] " UPDATE_HYPR_CONF || UPDATE_HYPR_CONF=""

RSYNC_EXCLUDES=()
case "${UPDATE_HYPR_CONF,,}" in
    n|no)
        RSYNC_EXCLUDES+=(--exclude "hypr/conf/***")
        echo "Keeping current ~/.config/hypr/conf/* files."
        notify_skipped_hypr_conf_changes "$REPO_ROOT" "$THEME_DIR" "$CONFIG_DIR"
        ;;
    *)
        echo "Updating ~/.config/hypr/conf/* files."
        ;;
esac

rsync -av --progress "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/Resources/Configs/" "$CONFIG_DIR/"
rsync -av --progress "${RSYNC_EXCLUDES[@]}" "$THEME_DIR/config/" "$CONFIG_DIR/"
mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Icons"
rsync -av --progress "$REPO_ROOT/Resources/Wallpapers/" "$TARGET_HOME/Pictures/Wallpapers/"
rsync -av --progress "$REPO_ROOT/Resources/Icons/" "$TARGET_HOME/Pictures/Icons/"

if [[ -d "$THEME_DIR/Scripts" ]]; then
    while IFS= read -r -d '' script; do
        echo "Running theme patch: $(basename "$script")"
        bash "$script"
    done < <(find "$THEME_DIR/Scripts" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)
fi

echo ""
echo "Desktop update complete."
