#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/ key-bindings.bash
#
# - $FZF_TMUX_OPTS
# - $FZF_CTRL_T_COMMAND
# - $FZF_CTRL_T_OPTS
# - $FZF_CTRL_R_OPTS
# - $FZF_ALT_C_COMMAND
# - $FZF_ALT_C_OPTS

# Key bindings
# ------------
__fzf_select__() {  ## {{{
  ##  NOTE a simple version of this function is used in select_file function in ~/scripts/gb
  ##       any change you make here, make sure to apply the changes there too

  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | sed "s#$HOME#~#" | FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS --expect=ctrl-v" $(__fzfcmd) "$@" | while read -r item; do  ## do NOT move --expect=ctrl-v to bashrc in FZF_CTRL_T_OPTS because it makes fzf select in lf screw up and not select file properly
  ## '--> ORIG: eval "$cmd" | FZF_DEFAULT_OPTS="--expect=ctrl-v --preview 'eval $HIGHLIGHT {-1} 2>/dev/null' --header 'select' --height ${FZF_TMUX_HEIGHT:-70%} --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS --preview-window noborder:right:70%:wrap" $(__fzfcmd) -m "$@" | while read -r item; do

      # https://github.com/junegunn/fzf/wiki/Examples in fo(){} function
      key=$(head -1 <<< "$item")
      item=$(head -2 <<< "$item" | tail -1)
      [ "$key" = ctrl-v ] && printf 'vim ' "$item" || printf "$item"

  done
  echo
}
## }}}

if [[ $- =~ i ]]; then
__fzfcmd() {  ## {{{
  [ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-70%}} -- " || echo "fzf"
}
## }}}
fzf-file-widget() {  ## {{{
  local selected="$(__fzf_select__)"
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
}
## }}}
__fzf_cd__() {  ## {{{
    ##  NOTE a simple version of this function is used in select_directory function in ~/scripts/gb
    ##       any change you make here, make sure to apply the changes there too

    local cmd dir

    cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"

    ## NOTE do NOT join JUMP_1 and JUMP_2 with && \
    dir="$(eval "$cmd" | sed "s#$HOME#~#" | FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd))"  ## JUMP_1
    [ "$dir" ] && printf 'cd %q' "${dir/\~/$HOME}"  ## JUMP_2 keep \~ escaped
    ## '--> ORIG: dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="--preview '\ls -A --color=always --group-directories-first {-1}' --header 'cd' --height ${FZF_TMUX_HEIGHT:-70%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS --preview-window noborder:right:70%:wrap" $(__fzfcmd) +m) && printf 'cd %q' "$dir"
}
## }}}
__fzf_history__() {  ## {{{
  local output

  output=$(
    builtin fc -lnr -2147483648 |
      last_hist=$(HISTTIMEFORMAT='' builtin history 1) perl -n -l0 -e 'BEGIN { getc; $/ = "\n\t"; $HISTCMD = $ENV{last_hist} + 1 } s/^[ *]//; print $HISTCMD - $. . "\t$_" if !$seen{$_}++' |
      FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CTRL_R_OPTS -n2..,.. --tiebreak=index --read0" $(__fzfcmd) --query "$READLINE_LINE"
      ## '--> ORIG: FZF_DEFAULT_OPTS="--header 'history' --height ${FZF_TMUX_HEIGHT:-70%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m --read0" $(__fzfcmd) --query "$READLINE_LINE"
  ) || return
  READLINE_LINE=${output#*$'\t'}
  if [ -z "$READLINE_POINT" ]; then
    echo "$READLINE_LINE"
  else
    READLINE_POINT=0x7fffffff
  fi
}
## }}}
## Required to refresh the prompt after fzf {{{
bind -m emacs-standard '"\er": redraw-current-line'

bind -m vi-command '"\C-z": emacs-editing-mode'
bind -m vi-insert '"\C-z": emacs-editing-mode'
bind -m emacs-standard '"\C-z": vi-editing-mode'

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  # CTRL-T - Paste the selected file path into the command line
  bind -m emacs-standard '"\C-t": " \C-b\C-k \C-u`__fzf_select__`\e\C-e\er\C-a\C-y\C-h\C-e\e \C-y\ey\C-x\C-x\C-f"'
  bind -m vi-command '"\C-t": "\C-z\C-t\C-z"'
  bind -m vi-insert '"\C-t": "\C-z\C-t\C-z"'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard '"\C-r": "\C-e \C-u\C-y\ey\C-u"$(__fzf_history__)"\e\C-e\er"'
  bind -m vi-command '"\C-r": "\C-z\C-r\C-z"'
  bind -m vi-insert '"\C-r": "\C-z\C-r\C-z"'
else
  # CTRL-T - Paste the selected file path into the command line
  bind -m emacs-standard -x '"\C-t": fzf-file-widget'
  bind -m vi-command -x '"\C-t": fzf-file-widget'
  bind -m vi-insert -x '"\C-t": fzf-file-widget'

  ## By me:
  bind -m vi-insert -x '"\et": fzf-file-widget'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard -x '"\C-r": __fzf_history__'
  bind -m vi-command -x '"\C-r": __fzf_history__'
  bind -m vi-insert -x '"\C-r": __fzf_history__'
fi

# ALT-C - cd into the selected directory
bind -m emacs-standard '"\ec": " \C-b\C-k \C-u`__fzf_cd__`\e\C-e\er\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d"'
bind -m vi-command '"\ec": "\C-z\ec\C-z"'
bind -m vi-insert '"\ec": "\C-z\ec\C-z"'
## }}}
fi
