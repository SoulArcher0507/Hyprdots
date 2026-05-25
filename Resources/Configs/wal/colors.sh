#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"


WALLPAPER="${1:-}"
TEMP_FRAME=""
HYPR_LUA="$HOME/.config/hypr/colors.lua"
DEPRECATED_HYPR_COLORS="$HOME/.config/hypr/colors.conf"
QS_JSON="$HOME/.config/quickshell/colors.json"
KDE_COLORS="$HOME/.local/share/color-schemes/Dynamic.colors"
KITTY_COLORS="$HOME/.config/kitty/colors.conf"
WAL_CACHE_JSON="$HOME/.cache/wal/colors.json"
MATUGEN_CONFIG="${MATUGEN_CONFIG:-$SCRIPT_DIR/matugen/config.toml}"
MATUGEN_MODE="${MATUGEN_MODE:-dark}"
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
need matugen
need magick
need jq
need python3

cleanup() {
  [[ -n "$TEMP_FRAME" ]] && rm -f -- "$TEMP_FRAME"
}
trap cleanup EXIT

lower_ext() {
  local name="${1##*/}"
  local ext="${name##*.}"
  [[ "$name" == "$ext" ]] && return 1
  printf '%s' "${ext,,}"
}

is_dynamic_wallpaper() {
  local file="$1" ext mime frames
  ext="$(lower_ext "$file" || true)"
  case "$ext" in
    mp4|mkv|mov|webm|avi|m4v|ogv|ogg|flv|wmv|mpg|mpeg|gif|apng)
      return 0
      ;;
  esac

  if [[ "$ext" == "webp" ]] && command -v magick >/dev/null 2>&1; then
    frames="$(magick identify -format '%n\n' "$file" 2>/dev/null | head -n 1 || true)"
    [[ "$frames" =~ ^[0-9]+$ && "$frames" -gt 1 ]] && return 0
  fi

  if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type -- "$file" 2>/dev/null || true)"
    [[ "$mime" == video/* ]] && return 0
  fi

  return 1
}

video_duration() {
  local source="$1"
  command -v ffprobe >/dev/null 2>&1 || return 1
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$source" 2>/dev/null \
    | awk 'NF && $1 > 0 { printf "%.3f\n", $1; exit }'
}

frame_timestamps() {
  local source="$1" duration
  printf '%s\n' "${WALLPAPER_FRAME_TIMESTAMP:-00:00:01}"

  duration="$(video_duration "$source" || true)"
  if [[ -n "$duration" ]]; then
    awk -v d="$duration" 'BEGIN {
      split("0.35 0.50 0.70 0.20 0.85", p, " ");
      for (i in p) printf "%.3f\n", d * p[i];
    }'
  fi

  printf '%s\n' "00:00:00" "00:00:02" "00:00:05"
}

extract_frame_for_matugen() {
  local source="$1" target="$2" ext
  ext="$(lower_ext "$source" || true)"
  if [[ "$ext" =~ ^(gif|apng|webp)$ ]] && command -v magick >/dev/null 2>&1; then
    magick "$source[0]" -auto-orient "$target" 2>/dev/null && return 0
  fi

  need ffmpeg
  ffmpeg -y -v error -ss "${WALLPAPER_FRAME_TIMESTAMP:-00:00:01}" -i "$source" -frames:v 1 "$target" 2>/dev/null \
    || ffmpeg -y -v error -i "$source" -frames:v 1 "$target" 2>/dev/null
}

run_matugen() {
  local image="$1"
  mkdir -p "$(dirname "$WAL_CACHE_JSON")"
  rm -f -- "$WAL_CACHE_JSON"
  matugen image "$image" -m "$MATUGEN_MODE" -b wal -c "$MATUGEN_CONFIG" --dry-run --continue-on-error >/dev/null 2>&1 || true
  python3 "$SCRIPT_DIR/generate_pywal_palette.py" "$image" "$WAL_CACHE_JSON"
}

run_matugen_for_dynamic_wallpaper() {
  local source="$1" ts seen=""
  TEMP_FRAME="$(mktemp --suffix=.jpg)"

  while IFS= read -r ts; do
    [[ -n "$ts" ]] || continue
    case " $seen " in
      *" $ts "*) continue ;;
    esac
    seen="$seen $ts"

    rm -f -- "$TEMP_FRAME"
    if ffmpeg -y -v error -ss "$ts" -i "$source" -frames:v 1 "$TEMP_FRAME" 2>/dev/null \
      || ffmpeg -y -v error -i "$source" -frames:v 1 "$TEMP_FRAME" 2>/dev/null; then
      [[ -s "$TEMP_FRAME" ]] || continue
      run_matugen "$TEMP_FRAME" && return 0
    fi
  done < <(frame_timestamps "$source")

  return 1
}

run_matugen_for_wallpaper() {
  if is_dynamic_wallpaper "$WALLPAPER"; then
    local ext
    ext="$(lower_ext "$WALLPAPER" || true)"
    if [[ "$ext" =~ ^(gif|apng|webp)$ ]]; then
      TEMP_FRAME="$(mktemp --suffix=.jpg)"
      extract_frame_for_matugen "$WALLPAPER" "$TEMP_FRAME"
      run_matugen "$TEMP_FRAME"
    else
      run_matugen_for_dynamic_wallpaper "$WALLPAPER"
    fi
  else
    run_matugen "$WALLPAPER"
  fi
}

for helper in \
  "$SCRIPT_DIR/generate_pywal_palette.py" \
  "$SCRIPT_DIR/render_templates.py" \
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
  [[ -f "$MATUGEN_CONFIG" ]] || {
    echo "Errore: configurazione matugen non trovata: $MATUGEN_CONFIG" >&2
    exit 1
  }
  run_matugen_for_wallpaper
else
  [[ -f "$WAL_CACHE_JSON" ]] || {
    echo "Errore: nessun wallpaper passato e cache colori non trovata: $WAL_CACHE_JSON" >&2
    exit 1
  }
fi

if [[ ! -f "$WAL_CACHE_JSON" ]]; then
  echo "Errore: matugen non ha generato $WAL_CACHE_JSON" >&2
  exit 1
fi

jq -e '
  .special.background and .special.foreground and .special.cursor and
  .colors.color0 and .colors.color1 and .colors.color2 and .colors.color3 and
  .colors.color4 and .colors.color5 and .colors.color6 and .colors.color7 and
  .colors.color8 and .colors.color9 and .colors.color10 and .colors.color11 and
  .colors.color12 and .colors.color13 and .colors.color14 and .colors.color15
' "$WAL_CACHE_JSON" >/dev/null || {
  echo "Errore: cache matugen incompleta o non compatibile: $WAL_CACHE_JSON" >&2
  exit 1
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

python3 "$SCRIPT_DIR/render_templates.py" \
  "$WAL_CACHE_JSON" \
  "$SCRIPT_DIR/templates" \
  "$HYPR_LUA" \
  "$QS_JSON" \
  "$KITTY_COLORS" \
  "$KDE_COLORS"

rm -f -- "$DEPRECATED_HYPR_COLORS"
echo "[OK] Hyprland Lua palette scritta in: $HYPR_LUA"
echo "[OK] Quickshell palette scritta in: $QS_JSON"
echo "[OK] Kitty palette scritta in: $KITTY_COLORS"
echo "[OK] KDE color scheme scritto in: $KDE_COLORS"

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

if [[ -x "$HOME/.config/fastfetch/fastfetch-colors.sh" ]]; then
  "$HOME/.config/fastfetch/fastfetch-colors.sh"
fi

if [[ -x "$HOME/.config/btop/btop-colors.sh" ]]; then
  "$HOME/.config/btop/btop-colors.sh"
fi

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
    sha256sum "$QS_JSON"
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
