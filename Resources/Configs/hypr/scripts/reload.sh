#!/usr/bin/env bash
hyprctl reload
if command -v awww >/dev/null 2>&1; then
  if ! awww query >/dev/null 2>&1; then
    awww init || true
    sleep 0.05
  fi
fi

