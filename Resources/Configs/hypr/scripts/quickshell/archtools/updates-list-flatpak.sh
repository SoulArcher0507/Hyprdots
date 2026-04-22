#!/usr/bin/env bash
set -euo pipefail

command -v flatpak >/dev/null 2>&1 || exit 0

(
  flatpak --system remote-ls --updates --columns=application 2>/dev/null || true
  flatpak --user   remote-ls --updates --columns=application 2>/dev/null || true
) | sort -u | grep -v "^Application ID$" | grep . || true


