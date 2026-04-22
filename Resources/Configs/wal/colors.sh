#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"


WALLPAPER="${1:-}" 
HYPR_CONF="$HOME/.config/hypr/colors.conf"
QS_JSON="$HOME/.config/quickshell/colors.json"
KDE_COLORS="$HOME/.local/share/color-schemes/Dynamic.colors"
KITTY_COLORS="$HOME/.config/kitty/colors.conf"
WAL_CACHE_JSON="$HOME/.cache/wal/colors.json"
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
PLASMARC="$HOME/.config/plasmarc"
KDEGLOBALS="$HOME/.config/kdeglobals"
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
GTK4_SETTINGS="$HOME/.config/gtk-4.0/settings.ini"
ICON_THEME_NAME="Dynamic"
ICON_THEME_DIR="$HOME/.local/share/icons/$ICON_THEME_NAME"
ICON_THEME_BASE_DIR="$(dirname "$ICON_THEME_DIR")"
ICON_THEME_CACHE_DIR="$HOME/.cache/dynamic-icons"
HARD_RELOAD_PLASMA="${DYNAMIC_KDE_HARD_RELOAD:-1}"
KORA_SOURCE_OVERRIDE="${KORA_SOURCE_OVERRIDE:-}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Errore: manca '$1'" >&2
    exit 1
  }
}
need wal
need jq
need python3

for helper in \
  "$SCRIPT_DIR/color_mix.py" \
  "$SCRIPT_DIR/color_contrast.py" \
  "$SCRIPT_DIR/set_generic_ini_key.py" \
  "$SCRIPT_DIR/update_index_theme.py" \
  "$SCRIPT_DIR/recolor_icon_theme.py"; do
  [[ -f "$helper" ]] || {
    echo "Errore: helper non trovato: $helper" >&2
    exit 1
  }
done

if [[ -n "$WALLPAPER" ]]; then
  if [[ ! -f "$WALLPAPER" ]]; then
    echo "Errore: wallpaper non trovato: $WALLPAPER" >&2
    exit 1
  fi
  wal -i "$WALLPAPER"
else
  wal -R
fi

if [[ ! -f "$WAL_CACHE_JSON" ]]; then
  echo "Errore: wal non ha generato $WAL_CACHE_JSON" >&2
  exit 1
fi

hex_norm() {
  local hex="${1#\#}"
  printf '#%s' "${hex^^}"
}

hex_to_rgb_triplet() {
  local HEX="${1#\#}"
  local R="${HEX:0:2}" G="${HEX:2:2}" B="${HEX:4:2}"
  printf "%d,%d,%d" "0x$R" "0x$G" "0x$B"
}

atomic_write() {
  local dst="$1"
  mkdir -p "$(dirname "$dst")"
  local tmp
  tmp="$(mktemp "${dst}.XXXXXX")"
  cat >"$tmp"
  mv -f "$tmp" "$dst"
}

mix_hex() {
  python3 "$SCRIPT_DIR/color_mix.py" "$1" "$2" "$3"
}

lighten_hex() { mix_hex "$1" '#FFFFFF' "$2"; }
darken_hex()  { mix_hex "$1" '#000000' "$2"; }

contrast_hex() {
  python3 "$SCRIPT_DIR/color_contrast.py" "$1"
}

set_ini_key() {
  local file="$1" group="$2" key="$3" value="$4"
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "$file" --group "$group" --key "$key" "$value" >/dev/null 2>&1 || true
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file "$file" --group "$group" --key "$key" "$value" >/dev/null 2>&1 || true
  fi
}

set_generic_ini_key() {
  local file="$1" group="$2" key="$3" value="$4"
  mkdir -p "$(dirname "$file")"
  python3 "$SCRIPT_DIR/set_generic_ini_key.py" "$file" "$group" "$key" "$value"
}

