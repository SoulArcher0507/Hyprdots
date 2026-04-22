export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less -R"

typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.go/bin"
  $path
)
export PATH
