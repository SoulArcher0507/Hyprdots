#!/usr/bin/env bash
set -euo pipefail

SOURCE_IMAGE="${1:-}"
TARGET_IMAGE="/boot/grub/themes/hyprgrub/background.png"

log() {
    printf '\033[1;36m[HyprGRUB]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[HyprGRUB]\033[0m %s\n' "$*" >&2
    exit 1
}

if [[ -z "$SOURCE_IMAGE" ]]; then
    die "Usage: $(basename "$0") /path/to/image"
fi

if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        die "Root or sudo is required."
    fi
    exec sudo "$0" "$@"
fi

[[ -f "$SOURCE_IMAGE" ]] || die "Source image not found: ${SOURCE_IMAGE}"
[[ -d "$(dirname "$TARGET_IMAGE")" ]] || die "HyprGRUB theme directory not found: $(dirname "$TARGET_IMAGE")"

backup_file() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$file" "$backup"
    log "Backup created: ${backup}"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

backup_file "$TARGET_IMAGE"

if have_cmd magick; then
    magick "$SOURCE_IMAGE" "$TARGET_IMAGE"
elif have_cmd convert; then
    convert "$SOURCE_IMAGE" "$TARGET_IMAGE"
else
    case "${SOURCE_IMAGE##*.}" in
        png|PNG)
            cp -f "$SOURCE_IMAGE" "$TARGET_IMAGE"
            ;;
        *)
            die "ImageMagick is required to convert non-PNG images for GRUB."
            ;;
    esac
fi

chmod 644 "$TARGET_IMAGE"
log "HyprGRUB background updated: ${TARGET_IMAGE}"
