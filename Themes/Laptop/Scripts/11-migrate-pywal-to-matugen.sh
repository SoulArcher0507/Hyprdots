#!/bin/bash

set -euo pipefail

PATCH_NUMBER="11"
PATCH_DESCRIPTION="Migrate dynamic colors from pywal to matugen"
OLD_PKG="python-pywal"
NEW_PKG="matugen"

echo "Theme patch ${PATCH_NUMBER}: ${PATCH_DESCRIPTION}"

need_sudo() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        return 1
    fi

    return 0
}

run_admin() {
    if need_sudo; then
        sudo "$@"
    else
        "$@"
    fi
}

if need_sudo; then
    echo "This patch needs sudo to remove ${OLD_PKG} and install ${NEW_PKG} with pacman."
    sudo -v
fi

if pacman -Qi "$OLD_PKG" >/dev/null 2>&1; then
    echo "Removing ${OLD_PKG}..."
    run_admin pacman -Rns --noconfirm "$OLD_PKG"
else
    echo "${OLD_PKG} is not installed; skipping removal."
fi

if pacman -Qi "$NEW_PKG" >/dev/null 2>&1; then
    echo "${NEW_PKG} is already installed."
else
    echo "Installing ${NEW_PKG}..."
    run_admin pacman -S --noconfirm --needed "$NEW_PKG"
fi

echo "Theme patch ${PATCH_NUMBER} complete: ${PATCH_DESCRIPTION}."
