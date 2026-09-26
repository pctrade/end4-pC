#!/usr/bin/env bash
# Sends a reply to a web chat (WhatsApp Web in the browser) from the island.
#
# The island has already invoked the notification's own "default" action — the same thing clicking the
# notification does — so the web app opens *that* conversation and the browser comes to the front. This waits
# for the focused window to really be that chat app, then types the text (never through the clipboard) and
# presses Enter. If the chat never comes up, nothing is typed anywhere: the reply is left on the clipboard and
# the script exits 1 so the island can say so.
#
# Usage: reply-send.sh <text> <window title hint, e.g. "WhatsApp">

set -uo pipefail

text=${1:-}
hint=${2:-WhatsApp}
[[ -z $text ]] && exit 0

focused_is_chat() {
    hyprctl activewindow -j 2>/dev/null | HINT="$hint" python3 -c '
import json, os, sys
try:
    w = json.load(sys.stdin)
except Exception:
    sys.exit(1)
hint = os.environ["HINT"].lower()
sys.exit(0 if hint in str(w.get("title", "")).lower() else 1)
'
}

for _ in $(seq 1 20); do
    focused_is_chat && break
    sleep 0.1
done

if ! focused_is_chat; then
    printf '%s' "$text" | wl-copy
    exit 1
fi

sleep 0.5
focused_is_chat || { printf '%s' "$text" | wl-copy; exit 1; }
wtype -- "$text"
sleep 0.05
wtype -k Return
