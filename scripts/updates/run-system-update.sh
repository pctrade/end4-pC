#!/usr/bin/env bash
# Runs the distro update command passed as $1 inside a terminal, then posts a
# notification summarizing what changed (parsed from the system's package logs
# when they're available). Meant to be launched from the shell's "Update now"
# notification action via `kitty -e bash run-system-update.sh <cmd>`.

set -u

CMD="${*:-}"
if [[ -z "$CMD" ]]; then
    echo "usage: $0 <update command>" >&2
    exit 1
fi

. /etc/os-release 2>/dev/null || true

printf '%s\n' "Running update: $CMD"
echo "--------------------------------------------------"
# Run exactly ONCE, streaming output to the user and teeing it for a summary.
set -o pipefail
bash -ic "$CMD" 2>&1 | tee /dev/null
status=$?
echo "--------------------------------------------------"

# ---- What's new summary (best effort, per distro) ----
summary=""
today="$(date +%F)"

if [[ -r /var/log/pacman.log ]]; then
    # Arch / CachyOS lines look like: [2026-10-21T22:11+02:00] [ALPM] upgraded kitty (0.42 -> 0.43)
    summary=$(grep -F "$today" /var/log/pacman.log 2>/dev/null \
        | grep -E '\[ALPM\] (upgraded|installed) ' \
        | sed -E 's/^.*\] (upgraded|installed) ([^ ]+)\(?.*$/\1 \2/' \
        | sed -E 's/ upgraded \(/ → /' \
        | tail -n 12)
elif [[ -r /var/log/apt/history.log ]]; then
    # Debian/Ubuntu: Show Upgrade: and Install: lines of today's history entries
    summary=$(grep -B0 -A0 "$today" /var/log/apt/history.log 2>/dev/null \
        | grep -E '^(Upgrade|Install): ' \
        | sed -E 's/Install: //; s/Upgrade: //' \
        | cut -d, -f1-12 | tail -n 12)
elif [[ -r /var/log/dnf.log ]]; then
    summary=$(grep -F "$today" /var/log/dnf.log 2>/dev/null | grep -iE 'upgrade' | tail -n 8)
elif [[ -r /var/log/zypper.log ]]; then
    summary=$(grep -F "$today" /var/log/zypper.log 2>/dev/null | tail -n 8)
fi

if [[ $status -eq 0 ]]; then
    title="System update finished"
    body="Update command completed successfully."
else
    title="System update had problems"
    body="Update command exited with status $status."
fi

body_curated="$(sed -E 's/^/• /' <<< "$summary" 2>/dev/null)"
if [[ -n "$summary" ]]; then
    body="$body
What changed:
$body_curated
(see /var/log for details)"
fi

notify-send -a "Shell" -t 10000 "$title" "$body" 2>/dev/null

echo "Done (exit $status). Press Enter to close."
read -r

exit "$status"
