#!/bin/sh
qs ipc call hyprshot open 2>/dev/null && exit 0
exec quickshell -c "$HOME/.config/quickshell/hyprshot" -n
