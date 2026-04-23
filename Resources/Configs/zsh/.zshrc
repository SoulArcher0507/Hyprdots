autoload -Uz colors && colors
autoload -Uz compinit
zmodload zsh/complist
zmodload zsh/terminfo 2>/dev/null || true

export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "$ZSH_CACHE_DIR" "$ZSH_STATE_DIR"

HISTFILE="$ZSH_STATE_DIR/history"
HISTSIZE=100000
SAVEHIST=100000

setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt interactive_comments
setopt append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_reduce_blanks
setopt extended_glob
setopt prompt_subst

fpath=(
  "$ZDOTDIR/completions"
  /usr/share/zsh/site-functions
  $fpath
)
compinit -d "$ZSH_CACHE_DIR/.zcompdump-$ZSH_VERSION"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _extensions _complete _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*' squeeze-slashes true

bindkey -e
bindkey '^[[3~' delete-char
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char
bindkey '^W' backward-kill-word
bindkey '^[f' forward-word
bindkey '^[b' backward-word

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line

bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D' backward-word
bindkey '^[[5C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

[[ -n ${terminfo[khome]-} ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n ${terminfo[kend]-} ]] && bindkey "${terminfo[kend]}" end-of-line
[[ -n ${terminfo[kLFT5]-} ]] && bindkey "${terminfo[kLFT5]}" backward-word
[[ -n ${terminfo[kRIT5]-} ]] && bindkey "${terminfo[kRIT5]}" forward-word

source "$ZDOTDIR/kitty-colors.zsh"
source "$ZDOTDIR/prompt.zsh"

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias launcher='qs -c ~/.config/quickshell/launcher -d'
alias gamelauncher='qs -c ~/.config/quickshell/gamelauncher -d'
alias overview='qs -c ~/.config/quickshell/overview -d'

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)

  _tab_or_partial_autosuggest() {
    if [[ -n ${POSTDISPLAY-} ]] && (( $+widgets[autosuggest-partial-accept] )); then
      zle autosuggest-partial-accept
    else
      zle expand-or-complete
    fi
  }
  zle -N _tab_or_partial_autosuggest
  bindkey '^I' _tab_or_partial_autosuggest

  _end_or_autosuggest_accept() {
    if [[ -n ${POSTDISPLAY-} ]] && (( $+widgets[autosuggest-accept] )); then
      zle autosuggest-accept
    else
      zle end-of-line
    fi
  }
  zle -N _end_or_autosuggest_accept
  bindkey '^[[F' _end_or_autosuggest_accept
  bindkey '^[OF' _end_or_autosuggest_accept
  bindkey '^[[4~' _end_or_autosuggest_accept
  bindkey '^[[8~' _end_or_autosuggest_accept
fi

if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
