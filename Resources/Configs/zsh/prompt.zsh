autoload -Uz add-zsh-hook

typeset -g KITTY_COLORS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/colors.conf"
typeset -gi _KTY_COLORS_MTIME=0
typeset -g _PROMPT_GIT_INFO=""
typeset -gi _PROMPT_LAST_STATUS=0

segment() {
  local bg="$1"
  local fg="$2"
  local text="$3"
  local next_bg="$4"

  if [[ -n "$next_bg" ]]; then
    print -nr -- "%K{$bg}%F{$fg} ${text} %K{$next_bg}%F{$bg}%f"
  else
    print -nr -- "%K{$bg}%F{$fg} ${text} "
  fi
}

arrow() {
  local left_bg="$1"
  local right_bg="$2"
  print -nr -- "%K{$right_bg}%F{$left_bg}%f"
}

endcap() {
  local bg="$1"
  print -nr -- "%k%F{$bg}%f"
}

_git_operation() {
  local gitdir
  gitdir="$(command git rev-parse --git-dir 2>/dev/null)" || return

  [[ -f "$gitdir/MERGE_HEAD" ]] && { print -nr -- "MERGE"; return; }
  [[ -f "$gitdir/CHERRY_PICK_HEAD" ]] && { print -nr -- "CHERRY"; return; }
  [[ -f "$gitdir/REVERT_HEAD" ]] && { print -nr -- "REVERT"; return; }
  [[ -f "$gitdir/BISECT_LOG" ]] && { print -nr -- "BISECT"; return; }
  [[ -d "$gitdir/rebase-merge" || -d "$gitdir/rebase-apply" ]] && { print -nr -- "REBASE"; return; }
}

git_prompt_info() {
  (( $+commands[git] )) || return
  command git rev-parse --is-inside-work-tree &>/dev/null || return

  local line branch="" xy x y op
  local -i ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflicted=0 stashed=0
  local -a states

  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*)
        branch="${line#\# branch.head }"
        if [[ "$branch" == "(detached)" ]]; then
          branch="@$(command git rev-parse --short HEAD 2>/dev/null)"
        fi
        ;;
      '# branch.ab '*)
        if [[ "$line" =~ '^# branch\.ab \+([0-9]+) -([0-9]+)$' ]]; then
          ahead=${match[1]}
          behind=${match[2]}
        fi
        ;;
      '1 '*|'2 '*)
        xy=${${(s: :)line}[2]}
        x=${xy[1,1]}
        y=${xy[2,2]}
        [[ "$x" != "." ]] && (( staged++ ))
        [[ "$y" != "." ]] && (( unstaged++ ))
        ;;
      'u '*)
        (( conflicted++ ))
        ;;
      '? '*)
        (( untracked++ ))
        ;;
    esac
  done < <(command git status --porcelain=2 --branch 2>/dev/null)

  if command git rev-parse --verify refs/stash &>/dev/null; then
    stashed=1
  fi

  op="$(_git_operation)"

  (( ahead > 0 ))      && states+=("⇡${ahead}")
  (( behind > 0 ))     && states+=("⇣${behind}")
  (( staged > 0 ))     && states+=("+${staged}")
  (( unstaged > 0 ))   && states+=("~${unstaged}")
  (( untracked > 0 ))  && states+=("?${untracked}")
  (( conflicted > 0 )) && states+=("!${conflicted}")
  (( stashed > 0 ))    && states+=("*")

  local info=" ${branch:-git}"
  [[ -n "$op" ]] && info+=":${op}"
  (( ${#states[@]} )) && info+=" · ${(j: · :)states}"

  print -nr -- "$info"
}

update_git_cache() {
  _PROMPT_GIT_INFO="$(git_prompt_info)"
}

build_prompt() {
  local a b c e g r1 r2 r3 first_next_bg

  first_next_bg="$KTY_COLOR11"
  if (( _PROMPT_LAST_STATUS != 0 )); then
    first_next_bg="$KTY_COLOR1"
    e="$(segment "$KTY_COLOR1" "$KTY_BACKGROUND" "✘ ${_PROMPT_LAST_STATUS}" "$KTY_COLOR11")"
  fi

  a="$(segment "$KTY_COLOR13" "$KTY_BACKGROUND" "󰣇  %n" "$first_next_bg")"

  if [[ -n "$_PROMPT_GIT_INFO" ]]; then
    b="$(segment "$KTY_COLOR11" "$KTY_BACKGROUND" "%~" "$KTY_COLOR10")"
    g="$(segment "$KTY_COLOR10" "$KTY_BACKGROUND" "$_PROMPT_GIT_INFO" "$KTY_COLOR14")"
    c="$(segment "$KTY_COLOR14" "$KTY_BACKGROUND" " %D{%H:%M}")$(endcap "$KTY_COLOR14")"
    PROMPT="${a}${e}${b}${g}${c} "
  else
    b="$(segment "$KTY_COLOR11" "$KTY_BACKGROUND" "%~")"
    r1="$(arrow "$KTY_COLOR11" "$KTY_COLOR10")"
    r2="$(arrow "$KTY_COLOR10" "$KTY_COLOR12")"
    r3="$(arrow "$KTY_COLOR12" "$KTY_COLOR14")"
    c="$(segment "$KTY_COLOR14" "$KTY_BACKGROUND" " %D{%H:%M}")$(endcap "$KTY_COLOR14")"
    PROMPT="${a}${e}${b}${r1}${r2}${r3}${c} "
  fi
}

_load_kitty_colors_if_needed() {
  local mtime=0
  [[ -r "$KITTY_COLORS_FILE" ]] && mtime="$(command stat -Lc %Y -- "$KITTY_COLORS_FILE" 2>/dev/null || print 0)"

  if (( mtime != _KTY_COLORS_MTIME )); then
    load_kitty_colors
    _KTY_COLORS_MTIME=$mtime
  fi
}

_redraw_prompt_now() {
  if zle -I 2>/dev/null; then
    zle reset-prompt
    zle -R
  fi
}

_prompt_precmd() {
  local last_status=$?

  _PROMPT_LAST_STATUS=$last_status
  _load_kitty_colors_if_needed
  update_git_cache
  build_prompt
}

reloadtheme() {
  _KTY_COLORS_MTIME=0
  _load_kitty_colors_if_needed
  build_prompt
  _redraw_prompt_now
}

TRAPUSR1() {
  _KTY_COLORS_MTIME=0
  _load_kitty_colors_if_needed
  build_prompt
  _redraw_prompt_now
}

if [[ -o interactive ]]; then
  add-zsh-hook precmd _prompt_precmd
fi
