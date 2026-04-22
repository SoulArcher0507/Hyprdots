#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 && -z "${SUDO_USER-}" ]]; then
    echo "Run this script as a regular user."
    exit 1
fi

if [[ -n "${SUDO_USER-}" ]]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$USER"
fi

TARGET_HOME="$(eval echo "~$TARGET_USER")"
CONFIG_DIR="$TARGET_HOME/.config"

run_target_cmd() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SUDO_USER="$TARGET_USER" "$@"
    else
        "$@"
    fi
}

run_target_bash() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SUDO_USER="$TARGET_USER" bash "$@"
    else
        bash "$@"
    fi
}

echo ""

run_target_bash "$SCRIPT_DIR/Resources/Scripts/yay.sh"

echo ""

run_target_cmd mkdir -p "$CONFIG_DIR"
run_target_cmd mkdir -p \
    "$TARGET_HOME/Desktop" \
    "$TARGET_HOME/Documents" \
    "$TARGET_HOME/Downloads" \
    "$TARGET_HOME/Music" \
    "$TARGET_HOME/Packages" \
    "$TARGET_HOME/Pictures" \
    "$TARGET_HOME/Public" \
    "$TARGET_HOME/Templates" \
    "$TARGET_HOME/Videos"

echo "=== Theme Selection ==="

THEME_SCRIPTS=()
while IFS= read -r -d '' f; do
    THEME_SCRIPTS+=("$f")
done < <(find "$SCRIPT_DIR/Themes" -mindepth 2 -maxdepth 2 -name "*-install.sh" -print0 | sort -z)

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
        run_target_bash "$SCRIPT_PATH"
        break
    fi

    echo "Not a valide choice."
    echo ""
    for i in "${!THEME_LABELS[@]}"; do
        echo "  [$((i+1))] ${THEME_LABELS[$i]}"
    done
    echo ""
done

bash "$SCRIPT_DIR/Resources/Grub/grubsouls-theme/install_theme.sh"
bash "$SCRIPT_DIR/Resources/Scripts/install_sddm.sh"
bash "$SCRIPT_DIR/Resources/Scripts/change_sddm_avatar.sh" "$TARGET_USER" "$SCRIPT_DIR/Resources/Wallpapers/shadow_army.jpg"
bash "$SCRIPT_DIR/Resources/Scripts/install_plymouth_theme.sh" "colorful_loop" "$SCRIPT_DIR/Resources/Plymouth/plymouth-themes"
run_target_bash "$SCRIPT_DIR/Resources/Scripts/zsh_enabler.sh"
bash "$SCRIPT_DIR/Resources/Scripts/dynamic_swap_file.sh"
run_target_bash "$SCRIPT_DIR/Resources/Scripts/default_webapps.sh"

run_target_cmd mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Icons"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Wallpapers/" "$TARGET_HOME/Pictures/Wallpapers/"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Icons/" "$TARGET_HOME/Pictures/Icons/"

$TARGET_HOME/.config/awww/wallpaper.sh "$TARGET_HOME/Pictures/Wallpapers/shadow_army.jpg"

echo "=== END OF INSTALLATION ==="