#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }
run_limited() {
  local seconds="$1"
  shift

  if has timeout; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

repo_count() {
  if has checkupdates; then
    ( run_limited 8s checkupdates 2>/dev/null || true ) | wc -l
    return
  fi

  if has yay; then
    ( run_limited 8s yay  -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi
  if has paru; then
    ( run_limited 8s paru -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi

  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  ( run_limited 8s pacman -Sy  --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true )
  ( run_limited 8s pacman -Sup --dbpath "$tmp" 2>/dev/null || true ) | wc -l
}



aur_count() {
  if has yay;    then ( run_limited 8s yay   -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has paru;   then ( run_limited 8s paru  -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has pikaur; then ( run_limited 8s pikaur -Qua --nocolor    2>/dev/null || true ) | wc -l; return; fi
  echo 0
}

flatpak_count() {
  command -v flatpak >/dev/null 2>&1 || { echo 0; return; }
  local s u
  s=$({ run_limited 4s flatpak --system remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  u=$({ run_limited 4s flatpak --user   remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  echo $((s + u))
}



p="$(repo_count)"
a="$(aur_count)"
f="$(flatpak_count)"
t=$(( p + a + f ))
printf '{"pacman":%s,"aur":%s,"flatpak":%s,"total":%s}
' "$p" "$a" "$f" "$t"
