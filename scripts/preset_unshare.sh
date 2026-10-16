#!/usr/bin/env bash
set -u

source "$(dirname "$(readlink -f "$0")")/preset_gh_lib.sh"

MODE="${1:-}"
NAME="${2:-}"

[ -n "$NAME" ] || die 12 "missing preset name"
require_gh
read_account

case "$MODE" in
    owned)
        author=""
        is_published "$NAME" && author=$(preset_owner "$NAME")
        if [ -z "$author" ]; then
            echo "none"
        elif [ "${author,,}" = "${login,,}" ]; then
            echo "yes"
        else
            echo "no"
        fi
        ;;
    remove)
        open_workspace
        [ -d "presets/$NAME" ] || die 14 "\"$NAME\" is not in the gallery"
        author=$(jq -r '.author // empty' "presets/$NAME/meta.json" 2>/dev/null)
        [ -n "$author" ] || author=$(first_author "$NAME")
        [ -n "$author" ] && [ "${author,,}" = "${login,,}" ] || die 15 "\"$NAME\" belongs to someone else"
        branch="preset/remove-$NAME-$(date +%s)"
        git checkout -q -b "$branch" || die 12 "could not create a branch"
        git rm -rq "presets/$NAME" || die 12 "could not remove the folder"
        commit_and_open_pr "Remove preset $NAME" "Remove preset: $NAME" "Removed from the gallery by its author, @$login."
        ;;
    *)
        die 12 "unknown mode"
        ;;
esac
