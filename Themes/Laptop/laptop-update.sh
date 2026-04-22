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

echo "=== Updating CorradsLaptop theme ==="
rsync -av --progress "$REPO_ROOT/Resources/Configs/" "$CONFIG_DIR/"
rsync -av --progress "$THEME_DIR/config/" "$CONFIG_DIR/"
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
echo "CorradsLaptop update complete."
