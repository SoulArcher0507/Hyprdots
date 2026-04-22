#!/usr/bin/env bash
set -euo pipefail

#   sudo ./install_plymouth_repo_theme.sh <theme_name> [repo_dir]
# Example:
#   sudo ./install_plymouth_repo_theme.sh colorful_loop ~/src/plymouth-themes
# Notes:
# - This script supports local repo paths. Clone the repo beforehand or vendor it
#   inside your dotfiles/resources tree.
# - It edits /etc/mkinitcpio.conf and tries to add "quiet splash" for GRUB or
#   systemd-boot entry files. Backups are created automatically.

THEME_NAME="${1:-colorful_loop}"
REPO_DIR="${2:-$HOME/plymouth-themes}"
LOGO_SOURCE="${LOGO_SOURCE:-/usr/share/pixmaps/archlinux-logo.png}"
THEMES_DIR="/usr/share/plymouth/themes"

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERR ] %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script as root."
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$file" "$backup"
  log "Backup created: $backup"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_theme_source() {
  local repo="$1" theme="$2"
  [[ -d "$repo" ]] || die "Repository directory not found: $repo"

  local result=""
  result="$(find "$repo" -mindepth 2 -maxdepth 2 -type d -name "$theme" 2>/dev/null | head -n1 || true)"
  [[ -n "$result" ]] || die "Theme '$theme' not found inside $repo"
  printf '%s\n' "$result"
}

get_theme_script_file() {
  local theme_dir="$1"
  local script_file="$theme_dir/$THEME_NAME.script"
  if [[ -f "$script_file" ]]; then
    printf '%s\n' "$script_file"
    return 0
  fi

  script_file="$(find "$theme_dir" -maxdepth 1 -type f -name '*.script' | head -n1 || true)"
  [[ -n "$script_file" ]] || die "No .script file found in $theme_dir"
  printf '%s\n' "$script_file"
}

copy_theme() {
  local source_dir="$1"
  local target_dir="$THEMES_DIR/$THEME_NAME"

  mkdir -p "$THEMES_DIR"
  rm -rf "$target_dir"
  cp -a "$source_dir" "$target_dir"
  log "Theme copied to $target_dir"
}

inject_arch_logo() {
  local theme_dir="$THEMES_DIR/$THEME_NAME"
  local script_file="$1"
  local logo_target="$theme_dir/archlinux-logo.png"

  [[ -f "$LOGO_SOURCE" ]] || die "Arch logo not found at $LOGO_SOURCE"
  cp -f "$LOGO_SOURCE" "$logo_target"

  if grep -q 'archlinux-logo.png' "$script_file"; then
    log "Arch logo snippet already present in $(basename "$script_file"), skipping injection."
    return 0
  fi

  cat >> "$script_file" <<'EOF'

# >>> arch-logo >>>
arch_logo_image = Image("archlinux-logo.png");
arch_logo_sprite = Sprite();
arch_logo_sprite.SetImage(arch_logo_image);
arch_logo_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - arch_logo_image.GetWidth() / 2));
arch_logo_sprite.SetY(Window.GetHeight() - arch_logo_image.GetHeight() - 50);
# <<< arch-logo <<<
EOF

  log "Arch logo injected into $(basename "$script_file")"
}

contains_word() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

insert_before_first_match() {
  local __resultvar="$1"; shift
  local item_to_insert="$1"; shift
  local regex="$1"; shift
  local arr=("$@")

  local out=()
  local inserted=0
  local item
  for item in "${arr[@]}"; do
    if [[ $inserted -eq 0 && "$item" =~ $regex ]]; then
      out+=("$item_to_insert")
      inserted=1
    fi
    out+=("$item")
  done

  if [[ $inserted -eq 0 ]]; then
    out+=("$item_to_insert")
  fi

  eval "$__resultvar=(\"\${out[@]}\")"
}

ensure_mkinitcpio_hooks() {
  local file="/etc/mkinitcpio.conf"
  [[ -f "$file" ]] || die "$file not found"

  backup_file "$file"

  local hooks_line
  hooks_line="$(grep -E '^[[:space:]]*HOOKS=\(' "$file" | head -n1 || true)"
  [[ -n "$hooks_line" ]] || die "Could not find HOOKS=() in $file"

  local inner="${hooks_line#*=(}"
  inner="${inner%)}"

  local hooks=()
  read -r -a hooks <<< "$inner"

  local filtered=()
  local h
  for h in "${hooks[@]}"; do
    case "$h" in
      plymouth|sd-plymouth|plymouth-encrypt)
        ;;
      *)
        filtered+=("$h")
        ;;
    esac
  done
  hooks=("${filtered[@]}")

  if ! contains_word "kms" "${hooks[@]}"; then
    local tmp=()
    insert_before_first_match tmp "kms" '^(keyboard|keymap|sd-vconsole|consolefont|block|filesystems)$' "${hooks[@]}"
    hooks=("${tmp[@]}")
    log "Added 'kms' hook to mkinitcpio."
  fi

  local tmp=()
  insert_before_first_match tmp "plymouth" '^(encrypt|sd-encrypt|filesystems|fsck)$' "${hooks[@]}"
  hooks=("${tmp[@]}")

  local new_line="HOOKS=(${hooks[*]})"
  sed -i "s|^[[:space:]]*HOOKS=.*|$new_line|" "$file"
  log "Updated mkinitcpio hooks: ${hooks[*]}"
}

