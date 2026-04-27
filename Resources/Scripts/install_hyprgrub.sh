#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ORIGINAL_ARGS=("$@")

THEME_NAME="hyprgrub"
SRC_THEME_DIR="${RESOURCES_DIR}/Grub/${THEME_NAME}"
TARGET_THEMES_DIR="/boot/grub/themes"
GRUB_DEFAULT="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"
RUN_MKCONFIG=true

log() {
    printf '\033[1;36m[HyprGRUB]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[HyprGRUB]\033[0m %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --target-dir DIR      Install theme under DIR/${THEME_NAME}
                        Default: ${TARGET_THEMES_DIR}
  --grub-default FILE   Path to the GRUB defaults file
                        Default: ${GRUB_DEFAULT}
  --grub-cfg FILE       Path to the generated GRUB config
                        Default: ${GRUB_CFG}
  --no-mkconfig         Do not regenerate grub.cfg after installation
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dir)
            [[ $# -ge 2 ]] || die "Missing value for --target-dir."
            TARGET_THEMES_DIR="$2"
            shift 2
            ;;
        --grub-default)
            [[ $# -ge 2 ]] || die "Missing value for --grub-default."
            GRUB_DEFAULT="$2"
            shift 2
            ;;
        --grub-cfg)
            [[ $# -ge 2 ]] || die "Missing value for --grub-cfg."
            GRUB_CFG="$2"
            shift 2
            ;;
        --no-mkconfig)
            RUN_MKCONFIG=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        die "Root or sudo is required."
    fi
    exec sudo "$0" "${ORIGINAL_ARGS[@]}"
fi

TARGET_THEME_DIR="${TARGET_THEMES_DIR}/${THEME_NAME}"
GRUB_THEME_PATH="${TARGET_THEME_DIR}/theme.txt"

backup_file() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$file" "$backup"
    log "Backup created: ${backup}"
}

set_grub_default_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp

    tmp="$(mktemp)"
    awk -v key="$key" -v value="$value" '
        BEGIN {
            written = 0
            pattern = "^[[:space:]]*#?[[:space:]]*" key "="
        }

        $0 ~ pattern {
            if (!written) {
                print key "=\"" value "\""
                written = 1
            }
            next
        }

        { print }

        END {
            if (!written) {
                print key "=\"" value "\""
            }
        }
    ' "$file" > "$tmp"

    install -m 644 "$tmp" "$file"
    rm -f "$tmp"
}

generate_grub_config() {
    if command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o "$GRUB_CFG"
        return 0
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub
        return 0
    fi

    die "Could not find grub-mkconfig or update-grub. Run grub-mkconfig manually."
}

[[ -d "$SRC_THEME_DIR" ]] || die "Theme directory not found: ${SRC_THEME_DIR}"
[[ -f "${SRC_THEME_DIR}/theme.txt" ]] || die "Missing theme.txt in ${SRC_THEME_DIR}"
[[ -f "$GRUB_DEFAULT" ]] || die "GRUB defaults file not found: ${GRUB_DEFAULT}"

log "Installing ${THEME_NAME} to ${TARGET_THEME_DIR} ..."
mkdir -p "$TARGET_THEMES_DIR"
rm -rf "$TARGET_THEME_DIR"
cp -a "$SRC_THEME_DIR" "$TARGET_THEME_DIR"
find "$TARGET_THEME_DIR" -name '*.swp' -delete

log "Updating ${GRUB_DEFAULT} ..."
backup_file "$GRUB_DEFAULT"
set_grub_default_value "$GRUB_DEFAULT" "GRUB_THEME" "$GRUB_THEME_PATH"
set_grub_default_value "$GRUB_DEFAULT" "GRUB_TERMINAL_OUTPUT" "gfxterm"

if grep -Eq '^[[:space:]]*GRUB_BACKGROUND=' "$GRUB_DEFAULT"; then
    log "GRUB_BACKGROUND is set too; GRUB_THEME will take precedence on standard GRUB configs."
fi

if [[ "$RUN_MKCONFIG" == true ]]; then
    log "Generating ${GRUB_CFG} ..."
    generate_grub_config
else
    log "Skipping grub.cfg generation."
fi

log "Installation completed."
log "Theme path: ${GRUB_THEME_PATH}"
