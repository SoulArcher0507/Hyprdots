#!/bin/bash
set -euo pipefail

PACMAN_CONF="/etc/pacman.conf"
CACHYOS_KEY="F3B607488DB35A47"
CACHYOS_KEYRING_URL="https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst"
CACHYOS_MIRRORLIST_URL="https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst"
CACHYOS_MIRRORLIST="/etc/pacman.d/cachyos-mirrorlist"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

cachyos_repo_enabled() {
  grep -Eq '^[[:space:]]*\[cachyos\][[:space:]]*$' "$PACMAN_CONF"
}

if cachyos_repo_enabled; then
  echo "[cachyos] section already enabled in $PACMAN_CONF"
  exit 0
fi

echo "Installing CachyOS keyring and mirrorlist..."
if pacman-key --list-keys "$CACHYOS_KEY" &>/dev/null; then
  echo "CachyOS key already present"
else
  pacman-key --recv-keys "$CACHYOS_KEY" --keyserver keyserver.ubuntu.com
fi
pacman-key --lsign-key "$CACHYOS_KEY"

cachyos_bootstrap_pkgs=()
if ! pacman -Qi cachyos-keyring &>/dev/null; then
  cachyos_bootstrap_pkgs+=("$CACHYOS_KEYRING_URL")
fi
if ! pacman -Qi cachyos-mirrorlist &>/dev/null; then
  cachyos_bootstrap_pkgs+=("$CACHYOS_MIRRORLIST_URL")
fi

if [ ${#cachyos_bootstrap_pkgs[@]} -gt 0 ]; then
  pacman -U --noconfirm --needed "${cachyos_bootstrap_pkgs[@]}"
else
  echo "CachyOS keyring and mirrorlist already installed"
fi

timestamp=$(date +"%Y%m%d%H%M%S")
backup="${PACMAN_CONF}.bak.${timestamp}"
cp "$PACMAN_CONF" "$backup"
echo "Backup of $PACMAN_CONF created at $backup"

awk -v mirrorlist="$CACHYOS_MIRRORLIST" '
  { print }
  /^[[:space:]]*\[multilib\][[:space:]]*$/ {
    in_multilib=1
    next
  }
  in_multilib && /^[[:space:]]*Include[[:space:]]*=/ {
    print ""
    print "[cachyos]"
    print "Include = " mirrorlist
    in_multilib=0
    inserted=1
    next
  }
  in_multilib && /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
    in_multilib=0
  }
  END {
    if (!inserted) {
      print ""
      print "[cachyos]"
      print "Include = " mirrorlist
    }
  }
' "$PACMAN_CONF" > "${PACMAN_CONF}.tmp" && mv "${PACMAN_CONF}.tmp" "$PACMAN_CONF"

echo "[cachyos] section enabled in $PACMAN_CONF"
