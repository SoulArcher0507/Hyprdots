#!/usr/bin/env bash

LOCK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/lock"

if pgrep -x quickshell | xargs -I{} grep -l "lock" /proc/{}/cmdline 2>/dev/null | grep -q .; then
    exit 0
fi

exec quickshell -p "$LOCK_DIR"
