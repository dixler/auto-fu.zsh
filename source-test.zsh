source $HOME/.zsh/auto-fu.zsh/auto-fu.zsh
zstyle ':completion:*:default'         list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions'    format $'%{\e[0;31m%}completing %B%d%b%{\e[0m%}'                                                             
zstyle ':completion:*' special-dirs ..
function zle-line-init () {
   auto-fu-init
   zle reset-prompt
}
zle -N zle-line-init
