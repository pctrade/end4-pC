#!/usr/bin/env bash
# Hold-to-talk for the island: records while you hold the shortcut, transcribes when you let go, and leaves the
# text on the clipboard. Bind it in Hyprland with press and release:
#   bindd = SUPER, V, Nota de voz, exec, ~/.config/quickshell/end4-pC/scripts/island/voice-note.sh start
#   bindrd = SUPER, V, Nota de voz, exec, ~/.config/quickshell/end4-pC/scripts/island/voice-note.sh stop
# "toggle" works too, for a single binding.

set -uo pipefail

dir="${XDG_RUNTIME_DIR:-/tmp}/island-voice"
mkdir -p "$dir"
pidfile="$dir/recorder.pid"
wav="$dir/note.wav"
script_dir=$(dirname "$(readlink -f "$0")")

island() {
    qs -c end4-pC ipc call island "$@" >/dev/null 2>&1
}

recording() {
    [[ -f $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

start() {
    recording && exit 0
    rm -f "$wav"
    parecord --channels=1 --rate=16000 --file-format=wav "$wav" &
    echo $! > "$pidfile"
    island indeterminate voice-note "Gravando nota de voz" "Solte para transcrever" mic
}

stop() {
    recording || exit 0
    kill -INT "$(cat "$pidfile")" 2>/dev/null
    rm -f "$pidfile"
    sleep 0.3

    # Anything under a second is a slip of the finger, not a note
    size=$(stat -c %s "$wav" 2>/dev/null || echo 0)
    if (( size < 32000 )); then
        island remove voice-note
        exit 0
    fi

    island indeterminate voice-note "Transcrevendo…" "$(( size / 32000 ))s de áudio" graphic_eq
    text=$("$script_dir/voice_note.py" "$wav" "${ISLAND_VOICE_LANG:-pt}" 2>/dev/null)

    if [[ -z $text ]]; then
        island finish voice-note "Não entendi o áudio" "Tente de novo" mic_off false
        exit 0
    fi

    printf '%s' "$text" | wl-copy
    island finish voice-note "Nota de voz copiada" "$text" content_paste true
}

case ${1:-toggle} in
    start) start ;;
    stop)  stop ;;
    toggle)
        if recording; then stop; else start; fi
        ;;
esac
