#!/usr/bin/env bash
# Follows the GitHub workflow run that a push just started, and reports it on the island.
#
# Called in the background right after a successful `git push`. It waits for GitHub to register a run for the
# pushed commit, then polls until the run finishes, so the island says "build passed" or "build failed" without
# anyone opening a browser.
#
# Usage: ci-watch.sh <repo dir>

set -uo pipefail

dir=${1:-$PWD}
cd "$dir" 2>/dev/null || exit 0

command -v gh >/dev/null 2>&1 || exit 0
command -v qs >/dev/null 2>&1 || exit 0
gh auth status >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

sha=$(git rev-parse HEAD 2>/dev/null) || exit 0
short=${sha:0:7}
repo=$(basename "$(git rev-parse --show-toplevel)")
id="ci-${short}"

island() {
    qs -c end4-pC ipc call island "$@" >/dev/null 2>&1
}

run_field() {
    gh run list --commit "$sha" --limit 1 --json "$1" --jq ".[0].$1" 2>/dev/null
}

for _ in $(seq 1 20); do
    status=$(run_field status)
    [[ -n $status ]] && break
    sleep 3
done
[[ -z ${status:-} ]] && exit 0

name=$(run_field name)
island indeterminate "$id" "${name:-CI} · ${repo}" "$short" "cloud_sync"

while [[ $status != "completed" ]]; do
    sleep 10
    status=$(run_field status)
    [[ -z $status ]] && break
done

conclusion=$(run_field conclusion)
url=$(run_field url)

case $conclusion in
    success)
        island finish "$id" "$(printf '%s' "${name:-CI}") passou" "$repo · $short" "check_circle" true
        ;;
    "")
        island remove "$id"
        ;;
    *)
        island finish "$id" "$(printf '%s' "${name:-CI}") falhou" "$repo · $short · $conclusion" "error" false
        [[ -n $url ]] && printf '%s\n' "$url" > "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/last-ci-failure.url"
        ;;
esac
