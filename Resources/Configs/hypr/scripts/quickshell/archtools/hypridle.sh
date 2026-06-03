#!/usr/bin/env bash

if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle || true
    sleep 0.5
    exit 0
fi

setsid -f "$HOME/.config/hypr/scripts/start-hypridle.sh" </dev/null >/dev/null 2>/dev/null

exit 0
