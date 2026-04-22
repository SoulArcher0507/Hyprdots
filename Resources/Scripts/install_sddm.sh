#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if [[ -d "${RESOURCES_DIR}/Sddm/silent" ]]; then
    SRC_THEME_DIR="${RESOURCES_DIR}/Sddm/silent"
elif [[ -f "${RESOURCES_DIR}/Sddm/Main.qml" ]]; then
    SRC_THEME_DIR="${RESOURCES_DIR}/Sddm"
else
    echo "Error: SilentSDDM theme not found."
    echo "Expected one of these paths:"
    echo "  - ${RESOURCES_DIR}/Sddm/silent"
    echo "  - ${RESOURCES_DIR}/Sddm"
    exit 1
fi

THEMES_DIR="/usr/share/sddm/themes"
TARGET_THEME_DIR="${THEMES_DIR}/silent"
FONTS_DIR="/usr/share/fonts"
SDDM_CONF="/etc/sddm.conf"

if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Error: root or sudo is required."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

log() {
    printf '\033[1;36m[SilentSDDM]\033[0m %s\n' "$*"
}

set_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    local tmp
    tmp="$(mktemp)"

    awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN {
        in_section = 0
        section_found = 0
        key_written = 0
    }

    function print_key() {
        print key "=" value
    }

    /^\[.*\]$/ {
        if (in_section && !key_written) {
            print_key()
            key_written = 1
        }

        if ($0 == "[" section "]") {
            in_section = 1
            section_found = 1
        } else {
            in_section = 0
        }

        print
        next
    }

    {
        if (in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
            if (!key_written) {
                print_key()
            }
            key_written = 1
            next
        }

        print
    }

    END {
        if (!section_found) {
            if (NR > 0) print ""
            print "[" section "]"
            print_key()
        } else if (in_section && !key_written) {
            print_key()
        }
    }' "$file" > "$tmp"

    command mv -f "$tmp" "$file"
}

log "Copying theme to ${TARGET_THEME_DIR} ..."
$SUDO mkdir -p "$THEMES_DIR"
$SUDO rm -rf "$TARGET_THEME_DIR"
$SUDO cp -a "$SRC_THEME_DIR" "$TARGET_THEME_DIR"

log "Copying required fonts ..."
for font_subdir in redhat redhat-vf; do
    if [[ -d "${TARGET_THEME_DIR}/fonts/${font_subdir}" ]]; then
        $SUDO rm -rf "${FONTS_DIR}/${font_subdir}"
        $SUDO cp -a "${TARGET_THEME_DIR}/fonts/${font_subdir}" "${FONTS_DIR}/"
    fi
done

if command -v fc-cache >/dev/null 2>&1; then
    $SUDO fc-cache -f >/dev/null 2>&1 || true
fi

log "Updating ${SDDM_CONF} ..."

TMP_CONF="$(mktemp)"
if [[ -f "$SDDM_CONF" ]]; then
    $SUDO cp -a "$SDDM_CONF" "$TMP_CONF"
else
    : > "$TMP_CONF"
fi

set_ini_value "$TMP_CONF" "Theme" "Current" "silent"
set_ini_value "$TMP_CONF" "General" "InputMethod" "qtvirtualkeyboard"
set_ini_value "$TMP_CONF" "General" "GreeterEnvironment" "QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard"

$SUDO install -m 644 "$TMP_CONF" "$SDDM_CONF"
rm -f "$TMP_CONF"

log "Installation completed."
log "Theme installed in: ${TARGET_THEME_DIR}"
log "Active SDDM theme: silent"

echo
echo "Recommended to test before reboot with:"
echo "  cd ${TARGET_THEME_DIR}"
echo "  ./test.sh"
