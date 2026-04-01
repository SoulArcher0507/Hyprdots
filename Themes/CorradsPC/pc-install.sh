#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$TARGET_HOME/.config"

rsync -av --progress "$SCRIPT_DIR/CorradsPC/config" "$CONFIG_DIR/"

