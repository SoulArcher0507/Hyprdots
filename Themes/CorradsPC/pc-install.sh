#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$TARGET_HOME/.config"
# Home directory user
if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
    TARGET_HOME="$HOME"
fi

# Package installation
echo "=== Package Installation ==="
bash "$SCRIPT_DIR/Resources/Scripts/packinstall.sh pc"

rsync -av --progress "$SCRIPT_DIR/CorradsPC/config" "$CONFIG_DIR/"

