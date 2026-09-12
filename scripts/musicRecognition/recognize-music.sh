#!/bin/bash

INTERVAL=2
TOTAL_DURATION=30
SOURCE_TYPE="monitor"  # monitor | input
FIFO=$(mktemp -u /tmp/songrec_out_XXXXXX)

while getopts "i:t:s:" opt; do
  case $opt in
    i) INTERVAL=$OPTARG ;;
    t) TOTAL_DURATION=$OPTARG ;;
    s) SOURCE_TYPE=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if ! command -v songrec >/dev/null 2>&1; then
    exit 1
fi

if [ "$SOURCE_TYPE" = "monitor" ]; then
    AUDIO_DEVICE=$(pactl info | grep "Default Sink:" | awk '{print $3}').monitor
elif [ "$SOURCE_TYPE" = "input" ]; then
    AUDIO_DEVICE=$(pactl info | grep "Default Source:" | awk '{print $3}' || true)
else
    echo "Invalid source type"
    exit 1
fi

if [ -z "$AUDIO_DEVICE" ] || ! pactl list short sources | grep -Fq "$AUDIO_DEVICE"; then
    # Fallback to the first available source if default monitor/source check fails
    AUDIO_DEVICE=$(pactl list short sources | head -n 1 | awk '{print $2}')
    if [ -z "$AUDIO_DEVICE" ]; then
        exit 1
    fi
fi

mkfifo "$FIFO"

cleanup() {
    kill "$SONGREC_PID" 2>/dev/null || true
    wait "$SONGREC_PID" 2>/dev/null
    rm -f "$FIFO"
}
trap cleanup EXIT

songrec listen --audio-device "$AUDIO_DEVICE" --json --disable-mpris > "$FIFO" &
SONGREC_PID=$!

( sleep "$TOTAL_DURATION" && kill "$SONGREC_PID" 2>/dev/null ) &

while IFS= read -r line; do
    if echo "$line" | grep -q '"matches" *: *\['; then
        if echo "$line" | grep -q '"matches" *: *\[\]'; then
            continue
        fi
        echo "$line"
        exit 0
    fi
done < "$FIFO"

exit 0