append_args_if_missing() {
  local original="$1"; shift
  local out=" $original "
  local arg
  for arg in "$@"; do
    [[ "$out" =~ [[:space:]]$arg[[:space:]] ]] || out+="$arg "
  done
  out="${out#" "}"
  out="${out%" "}"
  printf '%s\n' "$out"
}

update_grub() {
  local file="/etc/default/grub"
  [[ -f "$file" ]] || return 1
  have_cmd grub-mkconfig || return 1

  backup_file "$file"

  local line value new_value
  line="$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' "$file" | head -n1 || true)"
  [[ -n "$line" ]] || die "GRUB detected but GRUB_CMDLINE_LINUX_DEFAULT was not found in $file"

  value="${line#*=}"
  value="${value%\"}"
  value="${value#\"}"
  new_value="$(append_args_if_missing "$value" quiet splash)"

  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_value\"|" "$file"

  local grub_cfg="/boot/grub/grub.cfg"
  [[ -d /boot/grub ]] || grub_cfg="/grub/grub.cfg"

  log "Updating GRUB kernel parameters: $new_value"
  grub-mkconfig -o "$grub_cfg" >/dev/null
  log "GRUB configuration regenerated."
  return 0
}

update_systemd_boot_entries() {
  local entries_dir=""
  if [[ -d /boot/loader/entries ]]; then
    entries_dir="/boot/loader/entries"
  elif [[ -d /efi/loader/entries ]]; then
    entries_dir="/efi/loader/entries"
  else
    return 1
  fi

  local found=0
  local entry
  shopt -s nullglob
  for entry in "$entries_dir"/*.conf; do
    found=1
    backup_file "$entry"

    if grep -qE '^options[[:space:]]+' "$entry"; then
      local line value new_value
      line="$(grep -E '^options[[:space:]]+' "$entry" | head -n1)"
      value="${line#options }"
      new_value="$(append_args_if_missing "$value" quiet splash)"
      sed -i "s|^options[[:space:]].*|options $new_value|" "$entry"
      log "Updated systemd-boot entry: $(basename "$entry")"
    else
      warn "No options line found in $(basename "$entry"), skipped."
    fi
  done
  shopt -u nullglob

  if [[ $found -eq 0 ]]; then
    return 1
  fi

  if [[ -f /etc/kernel/cmdline ]]; then
    backup_file /etc/kernel/cmdline
    local cmdline
    cmdline="$(cat /etc/kernel/cmdline)"
    cmdline="$(append_args_if_missing "$cmdline" quiet splash)"
    printf '%s\n' "$cmdline" > /etc/kernel/cmdline
    log "Updated /etc/kernel/cmdline too."
  fi

  return 0
}

regenerate_initramfs_and_set_theme() {
  local theme="$1"
  have_cmd plymouth-set-default-theme || die "plymouth-set-default-theme not found. Install plymouth and rerun."
  have_cmd mkinitcpio || die "mkinitcpio not found."
  plymouth-set-default-theme -R "$theme" >/dev/null
  log "Set Plymouth theme to '$theme' and rebuilt initramfs."
  mkinitcpio -P >/dev/null
  log "mkinitcpio presets regenerated."
}

main() {
  require_root

  local theme_source
  theme_source="$(find_theme_source "$REPO_DIR" "$THEME_NAME")"
  copy_theme "$theme_source"

  local script_file
  script_file="$(get_theme_script_file "$THEMES_DIR/$THEME_NAME")"
  inject_arch_logo "$script_file"

  ensure_mkinitcpio_hooks
  regenerate_initramfs_and_set_theme "$THEME_NAME"

  if update_grub; then
    log "Bootloader detected: GRUB"
  elif update_systemd_boot_entries; then
    log "Bootloader detected: systemd-boot"
  else
    warn "Could not auto-detect GRUB or systemd-boot entries."
    warn "Add 'quiet splash' manually to your kernel parameters."
  fi

  cat <<EOF

Done.
Selected theme : $THEME_NAME
Repo path      : $REPO_DIR
Theme target   : $THEMES_DIR/$THEME_NAME
Logo source    : $LOGO_SOURCE

Reboot to test the splash screen.
EOF
}

main "$@"
