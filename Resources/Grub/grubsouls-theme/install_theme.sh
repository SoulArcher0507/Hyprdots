#!/bin/bash

set -euo pipefail

# === Config ===
theme_name="grubsouls"
systemd_service="grubsouls-update.service"
background_script="choose_background.sh"

log() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*"
}

error() {
    echo "[ERROR] $*" >&2
}

ok() {
    echo "[OK] $*"
}

backup_once() {
    local source_file="$1"
    local backup_file="$2"

    if [[ ! -e "$backup_file" ]]; then
        cp -a "$source_file" "$backup_file"
        ok "Backup created: $backup_file"
    else
        log "Backup already exists: $backup_file"
    fi
}

set_grub_default() {
    local key="$1"
    local value="$2"
    local file="$3"
    local escaped_value

    escaped_value=$(printf '%s' "$value" | sed 's/[&/\\]/\\&/g')

    if grep -qE "^[[:space:]]*${key}=" "$file"; then
        sed -i -E "s|^[[:space:]]*${key}=.*|${key}=\"${escaped_value}\"|" "$file"
    else
        printf '%s="%s"\n' "$key" "$value" >> "$file"
    fi
}

# === 1. Root Check ===
if [[ $(id -u) -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
fi

# === 2. Determine Script Directory ===
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
if [[ -z "$SCRIPT_DIR" || "$SCRIPT_DIR" == "/" ]]; then
    error "Invalid script directory. Exiting."
    exit 1
fi

# === 3. Locate GRUB Directory ===
if [[ -d /boot/grub ]]; then
    grub_path="/boot/grub"
elif [[ -d /boot/grub2 ]]; then
    grub_path="/boot/grub2"
else
    error "Could not find /boot/grub or /boot/grub2"
    exit 1
fi

theme_path="$grub_path/themes/$theme_name"
default_grub_file="/etc/default/grub"
header_file="/etc/grub.d/00_header"

# === 4. Optional Background Selection ===
echo
read -rp "[?] Choose a specific background from ./background_galery/? [y/N] " -n 1 choose_bg
printf '\n'
if [[ "$choose_bg" =~ [yY] ]]; then
    if [[ -x "$SCRIPT_DIR/$background_script" ]]; then
        log "Running background selection script..."
        "$SCRIPT_DIR/$background_script"
    else
        warn "Script '$background_script' not found or not executable."
    fi
else
    log "Skipping background selection."
fi

# === 5. Install Theme ===
echo
read -rp "[?] Copy/update theme to '$theme_path'? [Y/n] " -n 1 copy_theme
printf '\n'
if [[ ! "$copy_theme" =~ ^[nN]$ ]]; then
    if [[ ! -d "$SCRIPT_DIR/$theme_name" ]]; then
        error "Theme folder '$theme_name' not found in script directory."
        exit 1
    fi

    log "Copying theme..."
    mkdir -p "$grub_path/themes/"
    cp -ruv "$SCRIPT_DIR/$theme_name" "$grub_path/themes/"
    ok "Theme copied."
else
    log "Skipping theme installation."
fi

# === 6. Optional systemd Service Install ===
echo
read -rp "[?] Install systemd service to update theme on boot? [y/N] " -n 1 install_service
printf '\n'
if [[ "$install_service" =~ [yY] ]]; then
    if [[ -f "$SCRIPT_DIR/$systemd_service" ]]; then
        log "Installing service..."
        cp -uv "$SCRIPT_DIR/$systemd_service" /etc/systemd/system/
        systemctl daemon-reload
        ok "Service installed."
    else
        warn "Service file '$systemd_service' not found."
    fi
else
    log "Skipping service installation."
fi

# === 7. Optional Patch for GRUB_BACKGROUND ===
echo
read -rp "[?] Patch /etc/grub.d/00_header for GRUB_BACKGROUND support? [y/N] " -n 1 patch_header
printf '\n'
if [[ "$patch_header" =~ [yY] ]]; then
    backup_file="$SCRIPT_DIR/00_header.bak"
    backup_once "$header_file" "$backup_file"

    if grep -q 'fi; if.*GRUB_BACKGROUND' "$header_file"; then
        log "Patch already present in $header_file."
    else
        log "Applying patch..."
        sed -i -E 's/(.*)elif(.*"x\$GRUB_BACKGROUND" != x ] && \[ -f "\$GRUB_BACKGROUND" \].*)/\1fi; if\2/' "$header_file"
        ok "Patch applied."
    fi
else
    log "Skipping patch."
fi

# === 8. Automatically update /etc/default/grub ===
if [[ ! -f "$default_grub_file" ]]; then
    error "$default_grub_file not found."
    exit 1
fi

if [[ ! -f "$theme_path/theme.txt" ]]; then
    error "Theme file not found: $theme_path/theme.txt"
    exit 1
fi

if [[ ! -f "$theme_path/terminal_background.png" ]]; then
    error "Background file not found: $theme_path/terminal_background.png"
    exit 1
fi

default_backup="$SCRIPT_DIR/grub.default.bak"
backup_once "$default_grub_file" "$default_backup"

log "Updating $default_grub_file..."
set_grub_default "GRUB_THEME" "$theme_path/theme.txt" "$default_grub_file"
set_grub_default "GRUB_BACKGROUND" "$theme_path/terminal_background.png" "$default_grub_file"
ok "$default_grub_file updated."

# === 9. Regenerate GRUB config ===
grub_mkconfig_cmd=""
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub_mkconfig_cmd="grub-mkconfig"
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub_mkconfig_cmd="grub2-mkconfig"
else
    error "Neither grub-mkconfig nor grub2-mkconfig was found in PATH."
    exit 1
fi

log "Regenerating GRUB configuration..."
"$grub_mkconfig_cmd" -o "$grub_path/grub.cfg"
ok "GRUB configuration regenerated: $grub_path/grub.cfg"

# === 10. Final Output ===
echo
echo "========= Installation Complete ========="
echo "GRUB theme set to: $theme_path/theme.txt"
echo "GRUB background set to: $theme_path/terminal_background.png"
echo "GRUB config generated at: $grub_path/grub.cfg"
echo "============================================"
