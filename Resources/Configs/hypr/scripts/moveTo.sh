#!/usr/bin/env bash

set -euo pipefail

target_workspace="${1:-}"

case "$target_workspace" in
    ""|*[!0-9]*)
        printf 'Usage: %s <workspace-number>\n' "$0" >&2
        exit 1
        ;;
esac

hyprctl eval "
local target_workspace = ${target_workspace}
local workspace = hl.get_active_workspace()
if not workspace then
    return
end

for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
    hl.dispatch(hl.dsp.window.move({
        workspace = target_workspace,
        follow = false,
        window = window,
    }))
end

hl.dispatch(hl.dsp.focus({ workspace = target_workspace }))
"
