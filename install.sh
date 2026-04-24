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
TARGET_REPO_DIR="$CONFIG_DIR/Hyprdots"
LEGACY_REPO_LINK="$CONFIG_DIR/hyprdots"

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

finalize_repo_location() {
    local source_dir
    source_dir="$(cd -- "$SCRIPT_DIR" && pwd -P)"

    run_target_cmd mkdir -p "$CONFIG_DIR"

    if run_target_cmd test -d "$TARGET_REPO_DIR/.git"; then
        echo "Hyprdots repo already available in $TARGET_REPO_DIR"
    elif [[ "$source_dir" == "$TARGET_REPO_DIR" ]]; then
        echo "Hyprdots repo already installed in $TARGET_REPO_DIR"
    elif run_target_cmd test -e "$TARGET_REPO_DIR"; then
        echo "Skipping repo move because $TARGET_REPO_DIR already exists"
    else
        echo "Moving Hyprdots repo to $TARGET_REPO_DIR"
        run_target_cmd mv "$source_dir" "$TARGET_REPO_DIR"
    fi

    if run_target_cmd test -e "$LEGACY_REPO_LINK" && ! run_target_cmd test -L "$LEGACY_REPO_LINK"; then
        echo "Skipping legacy link because $LEGACY_REPO_LINK already exists and is not a symlink"
        return
    fi

    echo "Linking legacy path $LEGACY_REPO_LINK -> $TARGET_REPO_DIR"
    run_target_cmd ln -sfn "$TARGET_REPO_DIR" "$LEGACY_REPO_LINK"
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

if pacman -Q dunst >/dev/null 2>&1; then
    sudo pacman -R --noconfirm dunst
fi

bash "$SCRIPT_DIR/Resources/Scripts/install_sddm.sh"
sudo bash "$SCRIPT_DIR/Resources/Scripts/change_sddm_avatar.sh" "$TARGET_USER" "$SCRIPT_DIR/Resources/Wallpapers/elden.png"
sudo bash "$SCRIPT_DIR/Resources/Scripts/install_plymouth_theme.sh" "lone" "$SCRIPT_DIR/Resources/Plymouth/plymouth-themes"
run_target_bash "$SCRIPT_DIR/Resources/Scripts/zsh_enabler.sh"
sudo bash "$SCRIPT_DIR/Resources/Scripts/dynamic_swap_file.sh"
run_target_bash "$SCRIPT_DIR/Resources/Scripts/default_webapps.sh"

run_target_cmd mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Icons"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Wallpapers/" "$TARGET_HOME/Pictures/Wallpapers/"
run_target_cmd rsync -av --progress "$SCRIPT_DIR/Resources/Icons/" "$TARGET_HOME/Pictures/Icons/"

run_target_cmd env WALLPAPER_SYNC_COLORS=1 "$TARGET_HOME/.config/awww/wallpaper.sh" "$TARGET_HOME/Pictures/Wallpapers/default.jpg"

sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now cups.service 
sudo usermod -aG lp $USER   # add user to printer group
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now firewalld
sudo systemctl enable --now tailscaled

finalize_repo_location

echo "=== INSTALLATION COMPLETE ==="
