# ~/docs
# ❯
#
# nixos-config/modules/shell  main* ⇡1 ⇣2  ❄️ dev
# ✦1 ❯
#
# bohdan@hephaestus  nixos-config  main
# ❮

zmodload zsh/datetime zsh/parameter
autoload -Uz add-zsh-hook add-zle-hook-widget

typeset -g _pr_heading=
typeset -g _pr_styled=
typeset -g _pr_show=
typeset -g _pr_place= _pr_root= _pr_git= _pr_git_root= _pr_nix= _pr_jobs= _pr_pwd= _pr_base=
typeset -g _pr_result=
typeset -g _pr_mode=ins
typeset -gi _pr_failed=0 _pr_fd=0 _pr_top=1
typeset -gF _pr_start=0

_pr_find_place() {
  local d=$PWD
  _pr_root=
  while :; do
    if [[ -e $d/.git ]]; then
      _pr_root=$d
      break
    fi
    [[ $d == / ]] && break
    d=${d:h}
  done
  if [[ -n $_pr_root ]]; then
    _pr_place=${_pr_root:t}${PWD#$_pr_root}
  else
    _pr_place=${(%):-%~}
  fi
}

_pr_encode() {
  emulate -L zsh
  local LC_ALL=C s=$1 out= c hex
  local -i i
  for (( i = 1; i <= $#s; i++ )); do
    c=$s[i]
    if [[ $c == [A-Za-z0-9/._~-] ]]; then
      out+=$c
    else
      printf -v hex '%%%02X' "'$c"
      out+=$hex
    fi
  done
  REPLY=$out
}

_pr_find_nix() {
  _pr_nix=
  if [[ -n $IN_NIX_SHELL || :$PATH: == *:/nix/store/* ]]; then
    _pr_nix='❄️'
    [[ -n $IN_NIX_SHELL && -n $name && $name != nix-shell* ]] && _pr_nix+=" $name"
  fi
}

_pr_duration() {
  local -i s=$1
  if (( s >= 3600 )); then
    REPLY="$(( s / 3600 ))h$(( s % 3600 / 60 ))m"
  elif (( s >= 60 )); then
    REPLY="$(( s / 60 ))m$(( s % 60 ))s"
  else
    REPLY="${s}s"
  fi
}

_pr_title() { print -rn -- $'\e]2;'"${1//[[:cntrl:]]/}"$'\a' }

_pr_render() {
  local c='❯'
  [[ $_pr_mode == (cmd|vis) ]] && c='❮'
  (( _pr_failed )) && c="%F{red}$c%f"
  [[ $_pr_mode == (vis|rep) ]] && c="%S$c%s"
  local url=$_pr_base${_pr_result:+#$_pr_result}
  PROMPT="%{"$'\e]133;A\e\\'"%}$_pr_show$_pr_jobs%{"$'\e]8;;'"${url//\%/%%}"$'\e\\'"%}$c%{"$'\e]8;;\e\\'"%}%{"$'\e]133;B\e\\'"%} "
}

_pr_heading_update() {
  local plain=$_pr_place styled="%F{blue}${_pr_place//\%/%%}%f"
  if [[ -n $SSH_CONNECTION ]]; then
    plain="${(%):-%n@%m}  $plain"
    styled="%F{yellow}%n@%m%f  $styled"
  fi
  if [[ -n $_pr_git ]]; then
    plain+="  $_pr_git"
    styled+="  %F{magenta}${_pr_git//\%/%%}%f"
  fi
  if [[ -n $_pr_nix ]]; then
    plain+="  $_pr_nix"
    styled+="  %{❄️%2G%}${${_pr_nix#❄️}//\%/%%}"
  fi
  _pr_title $plain
  [[ $plain == $_pr_heading ]] && return
  _pr_heading=$plain _pr_styled=$styled
  local nl=$'\n'
  _pr_show="${${_pr_top:#1}:+$nl}$styled$nl"
  _pr_top=0
  if [[ $1 == redraw ]]; then
    _pr_render
    zle reset-prompt
  fi
}

_pr_git_stop() {
  (( _pr_fd )) || return 0
  zle -F $_pr_fd 2>/dev/null
  exec {_pr_fd}<&-
  _pr_fd=0
}
_pr_git_start() {
  _pr_git_stop
  [[ -n $_pr_root ]] && (( $+commands[git] )) || return 1
  exec {_pr_fd}< <(GIT_OPTIONAL_LOCKS=0 command git -C $PWD status --porcelain=v2 --branch 2>/dev/null)
  zle -F -w $_pr_fd _pr-git-done
}
_pr-git-done() {
  local fd=$1 line branch oid ab dirty a b
  local -a lines
  while IFS= read -r -u $fd line; do lines+=($line); done
  zle -F $fd
  exec {fd}<&-
  _pr_fd=0
  for line in $lines; do
    case $line in
      ('# branch.head '*) branch=${line#\# branch.head } ;;
      ('# branch.oid '*) oid=${line#\# branch.oid } ;;
      ('# branch.ab '*) ab=${line#\# branch.ab } ;;
      ('#'*) ;;
      (*) dirty='*' ;;
    esac
  done
  [[ $branch == '(detached)' ]] && branch=$oid[1,7]
  _pr_git=$branch$dirty
  if [[ -n $_pr_git && -n $ab ]]; then
    a=${${ab%% *}#+} b=${${ab##* }#-}
    (( a )) && _pr_git+=" ⇡$a"
    (( b )) && _pr_git+=" ⇣$b"
  fi
  _pr_git_root=$_pr_root
  _pr_heading_update redraw
}
zle -N _pr-git-done

_pr_preexec() {
  _pr_start=$EPOCHREALTIME
  print -rn -- $'\e]133;C\e\\'
  _pr_title ${1[1,100]}
}

_pr_precmd() {
  local -i s=$?
  if (( _pr_start )); then
    print -rn -- $'\e]133;D;'$s$'\e\\'
    _pr_failed=$(( s != 0 ))
    _pr_result=
    (( s )) && _pr_result="exit=$s"
    local -i secs=$(( EPOCHREALTIME - _pr_start ))
    if (( secs >= 2 )); then
      _pr_duration $secs
      _pr_result+="${_pr_result:+&}took=$REPLY"
    fi
    _pr_start=0
  else
    _pr_result=
  fi
  _pr_jobs=
  (( $#jobstates )) && _pr_jobs="✦$#jobstates "
  if [[ $PWD != $_pr_pwd ]]; then
    _pr_pwd=$PWD
    _pr_find_place
    _pr_encode $PWD
    _pr_base="file://$HOST$REPLY"
    print -rn -- $'\e]7;'$_pr_base$'\e\\'
  fi
  _pr_find_nix
  _pr_mode=ins
  _pr_show=
  if ! _pr_git_start; then
    _pr_git=
    _pr_heading_update
  elif [[ $_pr_root == $_pr_git_root ]]; then
    _pr_heading_update
  fi
  _pr_render
}

_pr_mode_update() {
  local mode=ins
  if [[ $KEYMAP == vicmd ]]; then
    mode=cmd
    (( REGION_ACTIVE )) && mode=vis
  elif [[ $ZLE_STATE == *overwrite* ]]; then
    mode=rep
  fi
  [[ $mode == $_pr_mode ]] && return
  _pr_mode=$mode
  _pr_render
  zle reset-prompt
}

_pr_line_finish() {
  [[ $_pr_mode == ins ]] && return
  _pr_mode=ins
  _pr_render
  zle reset-prompt
}

_pr-clear-screen() {
  _pr_show=${_pr_styled:+$_pr_styled$'\n'}
  _pr_render
  zle .clear-screen
}
zle -N _pr-clear-screen
bindkey -M viins '^L' _pr-clear-screen
bindkey -M vicmd '^L' _pr-clear-screen

add-zsh-hook precmd _pr_precmd
add-zsh-hook preexec _pr_preexec
add-zle-hook-widget keymap-select _pr_mode_update
add-zle-hook-widget line-pre-redraw _pr_mode_update
add-zle-hook-widget line-finish _pr_line_finish
