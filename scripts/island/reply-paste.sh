#!/usr/bin/env bash
# Puts a reply into its chat. Web apps lack inline notification reply, so this copies the text, focuses the
# app window and pastes. Never presses Enter.
# Usage: reply-paste.sh <text> <app hints>

set -euo pipefail

text=${1:-}
hints=${2:-}
[[ -z $text ]] && exit 0

printf '%s' "$text" | wl-copy

address=$(hyprctl clients -j | HINTS="$hints" python3 -c '
import json, os, sys

hints = [h for h in os.environ.get("HINTS", "").lower().split() if len(h) > 2]
clients = json.load(sys.stdin)

def score(client):
    haystack = " ".join(str(client.get(key, "")) for key in ("class", "initialClass", "title", "initialTitle")).lower()
    return sum(1 for hint in hints if hint in haystack)

best = max(clients, key=score, default=None)
print(best["address"] if best and score(best) > 0 else "")
')

if [[ -z $address ]]; then
    exit 1
fi

hyprctl dispatch "hl.dsp.focus({ window = \"address:${address}\" })" >/dev/null
sleep 0.25
hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"V\", window = \"address:${address}\" })" >/dev/null
