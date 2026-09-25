#!/usr/bin/env bash
# Dynamic Island helper for long terminal commands, called in the background by cmd-island.zsh and
# ~/.config/fish/conf.d/island.fish:
#   cmd-island.sh start  <id> <title> <shell-pid>
#   cmd-island.sh finish <id> <title> <shell-pid> <exit-code> <seconds> <cwd> <command>
# Nothing shows up while the terminal running the command is the focused window.
command -v qs >/dev/null 2>&1 || exit 0
mode=$1 id=$2 title=$3 shell=$4

terminal_of() {
    local pid=$1 comm
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
        comm=$(ps -o comm= -p "$pid" 2>/dev/null) || return
        case "$comm" in
            foot|footclient|kitty|alacritty|wezterm-gui|ghostty|konsole|gnome-terminal-|xterm) echo "$pid $comm"; return ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -n $pid && $pid -gt 1 ]] || return
    done
}

read -r term comm <<< "$(terminal_of "$shell")"
term=${term:-0}

focused() {
    [[ $term -gt 0 && "$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')" == "$term" ]]
}

island() {
    qs -c end4-pC ipc call island "$@" >/dev/null 2>&1
}

case $mode in
    start)
        focused || island indeterminate "$id" "$title" "$(basename "$PWD")" terminal
        ;;
    finish)
        code=$5 seconds=$6 cwd=$7 cmd=$8
        if focused; then
            island remove "$id"
            exit 0
        fi
        if (( seconds >= 3600 )); then took="$((seconds / 3600))h$((seconds % 3600 / 60))min"
        elif (( seconds >= 60 )); then took="$((seconds / 60))min $((seconds % 60))s"
        else took="${seconds}s"
        fi
        sub="$(basename "$cwd") · $took" ok=true log=""
        if (( code == 130 )); then
            sub="$sub · interrompido"
            ok=false
        elif (( code != 0 )); then
            sub="$sub · erro $code"
            ok=false
            if [[ $comm == foot ]]; then
                out="/tmp/quickshell/island/cmdout-$term.log"
                rm -f "$out"
                sleep 0.4
                hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"CTRL SHIFT SUPER\", key = \"F12\", window = \"pid:$term\" })" >/dev/null 2>&1
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                    [[ -s $out ]] && break
                    sleep 0.1
                done
                if [[ -s $out ]]; then
                    log="/tmp/quickshell/island/$id.log"
                    mv "$out" "$log"
                fi
            fi
        fi
        island command "$id" "$title" "$sub" "$ok" "$cwd" "$cmd" "$term" "$log"

        if [[ $ok == true && $cmd == git*push* ]]; then
            setsid "$(dirname "$0")/ci-watch.sh" "$cwd" >/dev/null 2>&1 < /dev/null &
        fi
        ;;
esac
