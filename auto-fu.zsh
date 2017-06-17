# Code

afu_zles=( \
  self-insert backward-delete-char backward-kill-word kill-line \
  kill-whole-line kill-word magic-space yank \
)

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

afu-install () {
  bindkey -N afu emacs
  { "$@" }
  bindkey -M afu "^I" afu+expand-or-complete
  bindkey -M afu "^M" afu+accept-line
}

afu-install afu-keymap+widget

afu-register-zle-accept-line () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  local code=${"$(<=(cat <<"EOT"
  $afufun () {
    __accepted=($WIDGET ${=NUMERIC:+-n $NUMERIC} "$@")
    zle $rawzle && {
      local hi
    }
    zstyle -T ':auto-fu:var' postdisplay/clearp && POSTDISPLAY=''
    return 0
  }
  zle -N $afufun
EOT
  ))"}
  eval "${${code//\$afufun/$afufun}//\$rawzle/$rawzle}"
  afu_accept_lines+=$afufun
    BUFFER=''
}

#irrelevant solely for printing lines
afu-register-zle-expand-or-complete () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  local code=${"$(<=(cat <<"EOT"
  $afufun () {
    if [[ $afu_one_match_p != t ]]; then
        buffer_cur="$BUFFER"
    fi
    zle $rawzle
    return 0
  }
  zle -N $afufun
EOT
  ))"}
  eval "${${code//\$afufun/$afufun}//\$rawzle/$rawzle}"
}
afu-register-zle-accept-line afu+accept-line
afu-register-zle-expand-or-complete afu+expand-or-complete

# Entry point.
auto-fu-init () {
    zle_highlight=(default:"fg=green,bold")
  local auto_fu_init_p=1
  local ps
  {
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

afu-recursive-edit-and-accept () {
  local -a __accepted
    region_highlight=("${#buffer_cur} ${#buffer_new} fg=white")
  zle recursive-edit -K afu || { zle -R ''; zle send-break; return }
  [[ -n ${__accepted} ]] &&
  (( ${#${(M)afu_accept_lines:#${__accepted[1]}}} > 1 )) &&
  { zle "${__accepted[@]}"} || { zle accept-line }
}

afu-clearing-maybe () {
  #region_highlight=()
  if ((afu_in_p == 1)); then
    [[ "$BUFFER" != "$buffer_new" ]] || ((CURSOR != cursor_cur)) &&
    { afu_in_p=0 }
  fi
}

with-afu () {
    local zlefun="$1"; shift
    local -a zs
    : ${(A)zs::=$@}
    afu-clearing-maybe
    ((afu_in_p == 1)) && { afu_in_p=0; BUFFER="$buffer_cur" }
    zle $zlefun && {
        setopt localoptions extendedglob no_banghist
        #region_highlight=("P0 ${#buffer_cur} fg=green")
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

auto-fu-maybe () {
  (($PENDING== 0)) && [[ $LBUFFER != *$'\012'*  ]] &&
  { auto-fu }
}

auto-fu () {
    cursor_cur="$CURSOR"
    buffer_cur="$BUFFER"
    with-afu-completer-vars zle complete-word
    cursor_new="$CURSOR"
    buffer_new="$BUFFER"
    region_highlight=("${#buffer_cur} ${#buffer_new} fg=242,underline")

    if [[ "$buffer_cur[1,cursor_cur]" == "$buffer_new[1,cursor_cur]" ]]; then
    CURSOR="$cursor_cur"
    {
      local hi hiv
      [[ $afu_one_match_p == t ]] && hi=completion/one || hi=completion
      zstyle -s ':auto-fu:highlight' "$hi" hiv
      [[ -z ${hiv} ]] || {
        local -i end=$cursor_new
        [[ $BUFFER[$cursor_new] == ' ' ]] && (( end-- ))
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

with-afu-completer-vars () {
  setopt localoptions no_recexact
  local LISTMAX=999999
  with-afu-compfuncs "$@"
}

with-afu-compfuncs () {
  comppostfuncs=(afu-comppost)
  "$@"
}

afu-comppost () {
((compstate[list_lines] + 2 > ( LINES ))) && {
    compstate[list]=''
    zle -M "$compstate[list_lines]($compstate[nmatches]) too many matches..."
  }

  typeset -g afu_one_match_p=
  (( $compstate[nmatches] == 1 )) && afu_one_match_p=t
}
zle -N auto-fu

