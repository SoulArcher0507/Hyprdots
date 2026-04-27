#!/usr/bin/env bash
set -euo pipefail

mode="${1:-read}"
calendar_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/quickshell/calendar"
env_file="${calendar_dir}/.env"
legacy_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/calendar"
legacy_env_file="${legacy_dir}/.env"

json_escape() {
  local s="${1:-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

read_value() {
  local key="$1"
  local file=""

  if [[ -f "$env_file" ]]; then
    file="$env_file"
  elif [[ -f "$legacy_env_file" ]]; then
    file="$legacy_env_file"
  fi

  [[ -n "$file" ]] || return 0
  awk -F= -v k="$key" '$1 == k { sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); gsub(/^"|"$/, "", $2); gsub(/^'\''|'\''$/, "", $2); print $2; exit }' "$file"
}

write_env() {
  local api_key="${1:-}"
  local city_id="${2:-}"
  local unit="${3:-metric}"

  mkdir -p "$calendar_dir"
  {
    printf 'OPENWEATHER_KEY=%s\n' "$api_key"
    printf 'OPENWEATHER_CITY_ID=%s\n' "$city_id"
    printf 'OPENWEATHER_UNIT=%s\n' "$unit"
  } > "$env_file"

  mkdir -p "$legacy_dir"
  cp "$env_file" "$legacy_env_file"
}

case "$mode" in
  read)
    key="$(read_value OPENWEATHER_KEY)"
    city_id="$(read_value OPENWEATHER_CITY_ID)"
    unit="$(read_value OPENWEATHER_UNIT)"
    printf '{"key":"%s","city_id":"%s","unit":"%s","path":"%s","script_path":"%s"}\n' \
      "$(json_escape "$key")" \
      "$(json_escape "$city_id")" \
      "$(json_escape "${unit:-metric}")" \
      "$(json_escape "$legacy_env_file")" \
      "$(json_escape "$env_file")"
    ;;
  write)
    write_env "${2:-}" "${3:-}" "${4:-metric}"
    ;;
  *)
    printf 'Usage: %s read|write [api_key city_id unit]\n' "$0" >&2
    exit 2
    ;;
esac
