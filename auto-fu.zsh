# Code

#CRITICAL
#afu_zles=( \
  #self-insert backward-delete-char backward-kill-word kill-line \
  #kill-whole-line kill-word magic-space yank \
#)
afu_zles=( \
  self-insert backward-delete-char backward-kill-word kill-line \
  kill-whole-line kill-word yank \
)
#CRITICAL
autoload +X keymap+widget
() {
  setopt localoptions extendedglob no_shwordsplit
  local code=${(S)${functions[keymap+widget]/for w in *
	do
/for w in $afu_zles
  do
  }/(#b)(\$w-by-keymap \(\) \{*\})/
  eval \${\${\${\"\$(echo \'$match\')\"}/\\\$w/\$w}//\\\$WIDGET/\$w}
  }
  eval "function afu-keymap+widget () { $code }"
}


#CRITICAL for some reason
afu-install () {
    zstyle -t ':auto-fu:var' misc-installed-p || {
        zmodload zsh/parameter 2>/dev/null || {
            echo 'auto-fu:zmodload error. exiting.' >&2; exit -1
    }
  } always {
    zstyle ':auto-fu:var' misc-installed-p yes
  }

  bindkey -N afu emacs
  { "$@" }
  #bindkey -M afu "^I" expand-or-complete
  #bindkey -M afu "^M" accept-line
  #bindkey -M afu "^J" accept-line
  #bindkey -M afu "^O" accept-line-and-down-history
  #bindkey -M afu "^[a" accept-and-hold
  #bindkey -M afu "^X^[" vi-cmd-mode
  #bindkey -N afu-vicmd vicmd

  bindkey -M afu "^I" expand-or-complete
  bindkey -M afu "^M" afu+accept-line
  bindkey -M afu "^J" afu+accept-line
  bindkey -M afu "^O" delta+accept-line-and-down-history
  bindkey -M afu "^[a" accept-and-hold
  bindkey -M afu "^X^[" vi-cmd-mode
  bindkey -N afu-vicmd vicmd
}

#CRITICAL because I suck
afu-install afu-keymap+widget

#irrelevant solely for printing lines
afu-register-zle-accept-line () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  #REMOVE BUFFER_CUR LATER
  local code=${"$(<=(cat <<"EOT"
  $afufun () {
    BUFFER="$buffer_cur"
    __accepted=($WIDGET ${=NUMERIC:+-n $NUMERIC} "$@")
    zle $rawzle && {
      local hi
      zstyle -s ':auto-fu:highlight' input hi
      [[ -z ${hi} ]] || region_highlight=("0 ${#BUFFER} ${hi}")
    }
    zstyle -T ':auto-fu:var' postdisplay/clearp && POSTDISPLAY=''
    return 0
  }
  zle -N $afufun
EOT
  ))"}
  eval "${${code//\$afufun/$afufun}//\$rawzle/$rawzle}"
  afu_accept_lines+=$afufun
}
afu-register-zle-accept-line afu+accept-line
afu-register-zle-accept-line accept-line-and-down-history
afu-register-zle-accept-line accept-and-hold

# Entry point.
auto-fu-init () {
  local auto_fu_init_p=1
  local ps
  {
    local -a region_highlight
    local afu_in_p=0
    local afu_paused_p=0

    zstyle -s ':auto-fu:var' postdisplay ps
    [[ -z ${ps} ]] || POSTDISPLAY="$ps"

    afu-recursive-edit-and-accept
    zle -I
  } always {
    [[ -z ${ps} ]] || POSTDISPLAY=''
  }
}
zle -N auto-fu-init

#CRITICAL
afu-recursive-edit-and-accept () {
  local -a __accepted
  zle recursive-edit -K afu || { zle -R ''; zle send-break; return }
  [[ -n ${__accepted} ]] &&
  (( ${#${(M)afu_accept_lines:#${__accepted[1]}}} > 1 )) &&
  { zle "${__accepted[@]}"} || { zle accept-line }
}

#Aesthetic clear buffer
afu-clearing-maybe () {
  region_highlight=()
  if ((afu_in_p == 1)); then
    [[ "$BUFFER" != "$buffer_new" ]] || ((CURSOR != cursor_cur)) &&
    { afu_in_p=0 }
  fi
}

#CRITITAL
with-afu () {
    local zlefun="$1"; shift
    local -a zs
    : ${(A)zs::=$@}
    afu-clearing-maybe
    ((afu_in_p == 1)) && { afu_in_p=0; BUFFER="$buffer_cur" }
    zle $zlefun && {
        setopt localoptions extendedglob no_banghist
        local es ds
        zstyle -a ':auto-fu:var' enable es; (( ${#es} == 0 )) && es=(all)
        if [[ -n ${(M)es:#(#i)all} ]]; then
            zstyle -a ':auto-fu:var' disable ds
            : ${(A)es::=${zs:#(${~${(j.|.)ds}})}}
        fi
        [[ -n ${(M)es:#${zlefun#.}} ]]
    } && {
        auto-fu-maybe
    }
}

#CRITICAL
afu-register-zle-afu () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  eval "function $afufun () { with-afu $rawzle $afu_zles; }; zle -N $afufun"
}

afu-initialize-zle-afu () {
  local z
  for z in $afu_zles ;do
    afu-register-zle-afu $z
  done
}
afu-initialize-zle-afu

#CRITICAL
auto-fu-maybe () {
  (($PENDING== 0)) && [[ $LBUFFER != *$'\012'*  ]] &&
  { auto-fu }
}

#CRITICAL
auto-fu () {
    zle reset-prompt
    cursor_cur="$CURSOR"
    buffer_cur="$BUFFER"
    with-afu-completer-vars zle complete-word
    cursor_new="$CURSOR"
    buffer_new="$BUFFER"

    if [[ "$buffer_cur[1,cursor_cur]" == "$buffer_new[1,cursor_cur]" ]]; then
    CURSOR="$cursor_cur"
    {
      local hi hiv
      [[ $afu_one_match_p == t ]] && hi=completion/one || hi=completion
      zstyle -s ':auto-fu:highlight' "$hi" hiv
      [[ -z ${hiv} ]] || {
        local -i end=$cursor_new
        [[ $BUFFER[$cursor_new] == ' ' ]] && (( end-- ))
        region_highlight=("$CURSOR $end ${hiv}")
      }
    }

    if [[ "$buffer_cur" != "$buffer_new" ]] || ((cursor_cur != cursor_new))
    then afu_in_p=1; {
      local BUFFER="$buffer_cur"
      local CURSOR="$cursor_cur"
      with-afu-completer-vars zle list-choices
    }
    fi
  else
    BUFFER="$buffer_cur"
    CURSOR="$cursor_cur"
    zle list-choices
  fi
}

#CRITICAL
with-afu-completer-vars () {
  setopt localoptions no_recexact
  local LISTMAX=999999
  with-afu-compfuncs "$@"
}

#CRITICAL
with-afu-compfuncs () {
  comppostfuncs=(afu-comppost)
  "$@"
}

#CRITICAL Makes it less annoying
afu-comppost () {
  ((compstate[list_lines] + BUFFERLINES + 2 > LINES)) && {
    compstate[list]=''
    zle -M "$compstate[list_lines]($compstate[nmatches]) too many matches..."
  }

  typeset -g afu_one_match_p=
  (( $compstate[nmatches] == 1 )) && afu_one_match_p=t
}

zle -N auto-fu

