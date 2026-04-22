#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exec sudo "$0" "$@"
fi

# Argument parsing
THEME=""
if [[ $# -gt 0 ]]; then
  case "${1,,}" in  # lowercase for case-insensitivity
    pc)     THEME="pc" ;;
    laptop) THEME="laptop" ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [pc|laptop]"
      exit 1
      ;;
  esac
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASE_PKGS="$REPO_ROOT/Resources/Pkgs"

case "$THEME" in
  pc)     THEME_PKGS="$REPO_ROOT/Themes/Desktop/Desktop-Pkgs" ;;
  laptop) THEME_PKGS="$REPO_ROOT/Themes/Laptop/Laptop-Pkgs" ;;
  *)      THEME_PKGS="" ;;
esac

# pacman.conf setup 
PACMAN_CONF="/etc/pacman.conf"
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

echo "Updating pacman database..."
pacman -Syu --noconfirm

# Optional package groups 
read -p "Install development packages (dev.txt)? [Y/n]: " DEV_ANSWER
INSTALL_DEV=true
if [[ "$DEV_ANSWER" =~ ^[Nn] ]]; then INSTALL_DEV=false; fi

read -p "Install gaming packages (gaming.txt)? [Y/n]: " GAMING_ANSWER
INSTALL_GAMING=true
if [[ "$GAMING_ANSWER" =~ ^[Nn] ]]; then INSTALL_GAMING=false; fi

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

load_packages() {
  local dir="$1"
  local -n target="$2"
  local label="$3"
  [[ -d "$dir" ]] || return 0  # skip silently if dir doesn't exist
  for file in "$dir"/*.txt; do
    [[ -f "$file" ]] || continue
    base=$(basename "$file")
    if [[ "$base" == "dev.txt"    && "$INSTALL_DEV"    != true ]]; then continue; fi
    if [[ "$base" == "gaming.txt" && "$INSTALL_GAMING" != true ]]; then continue; fi
    echo "Loading $label: $base"
    read_packages "$file" target
  done
}

# Load base packages (always)
load_packages "$BASE_PKGS/pacman"  PACMAN_PACKAGES "pacman"
load_packages "$BASE_PKGS/aur"     AUR_PACKAGES    "AUR"
load_packages "$BASE_PKGS/flatpak" FLAT_PACKAGES   "flatpak"

# Load theme packages (only if a theme was specified)
if [[ -n "$THEME_PKGS" ]]; then
  echo "=== Loading theme packages: $THEME ==="
  load_packages "$THEME_PKGS/pacman"  PACMAN_PACKAGES "pacman [$THEME]"
  load_packages "$THEME_PKGS/aur"     AUR_PACKAGES    "AUR [$THEME]"
  load_packages "$THEME_PKGS/flatpak" FLAT_PACKAGES   "flatpak [$THEME]"
fi

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
