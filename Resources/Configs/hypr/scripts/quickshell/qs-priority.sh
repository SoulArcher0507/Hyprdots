#!/usr/bin/env bash
set -u

export QT_NO_XDG_DESKTOP_PORTAL="${QT_NO_XDG_DESKTOP_PORTAL:-1}"

run_qs() {
    exec qs "$@"
}

if command -v systemd-run >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    systemd_scope_props=(
        --property=CPUWeight=10000
        --property=IOWeight=10000
    )

    if systemd-run --user --scope --quiet --collect "${systemd_scope_props[@]}" true >/dev/null 2>&1; then
        exec systemd-run --user --scope --quiet --collect "${systemd_scope_props[@]}" \
            env QT_NO_XDG_DESKTOP_PORTAL="$QT_NO_XDG_DESKTOP_PORTAL" qs "$@"
    fi
fi

run_qs "$@"
