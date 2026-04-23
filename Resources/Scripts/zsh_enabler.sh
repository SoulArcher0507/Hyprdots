#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER}}"

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    echo "Errore: impossibile determinare l'utente target."
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
ZSHENV_FILE="$TARGET_HOME/.zshenv"
BOOTSTRAP='export ZDOTDIR="$HOME/.config/zsh"
if [[ -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi'

touch "$ZSHENV_FILE"

if ! grep -Fq 'source "$ZDOTDIR/.zshenv"' "$ZSHENV_FILE"; then
  TMP_FILE="$(mktemp)"
  {
    printf '%s\n\n' "$BOOTSTRAP"
    cat "$ZSHENV_FILE"
  } > "$TMP_FILE"
  mv "$TMP_FILE" "$ZSHENV_FILE"
fi

chown "$TARGET_USER:$TARGET_USER" "$ZSHENV_FILE"
