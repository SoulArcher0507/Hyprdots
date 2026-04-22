#!/usr/bin/env bash
set -euo pipefail

log() { echo "[INFO] $*"; }
ok()  { echo "[OK] $*"; }
err() { echo "[ERROR] $*" >&2; }

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

mkdir -p "$CONFIG_DIR"

if [[ -f "$MIMEAPPS_FILE" ]]; then
    cp "$MIMEAPPS_FILE" "$BACKUP_FILE"
    log "Existing mimeapps.list backed up to: $BACKUP_FILE"
fi

log "Writing clean mimeapps.list for user: $TARGET_USER"

cat > "$MIMEAPPS_FILE" <<'EOF'
[Added Associations]
inode/directory=org.kde.dolphin.desktop;
text/plain=nvim.desktop;
text/markdown=nvim.desktop;
application/json=nvim.desktop;
application/x-shellscript=nvim.desktop;
text/html=vivaldi-stable.desktop;
application/xhtml+xml=vivaldi-stable.desktop;
x-scheme-handler/http=vivaldi-stable.desktop;
x-scheme-handler/https=vivaldi-stable.desktop;
x-scheme-handler/about=vivaldi-stable.desktop;
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
text/html=vivaldi-stable.desktop;
application/xhtml+xml=vivaldi-stable.desktop;
x-scheme-handler/http=vivaldi-stable.desktop;
x-scheme-handler/https=vivaldi-stable.desktop;
x-scheme-handler/about=vivaldi-stable.desktop;
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

echo
echo "Verify with:"
echo "  xdg-mime query default image/png"
echo "  xdg-mime query default application/zip"
