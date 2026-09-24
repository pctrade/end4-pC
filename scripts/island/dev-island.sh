#!/usr/bin/env bash
# Dynamic Island helper for local dev servers (seção 26 — Dev Activity). Framework-agnostic: it never
# parses a specific tool's output, only generic patterns (a localhost URL, common error/ready words), so
# it works the same for Next.js, Vite, Django's runserver, or anything else that prints to stdout.
#
# Usage: wrap the dev command's output with it, piped through so you still see everything normally:
#   npm run dev 2>&1 | ~/.config/quickshell/end4-pC/scripts/island/dev-island.sh myapp "My App"
#
# First line of stdin marks "building". A localhost URL anywhere in the output marks "ready" and starts
# polling that port every few seconds to keep the Live Activity alive for as long as the server answers —
# unlike a one-off "done", ready has to persist for however long you leave the server running. A generic
# error/failed keyword before a URL has appeared marks "error". The activity is removed when the wrapped
# command exits or the port stops answering.
command -v qs >/dev/null 2>&1 || { cat; exit 0; }

id=$1
title=${2:-$1}
[[ -n $id ]] || { echo "usage: dev-island.sh <id> [title]" >&2; cat; exit 1; }

# island <state: building|ready|error> <subtitle> [url]
island() {
    qs -c end4-pC ipc call island dev "$id" "$title" "$2" "$1" "${3:-}" >/dev/null 2>&1
}

remove() {
    qs -c end4-pC ipc call island remove "$id" >/dev/null 2>&1
}

ready=false
poll_pid=""

# Keeps "ready" touched so the 30-minute running-state grace window in upsertActivity never runs out on
# a server that's simply been open a while, and clears the activity once the port stops answering
poll_port() {
    local host=$1 port=$2 url=$3
    while :; do
        sleep 6
        if ! (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
            remove
            exit 0
        fi
        exec 3<&- 3>&- 2>/dev/null
        island ready "$url" "$url"
    done
}

cleanup() {
    # EOF on stdin means the wrapped command's own stdout closed — the dev server exited — so the
    # activity always goes away here. The poller is only a backup for a port that dies without the
    # wrapping shell noticing (and its own exit removes it independently, see poll_port above).
    [[ -n $poll_pid ]] && kill "$poll_pid" 2>/dev/null
    remove
}
trap cleanup EXIT

island building "Iniciando…"

while IFS= read -r line; do
    printf '%s\n' "$line"

    if ! $ready && [[ $line =~ https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)(:([0-9]+))?[^[:space:]\"\']* ]]; then
        url="${BASH_REMATCH[0]}"
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[3]:-80}"
        [[ $host == "0.0.0.0" ]] && host=127.0.0.1
        ready=true
        island ready "$url" "$url"
        poll_port "$host" "$port" "$url" &
        poll_pid=$!
        continue
    fi

    if ! $ready && [[ $line =~ [Ee]rror|[Ff]ailed|[Ee]xception ]]; then
        island error "$line"
    fi
done
