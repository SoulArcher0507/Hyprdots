typeset -g KTY_FOREGROUND="#cdd6f4"
typeset -g KTY_BACKGROUND="#1e1e2e"
typeset -g KTY_COLOR0="#45475a"
typeset -g KTY_COLOR1="#f38ba8"
typeset -g KTY_COLOR2="#a6e3a1"
typeset -g KTY_COLOR3="#f9e2af"
typeset -g KTY_COLOR4="#89b4fa"
typeset -g KTY_COLOR5="#f5c2e7"
typeset -g KTY_COLOR6="#94e2d5"
typeset -g KTY_COLOR7="#bac2de"
typeset -g KTY_COLOR8="#585b70"
typeset -g KTY_COLOR9="#f38ba8"
typeset -g KTY_COLOR10="#a6e3a1"
typeset -g KTY_COLOR11="#f9e2af"
typeset -g KTY_COLOR12="#89b4fa"
typeset -g KTY_COLOR13="#f5c2e7"
typeset -g KTY_COLOR14="#94e2d5"
typeset -g KTY_COLOR15="#a6adc8"

load_kitty_colors() {
  local file="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/colors.conf"
  [[ -r "$file" ]] || return 0

  local key value rest
  while read -r key value rest; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
      foreground) KTY_FOREGROUND="$value" ;;
      background) KTY_BACKGROUND="$value" ;;
      color0) KTY_COLOR0="$value" ;;
      color1) KTY_COLOR1="$value" ;;
      color2) KTY_COLOR2="$value" ;;
      color3) KTY_COLOR3="$value" ;;
      color4) KTY_COLOR4="$value" ;;
      color5) KTY_COLOR5="$value" ;;
      color6) KTY_COLOR6="$value" ;;
      color7) KTY_COLOR7="$value" ;;
      color8) KTY_COLOR8="$value" ;;
      color9) KTY_COLOR9="$value" ;;
      color10) KTY_COLOR10="$value" ;;
      color11) KTY_COLOR11="$value" ;;
      color12) KTY_COLOR12="$value" ;;
      color13) KTY_COLOR13="$value" ;;
      color14) KTY_COLOR14="$value" ;;
      color15) KTY_COLOR15="$value" ;;
    esac
  done < "$file"
}
