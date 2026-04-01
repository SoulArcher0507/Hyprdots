#!/bin/bash

set -euo pipefail 

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""

# Home directory user
if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
    TARGET_HOME="$HOME"
fi

# yay installation
bash "$SCRIPT_DIR/Resources/Scripts/yay.sh"

# Package installation
echo "=== Package Installation ==="
bash "$SCRIPT_DIR/Resources/Scripts/packinstall.sh"

echo ""

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR"

# Theme selection
echo "=== Theme Selection ==="

THEME_SCRIPTS=()
while IFS= read -r -d '' f; do
  THEME_SCRIPTS+=("$f")
done < <(find "$SCRIPT_DIR/Themes" -mindepth 2 -maxdepth 2 -name "*.sh" -print0 | sort -z)

THEME_LABELS=()
for f in "${THEME_SCRIPTS[@]}"; do
  label="$(basename "$(dirname "$f")")/$(basename "$f")"
  THEME_LABELS+=("$label")
done

echo "Scripts available:"
for i in "${!THEME_LABELS[@]}"; do
  echo "  [$((i+1))] ${THEME_LABELS[$i]}"
done
echo ""

PS3="Insert theme number: "
select LABEL in "${THEME_LABELS[@]}"; do
  if [[ -n "$LABEL" ]]; then
    IDX=$((REPLY-1))
    SCRIPT_PATH="${THEME_SCRIPTS[$IDX]}"
    echo ""
    echo "Installing: $SCRIPT_PATH"
    bash "$SCRIPT_PATH"
    break
  else
    echo "Not a valide choice."
    echo ""
    for i in "${!THEME_LABELS[@]}"; do
      echo "  [$((i+1))] ${THEME_LABELS[$i]}"
    done
    echo ""
  fi
done

mkdir -p "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Music" \
    "$HOME/Packages" "$HOME/Pictures" "$HOME/Public" "$HOME/Templates" \
    "$HOME/Videos"


bash "$script_dir/scripts/dolphin-terminal.sh"
bash "$script_dir/scripts/corradspc-installer.sh"

cp -r "Resources/Wallpapers" "$HOME/Pictures/Wallpapers"
cp -r "Resources/Icons" "$HOME/Pictures/Icons"

