#!/usr/bin/env bash
set -euo pipefail

KITTY_COLORS_FILE="${KITTY_COLORS_FILE:-$HOME/.config/kitty/colors.conf}"
BTOP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/btop"
BTOP_THEME_DIR="$BTOP_DIR/themes"
BTOP_THEME_FILE="$BTOP_THEME_DIR/Dynamic.theme"
BTOP_CONFIG_FILE="$BTOP_DIR/btop.conf"

mkdir -p "$BTOP_THEME_DIR"

if [[ ! -f "$KITTY_COLORS_FILE" ]]; then
  echo "File not found: $KITTY_COLORS_FILE" >&2
  exit 1
fi

get_color() {
  local key="$1"
  awk -v key="$key" '
    $1 == key {
      print $2
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' "$KITTY_COLORS_FILE"
}

background="$(get_color background)"
foreground="$(get_color foreground)"
color0="$(get_color color0)"
color1="$(get_color color1)"
color2="$(get_color color2)"
color3="$(get_color color3)"
color4="$(get_color color4)"
color5="$(get_color color5)"
color6="$(get_color color6)"
color7="$(get_color color7)"
color8="$(get_color color8)"
color9="$(get_color color9)"
color10="$(get_color color10)"
color11="$(get_color color11)"
color12="$(get_color color12)"
color13="$(get_color color13)"
color14="$(get_color color14)"
color15="$(get_color color15)"

cat > "$BTOP_THEME_FILE" <<EOF2
# Dynamic
# Generated from: $KITTY_COLORS_FILE
# Do not edit manually; regenerate instead.

# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="$background"

# Main text color
theme[main_fg]="$foreground"

# Title color for boxes
theme[title]="$color13"

# Highlight color for keyboard shortcuts
theme[hi_fg]="$color14"

# Background color of selected item in processes box
theme[selected_bg]="$color8"

# Foreground color of selected item in processes box
theme[selected_fg]="$color15"

# Color of inactive/disabled text
theme[inactive_fg]="$color8"

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="$color12"

# Background color of the percentage meters
theme[meter_bg]="$color0"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="$color13"

# Cpu box outline color
theme[cpu_box]="$color5"

# Memory/disks box outline color
theme[mem_box]="$color4"

# Net up/down box outline color
theme[net_box]="$color6"

# Processes box outline color
theme[proc_box]="$color13"

# Box divider line and small boxes line color
theme[div_line]="$color8"

# Temperature graph colors
theme[temp_start]="$color10"
theme[temp_mid]="$color11"
theme[temp_end]="$color9"

# CPU graph colors
theme[cpu_start]="$color10"
theme[cpu_mid]="$color11"
theme[cpu_end]="$color9"

# Mem/Disk free meter
theme[free_end]="$color10"
theme[free_mid]="$color11"
theme[free_start]="$color9"

# Mem/Disk cached meter
theme[cached_start]="$color6"
theme[cached_mid]="$color14"
theme[cached_end]="$color12"

# Mem/Disk available meter
theme[available_start]="$color9"
theme[available_mid]="$color11"
theme[available_end]="$color10"

# Mem/Disk used meter
theme[used_start]="$color10"
theme[used_mid]="$color11"
theme[used_end]="$color9"

# Download graph colors
theme[download_start]="$color6"
theme[download_mid]="$color12"
theme[download_end]="$color5"

# Upload graph colors
theme[upload_start]="$color5"
theme[upload_mid]="$color13"
theme[upload_end]="$color9"

# Process box color gradient for threads, mem and cpu usage
theme[process_start]="$color14"
theme[process_mid]="$color12"
theme[process_end]="$color13"

# Process list banner attributes
theme[proc_pause_bg]="$color3"
theme[proc_follow_bg]="$color4"
theme[proc_banner_bg]="$color5"
theme[proc_banner_fg]="$color15"

# Process following attributes
theme[followed_bg]="$color8"
theme[followed_fg]="$color15"
EOF2

if [[ -f "$BTOP_CONFIG_FILE" ]]; then
  if grep -qE '^[[:space:]]*color_theme[[:space:]]*=' "$BTOP_CONFIG_FILE"; then
    sed -i 's|^[[:space:]]*color_theme[[:space:]]*=.*$|color_theme = "Dynamic"|' "$BTOP_CONFIG_FILE"
  else
    printf '\ncolor_theme = "Dynamic"\n' >> "$BTOP_CONFIG_FILE"
  fi
else
  cat > "$BTOP_CONFIG_FILE" <<EOF2
color_theme = "Dynamic"
theme_background = True
EOF2
fi

echo "Created theme: $BTOP_THEME_FILE"
echo "Updated configs: $BTOP_CONFIG_FILE"
