#!/usr/bin/env bash

set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
profile_script="$config_dir/scripts/device-profile.sh"

if [[ -x "$profile_script" ]]; then
    selected_profile="$("$profile_script")"
else
    selected_profile="desktop"
fi
case "$selected_profile" in
    laptop)
        exec hypridle -c "$config_dir/hypridle-laptop.conf"
        ;;
    *)
        exec hypridle -c "$config_dir/hypridle.conf"
        ;;
esac
