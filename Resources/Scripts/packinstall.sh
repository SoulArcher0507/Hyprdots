#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exec sudo "$0" "$@"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASE_PKGS="$REPO_ROOT/Resources/Pkgs"

# pacman.conf setup 
PACMAN_CONF="/etc/pacman.conf"
CACHYOS_KEY="F3B607488DB35A47"
CACHYOS_KEYRING_URL="https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst"
CACHYOS_MIRRORLIST_URL="https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst"
CACHYOS_MIRRORLIST="/etc/pacman.d/cachyos-mirrorlist"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP="${PACMAN_CONF}.bak.${TIMESTAMP}"

cp "$PACMAN_CONF" "$BACKUP"
echo "Backup of $PACMAN_CONF created at $BACKUP"

awk '
  /^[[:space:]]*\\1\[multilib\][[:space:]]*$/ && !/testing/ {
    sub(/^[[:space:]]*\\1/, "")
    found=1
    print
    next
  }
  /^[[:space:]]*#[[:space:]]*\[multilib\][[:space:]]*$/ && !/testing/ {
    sub(/^[[:space:]]*#[[:space:]]*/, "")
    found=1
    print
    next
  }
  /^[[:space:]]*\[multilib\][[:space:]]*$/ && !/testing/ {
    found=1
    print
    next
  }
  found && /^[[:space:]]*\\1Include[[:space:]]*=/ {
    sub(/^[[:space:]]*\\1/, "")
    found=0
    print
    next
  }
  found && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ {
    sub(/^[[:space:]]*#[[:space:]]*/, "")
    found=0
    print
    next
  }
  found && /^[[:space:]]*Include[[:space:]]*=/ {
    found=0
    print
    next
  }
  { print }
' "$PACMAN_CONF" > "${PACMAN_CONF}.tmp" && mv "${PACMAN_CONF}.tmp" "$PACMAN_CONF"

echo "[multilib] section enabled in $PACMAN_CONF"

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

if grep -Eq '^[[:space:]]*\[cachyos\][[:space:]]*$' "$PACMAN_CONF"; then
  echo "[cachyos] section already enabled in $PACMAN_CONF"
else
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
fi

echo "Updating pacman database..."
pacman -Syu --noconfirm

# Optional package group
read -p "Install opinionated packages (opinionated.txt)? [Y/n]: " OPINIONATED_ANSWER
INSTALL_OPINIONATED=true
if [[ "$OPINIONATED_ANSWER" =~ ^[Nn] ]]; then INSTALL_OPINIONATED=false; fi

# Package arrays 
PACMAN_PACKAGES=()
AUR_PACKAGES=()
FLAT_PACKAGES=()

read_packages() {
  local file="$1"
  local -n arr_ref="$2"
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    arr_ref+=("$pkg")
  done < "$file"
}

load_package_file() {
  local dir="$1"
  local category="$2"
  local target_name="$3"
  local label="$4"
  local file="$dir/$category.txt"

  [[ -f "$file" ]] || return 0
  echo "Loading $label: $category.txt"
  read_packages "$file" "$target_name"
}

load_packages() {
  local dir="$1"
  local target_name="$2"
  local label="$3"

  [[ -d "$dir" ]] || return 0  # skip silently if dir doesn't exist

  load_package_file "$dir" "core" "$target_name" "$label"

  if [[ "$INSTALL_OPINIONATED" == true ]]; then
    load_package_file "$dir" "opinionated" "$target_name" "$label"
  fi
}

# Load base packages (always)
load_packages "$BASE_PKGS/pacman"  PACMAN_PACKAGES "pacman"
load_packages "$BASE_PKGS/aur"     AUR_PACKAGES    "AUR"
load_packages "$BASE_PKGS/flatpak" FLAT_PACKAGES   "flatpak"

# Installers 
install_pacman_pkgs() {
  local pkgs=("$@")
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      echo "$pkg already installed"
    else
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    pacman -S --noconfirm --needed "${to_install[@]}"
  fi
}

install_aur_pkgs() {
  local pkgs=("$@")
  local real_user="${SUDO_USER:-$(id -un)}"
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      echo "$pkg (AUR) already installed"
    else
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing from AUR: ${to_install[*]}"
    sudo -H -u "$real_user" yay -S --noconfirm --needed "${to_install[@]}"
  fi
}

install_flat_pkgs() {
  local pkgs=("$@")
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    if flatpak list --app | awk '{print $1}' | grep -qx "$pkg"; then
      echo "$pkg (Flatpak) already installed"
    else
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing from Flatpak: ${to_install[*]}"
    flatpak install -y flathub "${to_install[@]}"
  fi
}

# === Run installers ===
if [ ${#PACMAN_PACKAGES[@]} -gt 0 ]; then
  echo "=== Installing pacman packages ==="
  install_pacman_pkgs "${PACMAN_PACKAGES[@]}"
fi

if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
  echo "=== Installing AUR packages ==="
  install_aur_pkgs "${AUR_PACKAGES[@]}"
fi

if [ ${#FLAT_PACKAGES[@]} -gt 0 ]; then
  echo "=== Installing Flatpak packages ==="
  install_flat_pkgs "${FLAT_PACKAGES[@]}"
fi
