#!/usr/bin/env bash

set -u

delay="${1:-20}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
portal_conf="$config_dir/hyprland-portals.conf"
runtime_conf="$config_dir/hyprland-portals-kde-filechooser.conf"

sleep "$delay"
mkdir -p "$config_dir"

cat > "$runtime_conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Settings=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.FileChooser=kde
org.freedesktop.impl.portal.AppChooser=gtk
EOF

cat > "$portal_conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Settings=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.FileChooser=kde
org.freedesktop.impl.portal.AppChooser=gtk
EOF

systemctl --user start plasma-xdg-desktop-portal-kde.service >/dev/null 2>&1 || true
systemctl --user restart \
  xdg-desktop-portal.service \
  xdg-desktop-portal-hyprland.service \
  xdg-desktop-portal-gtk.service \
  plasma-xdg-desktop-portal-kde.service >/dev/null 2>&1 || true

cat > "$portal_conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Settings=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.AppChooser=gtk
EOF
