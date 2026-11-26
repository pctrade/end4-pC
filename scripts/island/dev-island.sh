#!/usr/bin/env bash
# Dynamic Island helper for local dev servers. Framework-agnostic: only generic patterns (localhost URL, error/ready words).
# Usage: npm run dev 2>&1 | ~/.config/quickshell/end4-pC/scripts/island/dev-island.sh myapp "My App"
# First stdin line = "building"; a localhost URL = "ready" (the port is then polled to keep the activity alive);
# an error keyword before any URL = "error". Removed when the command exits or the port stops answering.
command -v qs >/dev/null 2>&1 || { cat; exit 0; }

id=$1
title=${2:-$1}
[[ -n $id ]] || { echo "usage: dev-island.sh <id> [title]" >&2; cat; exit 1; }

island() {
    qs -c end4-pC ipc call island dev "$id" "$title" "$2" "$1" "${3:-}" >/dev/null 2>&1
}

remove() {
    qs -c end4-pC ipc call island remove "$id" >/dev/null 2>&1
}

ready=false
poll_pid=""

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