cleanup_legacy_icon_theme_dirs() {
  local dirs=(
    "$ICON_THEME_BASE_DIR/${ICON_THEME_NAME}.stage."*
    "$ICON_THEME_BASE_DIR/${ICON_THEME_NAME}.bak."*
    "$ICON_THEME_BASE_DIR/.${ICON_THEME_NAME}.stage."*
    "$ICON_THEME_BASE_DIR/.${ICON_THEME_NAME}.bak."*
    "$HOME/.icons/$ICON_THEME_NAME"
  )
  local d
  shopt -s nullglob
  for d in "${dirs[@]}"; do
    [[ -e "$d" ]] || continue
    [[ "$d" = "$ICON_THEME_DIR" ]] && continue
    rm -rf "$d" 2>/dev/null || true
  done
  shopt -u nullglob
}

get_ini_key() {
  local file="$1" group="$2" key="$3"
  if command -v kreadconfig6 >/dev/null 2>&1; then
    kreadconfig6 --file "$file" --group "$group" --key "$key" 2>/dev/null || true
  elif command -v kreadconfig5 >/dev/null 2>&1; then
    kreadconfig5 --file "$file" --group "$group" --key "$key" 2>/dev/null || true
  fi
}

find_kora_source() {
  if [[ -n "$KORA_SOURCE_OVERRIDE" && -d "$KORA_SOURCE_OVERRIDE" ]]; then
    printf '%s\n' "$KORA_SOURCE_OVERRIDE"
    return 0
  fi

  local candidates=(
    "$HOME/.local/share/icons/Kora"
    "$HOME/.local/share/icons/kora"
    "$HOME/.icons/Kora"
    "$HOME/.icons/kora"
    "/usr/share/icons/Kora"
    "/usr/share/icons/kora"
  )
  local p
  for p in "${candidates[@]}"; do
    [[ -d "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

find_plasma_changeicons() {
  local candidates=(
    "$(command -v plasma-changeicons 2>/dev/null || true)"
    "/usr/lib/plasma-changeicons"
    "/usr/lib64/plasma-changeicons"
    "/usr/libexec/plasma-changeicons"
  )
  local p
  for p in "${candidates[@]}"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

update_gtk_setting_file() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  if [[ ! -f "$file" ]]; then
    printf '[Settings]\n%s=%s\n' "$key" "$value" > "$file"
    return 0
  fi
  if grep -q '^\[Settings\]' "$file"; then
    if grep -q "^${key}=" "$file"; then
      sed -i "s|^${key}=.*|${key}=${value}|" "$file" || true
    else
      awk -v kv="${key}=${value}" '
        BEGIN{done=0}
        /^\[Settings\]$/ {print; if (!done) {print kv; done=1; next}}
        {print}
        END{if (!done) {print "[Settings]"; print kv}}
      ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
  else
    printf '\n[Settings]\n%s=%s\n' "$key" "$value" >> "$file"
  fi
}

notify_kglobalsettings() {
  if command -v dbus-send >/dev/null 2>&1; then
    dbus-send --session --type=signal /KGlobalSettings \
      org.kde.KGlobalSettings.notifyChange \
      int32:0 int32:0 >/dev/null 2>&1 || true
  fi
}

reconfigure_kwin() {
  if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  elif command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  elif command -v gdbus >/dev/null 2>&1; then
    gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
  fi
}

reapply_plasma_theme() {
  local current_theme=""
  current_theme="$(get_ini_key "$PLASMARC" Theme name || true)"
  [[ -n "$current_theme" ]] || current_theme="breeze"

  if command -v plasma-apply-desktoptheme >/dev/null 2>&1; then
    plasma-apply-desktoptheme "$current_theme" >/dev/null 2>&1 || true
  else
    set_ini_key plasmarc Theme name "$current_theme"
  fi
}

refresh_icon_caches() {
  local target_dir="${1:-$ICON_THEME_DIR}"

  rm -f "$HOME/.cache/icon-cache.kcache" 2>/dev/null || true

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$target_dir" >/dev/null 2>&1 || true
  fi
}

refresh_system_icon_indices() {
  if command -v xdg-icon-resource >/dev/null 2>&1; then
    xdg-icon-resource forceupdate >/dev/null 2>&1 || true
  fi
  if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
  elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 >/dev/null 2>&1 || true
  fi
}

apply_icon_theme() {
  local plasma_changeicons_bin=""
  plasma_changeicons_bin="$(find_plasma_changeicons || true)"

  set_generic_ini_key "$KDEGLOBALS" "Icons" "Theme" "$ICON_THEME_NAME"
  set_ini_key kdeglobals Icons Theme "$ICON_THEME_NAME"
  set_generic_ini_key "$QT6CT_CONF" "Appearance" "icon_theme" "$ICON_THEME_NAME"

  update_gtk_setting_file "$GTK3_SETTINGS" gtk-icon-theme-name "$ICON_THEME_NAME"
  update_gtk_setting_file "$GTK4_SETTINGS" gtk-icon-theme-name "$ICON_THEME_NAME"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_NAME" >/dev/null 2>&1 || true
  fi

  if [[ -n "$plasma_changeicons_bin" ]]; then
    "$plasma_changeicons_bin" "$ICON_THEME_NAME" >/dev/null 2>&1 || true
  fi
}

hard_reload_plasmashell() {
  [[ "$HARD_RELOAD_PLASMA" = "1" ]] || return 0

  if command -v kquitapp6 >/dev/null 2>&1 && command -v kstart6 >/dev/null 2>&1; then
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 1
    kstart6 plasmashell >/dev/null 2>&1 &
  elif command -v kquitapp5 >/dev/null 2>&1 && command -v kstart5 >/dev/null 2>&1; then
    kquitapp5 plasmashell >/dev/null 2>&1 || true
    sleep 1
    kstart5 plasmashell >/dev/null 2>&1 &
  elif command -v plasmashell >/dev/null 2>&1; then
    pkill -x plasmashell >/dev/null 2>&1 || true
    sleep 1
    nohup plasmashell >/dev/null 2>&1 &
  fi
}


reload_kitty_config() {
  if pgrep -x kitty >/dev/null 2>&1; then
    pkill -USR1 -x kitty >/dev/null 2>&1 || true
  fi
}

bg="$(hex_norm "$(jq -r '.special.background' "$WAL_CACHE_JSON")")"
fg="$(hex_norm "$(jq -r '.special.foreground' "$WAL_CACHE_JSON")")"
cursor="$(hex_norm "$(jq -r '.special.cursor' "$WAL_CACHE_JSON")")"

c0="$(hex_norm "$(jq -r '.colors.color0'  "$WAL_CACHE_JSON")")"
c1="$(hex_norm "$(jq -r '.colors.color1'  "$WAL_CACHE_JSON")")"
c2="$(hex_norm "$(jq -r '.colors.color2'  "$WAL_CACHE_JSON")")"
c3="$(hex_norm "$(jq -r '.colors.color3'  "$WAL_CACHE_JSON")")"
c4="$(hex_norm "$(jq -r '.colors.color4'  "$WAL_CACHE_JSON")")"
c5="$(hex_norm "$(jq -r '.colors.color5'  "$WAL_CACHE_JSON")")"
c6="$(hex_norm "$(jq -r '.colors.color6'  "$WAL_CACHE_JSON")")"
c7="$(hex_norm "$(jq -r '.colors.color7'  "$WAL_CACHE_JSON")")"
c8="$(hex_norm "$(jq -r '.colors.color8'  "$WAL_CACHE_JSON")")"
c9="$(hex_norm "$(jq -r '.colors.color9'  "$WAL_CACHE_JSON")")"
c10="$(hex_norm "$(jq -r '.colors.color10' "$WAL_CACHE_JSON")")"
c11="$(hex_norm "$(jq -r '.colors.color11' "$WAL_CACHE_JSON")")"
c12="$(hex_norm "$(jq -r '.colors.color12' "$WAL_CACHE_JSON")")"
c13="$(hex_norm "$(jq -r '.colors.color13' "$WAL_CACHE_JSON")")"
c14="$(hex_norm "$(jq -r '.colors.color14' "$WAL_CACHE_JSON")")"
c15="$(hex_norm "$(jq -r '.colors.color15' "$WAL_CACHE_JSON")")"

accent="$c4"
accent2="$c6"
success="$c2"
warning="$c3"
danger="$c1"
muted="$c8"

window_bg="$(mix_hex "$bg" "$fg" 0.06)"
view_bg="$bg"
alt_bg="$(mix_hex "$bg" "$c0" 0.55)"
panel_bg="$(mix_hex "$bg" "$accent" 0.10)"
header_bg="$(mix_hex "$bg" "$accent" 0.14)"
button_bg="$(mix_hex "$bg" "$accent" 0.16)"
button_alt_bg="$(mix_hex "$bg" "$accent2" 0.18)"
tooltip_bg="$(mix_hex "$bg" "$fg" 0.12)"
comp_bg="$(mix_hex "$bg" "$accent2" 0.12)"
active_title_bg="$(mix_hex "$bg" "$accent" 0.22)"
inactive_title_bg="$(mix_hex "$bg" "$fg" 0.09)"
selection_bg="$accent"
selection_alt_bg="$accent2"
selection_fg="$(contrast_hex "$selection_bg")"
button_fg="$(contrast_hex "$button_bg")"
header_fg="$(contrast_hex "$header_bg")"
active_title_fg="$(contrast_hex "$active_title_bg")"

rgb_bg="$(hex_to_rgb_triplet "$bg")"
rgb_fg="$(hex_to_rgb_triplet "$fg")"
rgb_cursor="$(hex_to_rgb_triplet "$cursor")"

rgb0="$(hex_to_rgb_triplet "$c0")"
rgb1="$(hex_to_rgb_triplet "$c1")"
rgb2="$(hex_to_rgb_triplet "$c2")"
rgb3="$(hex_to_rgb_triplet "$c3")"
rgb4="$(hex_to_rgb_triplet "$c4")"
rgb5="$(hex_to_rgb_triplet "$c5")"
rgb6="$(hex_to_rgb_triplet "$c6")"
rgb7="$(hex_to_rgb_triplet "$c7")"
rgb8="$(hex_to_rgb_triplet "$c8")"
rgb9="$(hex_to_rgb_triplet "$c9")"
rgb10="$(hex_to_rgb_triplet "$c10")"
rgb11="$(hex_to_rgb_triplet "$c11")"
rgb12="$(hex_to_rgb_triplet "$c12")"
rgb13="$(hex_to_rgb_triplet "$c13")"
rgb14="$(hex_to_rgb_triplet "$c14")"
rgb15="$(hex_to_rgb_triplet "$c15")"

rgb_window_bg="$(hex_to_rgb_triplet "$window_bg")"
rgb_view_bg="$(hex_to_rgb_triplet "$view_bg")"
rgb_alt_bg="$(hex_to_rgb_triplet "$alt_bg")"
rgb_panel_bg="$(hex_to_rgb_triplet "$panel_bg")"
rgb_header_bg="$(hex_to_rgb_triplet "$header_bg")"
rgb_button_bg="$(hex_to_rgb_triplet "$button_bg")"
rgb_button_alt_bg="$(hex_to_rgb_triplet "$button_alt_bg")"
rgb_tooltip_bg="$(hex_to_rgb_triplet "$tooltip_bg")"
rgb_comp_bg="$(hex_to_rgb_triplet "$comp_bg")"
rgb_active_title_bg="$(hex_to_rgb_triplet "$active_title_bg")"
rgb_inactive_title_bg="$(hex_to_rgb_triplet "$inactive_title_bg")"
rgb_selection_bg="$(hex_to_rgb_triplet "$selection_bg")"
rgb_selection_alt_bg="$(hex_to_rgb_triplet "$selection_alt_bg")"
rgb_selection_fg="$(hex_to_rgb_triplet "$selection_fg")"
rgb_button_fg="$(hex_to_rgb_triplet "$button_fg")"
rgb_header_fg="$(hex_to_rgb_triplet "$header_fg")"
rgb_active_title_fg="$(hex_to_rgb_triplet "$active_title_fg")"

atomic_write "$HYPR_CONF" <<EOF_HYPR
# Generated by colors.sh
\$bg = rgb(${rgb_bg})
\$fg = rgb(${rgb_fg})
\$cursor = rgb(${rgb_cursor})

\$color0  = rgb(${rgb0})
\$color1  = rgb(${rgb1})
\$color2  = rgb(${rgb2})
\$color3  = rgb(${rgb3})
\$color4  = rgb(${rgb4})
\$color5  = rgb(${rgb5})
\$color6  = rgb(${rgb6})
\$color7  = rgb(${rgb7})
\$color8  = rgb(${rgb8})
\$color9  = rgb(${rgb9})
\$color10 = rgb(${rgb10})
\$color11 = rgb(${rgb11})
\$color12 = rgb(${rgb12})
\$color13 = rgb(${rgb13})
\$color14 = rgb(${rgb14})
\$color15 = rgb(${rgb15})

\$accent  = rgb(${rgb4})
\$accent2 = rgb(${rgb6})
\$success = rgb(${rgb2})
\$warning = rgb(${rgb3})
\$danger  = rgb(${rgb1})
\$muted   = rgb(${rgb8})
EOF_HYPR

echo "[OK] Hyprland palette scritta in: $HYPR_CONF"

mkdir -p "$(dirname "$QS_JSON")"
jq -n --argjson src "$(cat "$WAL_CACHE_JSON")" \
  '{
  special: {
    background: $src.special.background,
    foreground: $src.special.foreground,
    cursor:     $src.special.cursor
  },
  colors: {
    color0:  $src.colors.color0,  color1:  $src.colors.color1,
    color2:  $src.colors.color2,  color3:  $src.colors.color3,
    color4:  $src.colors.color4,  color5:  $src.colors.color5,
    color6:  $src.colors.color6,  color7:  $src.colors.color7,
    color8:  $src.colors.color8,  color9:  $src.colors.color9,
    color10: $src.colors.color10, color11: $src.colors.color11,
    color12: $src.colors.color12, color13: $src.colors.color13,
    color14: $src.colors.color14, color15: $src.colors.color15
  },
  quickshell: {
    bg:       $src.special.background,
    fg:       $src.special.foreground,
    accent:   $src.colors.color4,
    accent2:  $src.colors.color6,
    success:  $src.colors.color2,
    warning:  $src.colors.color3,
    danger:   $src.colors.color1,
    muted:    $src.colors.color8
  }
}' > "$QS_JSON"

echo "[OK] Quickshell palette scritta in: $QS_JSON"

atomic_write "$KITTY_COLORS" <<EOF_KITTY
# Generated by colors.sh
foreground ${fg}
background ${bg}
selection_foreground ${selection_fg}
selection_background ${accent}
cursor ${accent}
cursor_text_color ${selection_fg}
url_color ${accent2}

active_tab_foreground ${header_fg}
active_tab_background ${header_bg}
inactive_tab_foreground ${fg}
inactive_tab_background ${panel_bg}
tab_bar_background ${window_bg}

active_border_color ${accent}
inactive_border_color ${muted}
bell_border_color ${warning}
visual_bell_color ${danger}

mark1_foreground ${selection_fg}
mark1_background ${accent}
mark2_foreground ${selection_fg}
mark2_background ${accent2}

wayland_titlebar_color background

color0 ${c0}
color1 ${c1}
color2 ${c2}
color3 ${c3}
color4 ${c4}
color5 ${c5}
color6 ${c6}
color7 ${c7}
color8 ${c8}
color9 ${c9}
color10 ${c10}
color11 ${c11}
color12 ${c12}
color13 ${c13}
color14 ${c14}
color15 ${c15}
EOF_KITTY

echo "[OK] Kitty palette scritta in: $KITTY_COLORS"

notify_zsh_prompt_refresh() {
  local pid="$PPID"
  local comm=""

  while [[ -n "$pid" && "$pid" -gt 1 ]]; do
    comm="$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]')"

    if [[ "$comm" == "zsh" ]]; then
      (
        sleep 0.05
        kill -USR1 "$pid" 2>/dev/null || true
      ) >/dev/null 2>&1 &

      disown 2>/dev/null || true
      return 0
    fi

    pid="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]')"
  done

  while read -r zpid tty comm; do
    [[ "$comm" == "zsh" ]] || continue
    [[ "$tty" == "?" ]] && continue

    (
      sleep 0.05
      kill -USR1 "$zpid" 2>/dev/null || true
    ) >/dev/null 2>&1 &
  done < <(ps -u "$USER" -o pid=,tty=,comm=)
}

notify_zsh_prompt_refresh

$HOME/.config/fastfetch/fastfetch-colors.sh

$HOME/.config/btop/btop-colors.sh

atomic_write "$KDE_COLORS" <<EOF_KDE
[ColorEffects:Disabled]
Color=${rgb8}
ColorAmount=0.55
ColorEffect=3
ContrastAmount=0.65
ContrastEffect=1
Enable=true
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=${rgb8}
ColorAmount=0.08
ColorEffect=2
ContrastAmount=0.08
ContrastEffect=2
Enable=true
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=${rgb_button_alt_bg}
BackgroundNormal=${rgb_button_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_button_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:Header]
BackgroundAlternate=${rgb_panel_bg}
BackgroundNormal=${rgb_header_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_header_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:Header][Inactive]
BackgroundAlternate=${rgb_alt_bg}
BackgroundNormal=${rgb_inactive_title_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb8}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:Selection]
BackgroundAlternate=${rgb_selection_alt_bg}
BackgroundNormal=${rgb_selection_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb_selection_fg}
ForegroundInactive=${rgb_selection_fg}
ForegroundLink=${rgb_selection_fg}
ForegroundNegative=${rgb_selection_fg}
ForegroundNeutral=${rgb_selection_fg}
ForegroundNormal=${rgb_selection_fg}
ForegroundPositive=${rgb_selection_fg}
ForegroundVisited=${rgb_selection_fg}

[Colors:Tooltip]
BackgroundAlternate=${rgb_alt_bg}
BackgroundNormal=${rgb_tooltip_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:View]
BackgroundAlternate=${rgb_alt_bg}
BackgroundNormal=${rgb_view_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:Window]
BackgroundAlternate=${rgb_alt_bg}
BackgroundNormal=${rgb_window_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[Colors:Complementary]
BackgroundAlternate=${rgb_alt_bg}
BackgroundNormal=${rgb_comp_bg}
DecorationFocus=${rgb4}
DecorationHover=${rgb6}
ForegroundActive=${rgb4}
ForegroundInactive=${rgb8}
ForegroundLink=${rgb6}
ForegroundNegative=${rgb1}
ForegroundNeutral=${rgb3}
ForegroundNormal=${rgb_fg}
ForegroundPositive=${rgb2}
ForegroundVisited=${rgb5}

[General]
ColorScheme=Dynamic
Name=Dynamic
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=${rgb_active_title_bg}
activeBlend=${rgb4}
activeForeground=${rgb_active_title_fg}
inactiveBackground=${rgb_inactive_title_bg}
inactiveBlend=${rgb8}
inactiveForeground=${rgb8}
EOF_KDE

echo "[OK] KDE color scheme scritto in: $KDE_COLORS"

set_generic_ini_key "$KDEGLOBALS" "General" "ColorScheme" "Dynamic"
set_generic_ini_key "$KDEGLOBALS" "KDE" "colorScheme" "Dynamic"

if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
  plasma-apply-colorscheme Dynamic >/dev/null 2>&1 || true
else
  set_ini_key kdeglobals General ColorScheme Dynamic
  set_ini_key kdeglobals KDE colorScheme Dynamic
fi

set_generic_ini_key "$QT6CT_CONF" "Appearance" "color_scheme_path" "$KDE_COLORS"
echo "[OK] qt6ct aggiornato: $QT6CT_CONF"

KORA_SOURCE="$(find_kora_source || true)"
if [[ -n "$KORA_SOURCE" ]]; then
  echo "[INFO] Sorgente Kora trovata in: $KORA_SOURCE"

  mkdir -p "$ICON_THEME_BASE_DIR" "$ICON_THEME_CACHE_DIR"
  cleanup_legacy_icon_theme_dirs

  palette_hash="$({
    printf '%s\n' "$ICON_THEME_NAME"
    printf '%s\n' "$bg" "$fg" "$cursor"
    printf '%s\n' "$c0" "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7"
    printf '%s\n' "$c8" "$c9" "$c10" "$c11" "$c12" "$c13" "$c14" "$c15"
    printf '%s\n' "$KORA_SOURCE"
  } | sha256sum | awk '{print $1}')"

  palette_cache_dir="$ICON_THEME_CACHE_DIR/$palette_hash"
  staged_theme_dir="$(mktemp -d "$ICON_THEME_CACHE_DIR/.${ICON_THEME_NAME}.stage.XXXXXX")"
  backup_theme_dir="$(mktemp -d "$ICON_THEME_CACHE_DIR/.${ICON_THEME_NAME}.bak.XXXXXX")"

  cleanup_icon_stage() {
    rm -rf "$staged_theme_dir" "$backup_theme_dir" 2>/dev/null || true
  }
  trap cleanup_icon_stage EXIT

  if [[ -d "$palette_cache_dir" ]]; then
    echo "[INFO] Cache tema icone trovata: riuso snapshot già generata"
    rm -rf "$staged_theme_dir"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$palette_cache_dir/" "$staged_theme_dir/"
    else
      mkdir -p "$staged_theme_dir"
      cp -a "$palette_cache_dir/." "$staged_theme_dir/"
    fi
  else
    rm -rf "$staged_theme_dir"
    mkdir -p "$staged_theme_dir"

    if command -v rsync >/dev/null 2>&1; then
      rsync -aL --delete --exclude 'icon-theme.cache' "$KORA_SOURCE/" "$staged_theme_dir/"
    else
      cp -aL "$KORA_SOURCE/." "$staged_theme_dir/"
      rm -f "$staged_theme_dir/icon-theme.cache"
    fi

    if [[ -f "$staged_theme_dir/index.theme" ]]; then
      python3 "$SCRIPT_DIR/update_index_theme.py" "$staged_theme_dir/index.theme" "$ICON_THEME_NAME"
    fi

    export DYNAMIC_PALETTE_SOURCE="$QS_JSON"
    export DYNAMIC_THEME_DIR="$staged_theme_dir"
    export DYNAMIC_THEME_NAME="$ICON_THEME_NAME"

    python3 "$SCRIPT_DIR/recolor_icon_theme.py"

    refresh_icon_caches "$staged_theme_dir"

    rm -rf "$palette_cache_dir"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$staged_theme_dir/" "$palette_cache_dir/"
    else
      mkdir -p "$palette_cache_dir"
      cp -a "$staged_theme_dir/." "$palette_cache_dir/"
    fi
  fi

  rm -rf "$backup_theme_dir"
  if [[ -d "$ICON_THEME_DIR" ]]; then
    mv "$ICON_THEME_DIR" "$backup_theme_dir"
  fi
  mv "$staged_theme_dir" "$ICON_THEME_DIR"
  rm -rf "$backup_theme_dir"
  cleanup_legacy_icon_theme_dirs

  refresh_icon_caches "$ICON_THEME_DIR"
  apply_icon_theme
  refresh_system_icon_indices
  echo "[OK] Tema icone dinamico creato e applicato: $ICON_THEME_NAME"
else
  echo "[WARN] Tema Kora non trovato in ~/.local/share/icons, ~/.icons o /usr/share/icons. Salto la parte icone."
fi

reapply_plasma_theme
notify_kglobalsettings
reconfigure_kwin
hard_reload_plasmashell
notify_kglobalsettings

if [[ -x "$HOME/.config/hypr/scripts/reload.sh" ]]; then
  "$HOME/.config/hypr/scripts/reload.sh"
fi

reload_kitty_config

echo "[colors.sh] Aggiornamento completato."
