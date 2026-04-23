#!/usr/bin/env bash
set -euo pipefail

log() { echo "[INFO] $*"; }
ok()  { echo "[OK] $*"; }
err() { echo "[ERROR] $*" >&2; }

run_as_target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
else
    TARGET_USER="$(id -un)"
    TARGET_HOME="$HOME"
fi

if [[ -z "${TARGET_HOME:-}" || ! -d "$TARGET_HOME" ]]; then
    err "Unable to determine target home directory."
    exit 1
fi

CONFIG_DIR="$TARGET_HOME/.config"
MIMEAPPS_FILE="$CONFIG_DIR/mimeapps.list"
BACKUP_FILE="$MIMEAPPS_FILE.bak.$(date +%Y%m%d-%H%M%S)"
BROWSER_DESKTOP_ID="vivaldi-stable.desktop"

mkdir -p "$CONFIG_DIR"

for candidate in vivaldi-stable.desktop vivaldi.desktop; do
    if [[ -f "/usr/share/applications/$candidate" || -f "$TARGET_HOME/.local/share/applications/$candidate" ]]; then
        BROWSER_DESKTOP_ID="$candidate"
        break
    fi
done

if [[ -f "$MIMEAPPS_FILE" ]]; then
    cp "$MIMEAPPS_FILE" "$BACKUP_FILE"
    log "Existing mimeapps.list backed up to: $BACKUP_FILE"
fi

log "Writing clean mimeapps.list for user: $TARGET_USER"
log "Default browser desktop entry: $BROWSER_DESKTOP_ID"

cat > "$MIMEAPPS_FILE" <<EOF
[Added Associations]
inode/directory=org.kde.dolphin.desktop;
text/plain=nvim.desktop;
text/markdown=nvim.desktop;
application/json=nvim.desktop;
application/x-shellscript=nvim.desktop;
text/html=$BROWSER_DESKTOP_ID;
application/xhtml+xml=$BROWSER_DESKTOP_ID;
x-scheme-handler/http=$BROWSER_DESKTOP_ID;
x-scheme-handler/https=$BROWSER_DESKTOP_ID;
x-scheme-handler/about=$BROWSER_DESKTOP_ID;
application/pdf=org.kde.okular.desktop;
image/jpeg=org.kde.gwenview.desktop;
image/png=org.kde.gwenview.desktop;
image/gif=org.kde.gwenview.desktop;
image/svg+xml=org.kde.gwenview.desktop;
audio/mpeg=vlc.desktop;
audio/flac=vlc.desktop;
audio/x-opus+ogg=vlc.desktop;
video/mp4=vlc.desktop;
video/quicktime=vlc.desktop;
video/vnd.avi=vlc.desktop;
video/x-matroska=vlc.desktop;
application/zip=org.kde.ark.desktop;

[Default Applications]
inode/directory=org.kde.dolphin.desktop;
text/plain=nvim.desktop;
text/markdown=nvim.desktop;
application/json=nvim.desktop;
application/x-shellscript=nvim.desktop;
text/html=$BROWSER_DESKTOP_ID;
application/xhtml+xml=$BROWSER_DESKTOP_ID;
x-scheme-handler/http=$BROWSER_DESKTOP_ID;
x-scheme-handler/https=$BROWSER_DESKTOP_ID;
x-scheme-handler/about=$BROWSER_DESKTOP_ID;
application/pdf=org.kde.okular.desktop;
image/jpeg=org.kde.gwenview.desktop;
image/png=org.kde.gwenview.desktop;
image/gif=org.kde.gwenview.desktop;
image/svg+xml=org.kde.gwenview.desktop;
audio/mpeg=vlc.desktop;
audio/flac=vlc.desktop;
audio/x-opus+ogg=vlc.desktop;
video/mp4=vlc.desktop;
video/quicktime=vlc.desktop;
video/vnd.avi=vlc.desktop;
video/x-matroska=vlc.desktop;
application/zip=org.kde.ark.desktop;
EOF

chown "$TARGET_USER:$TARGET_USER" "$MIMEAPPS_FILE" 2>/dev/null || true

ok "mimeapps.list written to: $MIMEAPPS_FILE"

if command -v xdg-settings >/dev/null 2>&1; then
    run_as_target_user env HOME="$TARGET_HOME" xdg-settings set default-web-browser "$BROWSER_DESKTOP_ID" || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
    for mime in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about; do
        run_as_target_user env HOME="$TARGET_HOME" xdg-mime default "$BROWSER_DESKTOP_ID" "$mime" || true
    done
fi

ok "Default browser set to: $BROWSER_DESKTOP_ID"

echo
echo "Verify with:"
echo "  xdg-settings get default-web-browser"
echo "  xdg-mime query default x-scheme-handler/https"
echo "  xdg-mime query default image/png"
echo "  xdg-mime query default application/zip"
