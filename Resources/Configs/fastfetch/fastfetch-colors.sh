#!/usr/bin/env bash
set -euo pipefail

KITTY_COLORS_FILE="${KITTY_COLORS_FILE:-$HOME/.config/kitty/colors.conf}"
FASTFETCH_DIR="${FASTFETCH_DIR:-$HOME/.config/fastfetch}"
FASTFETCH_CONFIG="${FASTFETCH_CONFIG:-$FASTFETCH_DIR/config.jsonc}"

mkdir -p "$FASTFETCH_DIR"

if [[ ! -f "$KITTY_COLORS_FILE" ]]; then
  echo "File not found: $KITTY_COLORS_FILE" >&2
  exit 1
fi

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

get_color() {
  local key="$1"
  local line value
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]+" "$KITTY_COLORS_FILE" | tail -n1 || true)"
  value="${line#$key}"
  value="$(trim "$value")"
  printf '%s' "$value"
}

hex_or_fallback() {
  local v="$1" fallback="$2"
  if [[ "$v" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    printf '%s' "$v"
  else
    printf '%s' "$fallback"
  fi
}

foreground="$(hex_or_fallback "$(get_color foreground)" '#cdd6f4')"
color1="$(hex_or_fallback "$(get_color color1)" '#ff757f')"
color2="$(hex_or_fallback "$(get_color color2)" '#c3e88d')"
color3="$(hex_or_fallback "$(get_color color3)" '#ffc777')"
color4="$(hex_or_fallback "$(get_color color4)" '#82aaff')"
color5="$(hex_or_fallback "$(get_color color5)" '#c099ff')"
color6="$(hex_or_fallback "$(get_color color6)" '#86e1fc')"
color8="$(hex_or_fallback "$(get_color color8)" '#6e6e6e')"
color9="$(hex_or_fallback "$(get_color color9)" "$color1")"
color10="$(hex_or_fallback "$(get_color color10)" "$color2")"
color11="$(hex_or_fallback "$(get_color color11)" "$color3")"
color12="$(hex_or_fallback "$(get_color color12)" "$color4")"
color13="$(hex_or_fallback "$(get_color color13)" "$color5")"
color14="$(hex_or_fallback "$(get_color color14)" "$color6")"

cat > "$FASTFETCH_CONFIG" <<EOF2
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",

  "logo": {
    "type": "small",
    "source": "arch",
    "padding": {
      "top": 7,
      "left": 7,
      "right": 7
    },
    "color": {
      "1": "$color12",
      "2": "$color6"
    }
  },

  "display": {
    "separator": " │ ",
    "color": {
      "keys": "$color13",
      "title": "$color14",
      "separator": "$color8"
    },
    "key": {
      "width": 20,
      "type": "string"
    },
    "bar": {
      "width": 18,
      "char": {
        "elapsed": "■",
        "total": "·"
      },
      "color": {
        "elapsed": "$color13",
        "total": "$color8",
        "border": "$color8"
      },
      "border": {
        "left": "[",
        "right": "]"
      }
    },
    "percent": {
      "type": 9,
      "color": {
        "green": "$color10",
        "yellow": "$color11",
        "red": "$color9"
      }
    }
  },

  "modules": [
    {
      "type": "title",
      "color": {
        "user": "$color14",
        "at": "$color8",
        "host": "$color12"
      }
    },
    {
      "type": "separator",
      "string": "────────────────────────────"
    },
    {
      "type": "os",
      "key": " OS",
      "keyColor": "$color12",
      "outputColor": "$foreground"
    },
    {
      "type": "host",
      "key": "󰌢 Host",
      "keyColor": "$color6",
      "outputColor": "$foreground"
    },
    {
      "type": "kernel",
      "key": " Kernel",
      "keyColor": "$color13",
      "outputColor": "$foreground"
    },
    {
      "type": "uptime",
      "key": "󰅐 Uptime",
      "keyColor": "$color10",
      "outputColor": "$foreground"
    },
    {
      "type": "packages",
      "key": "󰏖 Pkgs",
      "keyColor": "$color11",
      "outputColor": "$foreground"
    },
    {
      "type": "shell",
      "key": " Shell",
      "keyColor": "$color14",
      "outputColor": "$foreground"
    },
    {
      "type": "terminal",
      "key": " Term",
      "keyColor": "$color12",
      "outputColor": "$foreground"
    },
    {
      "type": "terminalfont",
      "key": "󰛖 Term Font",
      "keyColor": "$color6",
      "outputColor": "$foreground"
    },
    {
      "type": "wm",
      "key": " WM",
      "keyColor": "$color13",
      "outputColor": "$foreground"
    },
    {
      "type": "theme",
      "key": "󰉼 Theme",
      "keyColor": "$color10",
      "outputColor": "$foreground"
    },
    {
      "type": "icons",
      "key": "󰀻 Icons",
      "keyColor": "$color11",
      "outputColor": "$foreground"
    },
    {
      "type": "font",
      "key": "󰛖 Font",
      "keyColor": "$color14",
      "outputColor": "$foreground"
    },
    {
      "type": "cursor",
      "key": "󰆿 Cursor",
      "keyColor": "$color12",
      "outputColor": "$foreground"
    },
    {
      "type": "display",
      "key": "󰍹 Display",
      "keyColor": "$color6",
      "outputColor": "$foreground",
      "compactType": "scaled-with-refresh-rate",
      "order": "asc"
    },
    {
      "type": "cpu",
      "key": " CPU",
      "keyColor": "$color13",
      "outputColor": "$foreground"
    },
    {
      "type": "gpu",
      "key": "󰢮 GPU",
      "keyColor": "$color10",
      "outputColor": "$foreground"
    },
    {
      "type": "memory",
      "key": "󰍛 RAM",
      "keyColor": "$color11",
      "outputColor": "$foreground",
      "percent": {
        "type": 3,
        "green": 50,
        "yellow": 80
      }
    },
    {
      "type": "disk",
      "key": "󰋊 Disk",
      "keyColor": "$color14",
      "outputColor": "$foreground",
      "format": "[{mountpoint}]  {size-used} / {size-total} ({size-percentage})",
      "percent": {
        "green": 50,
        "yellow": 80
      }
    },
    "break",
    {
      "type": "colors",
      "paddingLeft": 2,
      "symbol": "circle"
    }
  ]
}
EOF2

printf 'Fastfetch config updated in %s\n' "$FASTFETCH_CONFIG"
