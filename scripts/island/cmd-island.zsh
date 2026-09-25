# Dynamic Island: commands running longer than ISLAND_CMD_MIN seconds (default 30) show up as a live
# activity, and report ✓/✗ with the duration when they finish (output, run again and go to terminal in
# the expanded view). Nothing shows while the terminal is the focused window. Sourced from ~/.zshrc.
# Interactive programs (editors, pagers, ssh, TUIs) are skipped; git push/pull is handled by git-island.zsh.

typeset -g ISLAND_CMD_MIN=${ISLAND_CMD_MIN:-30}
typeset -ga ISLAND_CMD_SKIP=(vim nvim vi nano micro hx less more man ssh mosh top htop btop nvtop claude yazi
    ranger nnn tmux zellij screen mpv watch tail fzf lazygit tig python python3 ipython node bun deno irb psql
    mysql sqlite3 sudoedit git)
typeset -g _island_helper=${${(%):-%x}:A:h}/cmd-island.sh

zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

_island_cmd_preexec() {
    (( $+commands[qs] )) || return
    local -a words=(${(z)1})
    local first=${words[1]}
    [[ $first == (sudo|env|time|nohup) ]] && first=${words[2]}
    (( ${ISLAND_CMD_SKIP[(Ie)${first:t}]} )) && return
    typeset -g _island_cmd=${1[1,60]} _island_cmd_full=$1 _island_cmd_start=$EPOCHREALTIME _island_cmd_id="cmd-$$-$RANDOM"
    # The activity only appears once the command has really been running for a while
    { sleep $ISLAND_CMD_MIN; bash $_island_helper start "$_island_cmd_id" "$_island_cmd" $$ } >/dev/null 2>&1 &!
    typeset -g _island_cmd_timer=$!
}

_island_cmd_precmd() {
    local code=$?
    [[ -n $_island_cmd_start ]] || return
    kill $_island_cmd_timer 2>/dev/null
    local took=$(( EPOCHREALTIME - _island_cmd_start ))
    took=${took%.*}
    if (( took >= ISLAND_CMD_MIN )); then
        bash $_island_helper finish "$_island_cmd_id" "$_island_cmd" $$ $code $took "$PWD" "$_island_cmd_full" >/dev/null 2>&1 &!
    fi
    unset _island_cmd _island_cmd_full _island_cmd_start _island_cmd_id _island_cmd_timer
}

add-zsh-hook preexec _island_cmd_preexec
# First in line so the exit code isn't replaced by other prompt hooks
precmd_functions=(_island_cmd_precmd ${precmd_functions:#_island_cmd_precmd})
