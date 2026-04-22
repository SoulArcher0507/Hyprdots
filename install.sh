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

echo ""

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR"

mkdir -p "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Music" \
    "$HOME/Packages" "$HOME/Pictures" "$HOME/Public" "$HOME/Templates" \
    "$HOME/Videos"

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

sudo bash "$SCRIPT_DIR/Resources/Grub/grubsouls-theme/install_theme.sh"
bash "$SCRIPT_DIR/Resources/Scripts/dolphin-terminal.sh"
bash "$SCRIPT_DIR/Resources/Scripts/install_sddm.sh"
sudo bash "$SCRIPT_DIR/Resources/Scripts/change_sddm_avatar.sh $(whoami) $SCRIPT_DIR/Resources/Wallpapers/shadow_army.jpg"
bash "$SCRIPT_DIR/Resources/Scripts/install_plymouth_repo_theme.sh" "colorful_loop" "$SCRIPT_DIR/Resources/Plymouth/plymouth-themes"
bash "$SCRIPT_DIR/Resources/Scripts/zsh_enabler.sh"
bash "$SCRIPT_DIR/Resources/Scripts/dynamic_swap_file.sh"
bash "$SCRIPT_DIR/Resources/Scripts/default_webapps.sh"

rsync -av --progress "$SCRIPT_DIR/Resources/Wallpapers" "$HOME/Pictures/Wallpapers"
rsync -av --progress "$SCRIPT_DIR/Resources/Icons" "$HOME/Pictures/Icons"


