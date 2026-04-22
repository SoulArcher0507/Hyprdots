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

echo "=== Package Installation ==="
bash "$REPO_ROOT/Resources/Scripts/packinstall.sh" pc

mkdir -p "$CONFIG_DIR"
rsync -av --progress "$REPO_ROOT/Resources/Configs/" "$CONFIG_DIR/"
rsync -av --progress "$THEME_DIR/config/" "$CONFIG_DIR/"
