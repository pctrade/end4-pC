#!/usr/bin/env bash
set -u

source "$(dirname "$(readlink -f "$0")")/preset_gh_lib.sh"

NAME="${1:-}"
FOLDER="$HOME/.cache/quickshell/presets_share/$NAME"

[ -n "$NAME" ] || die 12 "missing preset name"
[ -f "$FOLDER/$NAME.json" ] || die 12 "no prepared folder for $NAME"
require_gh
read_account
open_workspace

branch="preset/$NAME-$(date +%s)"
git checkout -q -b "$branch" || die 12 "could not create a branch"
rm -rf "presets/$NAME"
mkdir -p "presets/$NAME"
cp -a "$FOLDER"/. "presets/$NAME"/

meta="presets/$NAME/meta.json"
[ -f "$meta" ] || echo '{}' > "$meta"
jq --arg author "$login" '.author = $author' "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta" \
    || die 12 "could not write the author"

git add -A presets
if git diff --cached --quiet; then
    die 13 "nothing changed compared with the published preset"
fi

commit_and_open_pr "Add preset $NAME" "Preset: $NAME" "Shared from the shell by @$login."
