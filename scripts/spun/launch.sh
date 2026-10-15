#!/usr/bin/env bash
set -euo pipefail

# Use an installed binary directly; opening the widget must never trigger a build.
spun_locate=false
if [[ "${1:-}" == "--locate" ]]; then
    spun_locate=true
    shift
fi

spun_run() {
    if "$spun_locate"; then
        printf '%s\n' "$1"
        exit 0
    fi
    exec "$@"
}

if command -v spun >/dev/null 2>&1; then
    spun_run "$(command -v spun)" "$@"
fi

for spun_binary in \
    "${SPUN_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/spun}/build/spun" \
    "$HOME/Spun/build/spun"; do
    if [[ -x "$spun_binary" ]]; then
        spun_run "$spun_binary" "$@"
    fi
done

echo "Spun was not found. Install it in ~/Spun or set SPUN_HOME to its source directory." >&2
exit 127
