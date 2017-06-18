source $HOME/.zsh/auto-fu.zsh/auto-fu.zsh
zstyle ':completion:*:default'         list-colors ${(s.:.)LS_COLORS}
function zle-line-init () {
   auto-fu-init
   zle reset-prompt
}
zle -N zle-line-init
