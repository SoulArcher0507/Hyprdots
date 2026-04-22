#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

repo_count() {
  if has checkupdates; then
    ( checkupdates 2>/dev/null || true ) | wc -l
    return
  fi

  if has yay; then
    ( yay  -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi
  if has paru; then
    ( paru -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi

  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  ( pacman -Sy  --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true )
  ( pacman -Sup --dbpath "$tmp" 2>/dev/null || true ) | wc -l
}



aur_count() {
  if has yay;    then ( yay   -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has paru;   then ( paru  -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has pikaur; then ( pikaur -Qua --nocolor    2>/dev/null || true ) | wc -l; return; fi
  echo 0
}

flatpak_count() {
  command -v flatpak >/dev/null 2>&1 || { echo 0; return; }
  local s u
  s=$({ flatpak --system remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  u=$({ flatpak --user   remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  echo $((s + u))
}



p="$(repo_count)"
a="$(aur_count)"
f="$(flatpak_count)"
t=$(( p + a + f ))
printf '{"pacman":%s,"aur":%s,"flatpak":%s,"total":%s}
' "$p" "$a" "$f" "$t"
