#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER}}"

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    echo "Errore: impossibile determinare l'utente target."
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
ZSHENV_FILE="$TARGET_HOME/.zshenv"
LINE='export ZDOTDIR="$HOME/.config/zsh"'

touch "$ZSHENV_FILE"

grep -Fxq "$LINE" "$ZSHENV_FILE" || echo "$LINE" >> "$ZSHENV_FILE"

chown "$TARGET_USER:$TARGET_USER" "$ZSHENV_FILE"
