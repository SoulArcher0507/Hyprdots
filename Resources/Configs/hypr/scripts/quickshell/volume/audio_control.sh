#!/usr/bin/env bash

ACTION=$1
TYPE=$2
ID=$3
VAL=$4

show_overlay() {
    mkdir -p "$HOME/.cache/quickshell"
    touch "$HOME/.cache/quickshell/volume-overlay.trigger"
    qs ipc --any-display -p "$HOME/.config/quickshell" call volumeoverlay show >/dev/null 2>&1 || true
}

case $ACTION in
    set-volume)
        pactl set-$TYPE-volume "$ID" "$VAL%"
        show_overlay
        ;;
    toggle-mute)
        pactl set-$TYPE-mute "$ID" toggle
        show_overlay
        ;;
    set-default)
        pactl set-default-$TYPE "$ID"
        ;;
esac
