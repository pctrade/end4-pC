#!/usr/bin/env bash
# Update the end4-pC checkout in place on the personal "perso" branch:
# merge pctrade's main into it, keep the fork in sync, restart the shell.
#
# Nothing is ever deleted. Uncommitted changes are stashed and put back when
# the update did not touch the same files. A merge that conflicts is aborted,
# leaving the branch exactly as it was.
#
# Run it through scripts/perso/end4-update (or ~/.local/bin/end4-update),
# which executes a temporary copy: the merge may rewrite this very file.

set -uo pipefail

# The launcher runs a temporary copy; bash keeps reading it once unlinked
[ -n "${END4_UPDATE_TMP:-}" ] && rm -f "$END4_UPDATE_TMP"

REPO="${END4_REPO:-$HOME/.config/quickshell/end4-pC}"
BRANCH="${END4_BRANCH:-perso}"
UPSTREAM="${END4_UPSTREAM:-origin}" # pctrade/end4-pC
FORK="${END4_FORK:-fork}"           # SDcold/end4-pC
QS_CONFIG="${qsConfig:-end4-pC}"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*"; exit 1; }

restart_shell() {
    bold "Restarting the shell"
    for _ in 1 2 3 4 5; do
        qs kill -c "$QS_CONFIG" --newest >/dev/null 2>&1 || break
    done
    sleep 0.5
    setsid qs -c "$QS_CONFIG" >/dev/null 2>&1 </dev/null &
    disown
}

cd "$REPO" 2>/dev/null || fail "$REPO does not exist."
git rev-parse --git-dir >/dev/null 2>&1 || fail "$REPO is not a git checkout."

current="$(git rev-parse --abbrev-ref HEAD)"
[ "$current" = "$BRANCH" ] || fail "The checkout is on '$current', not '$BRANCH'. Nothing was changed.
Switch back with: git -C \"$REPO\" switch $BRANCH"

if [ -n "$(git status --porcelain)" ]; then
    bold "Stashing uncommitted changes"
    git stash push --include-untracked --message "end4-update $(date +%Y-%m-%d_%H-%M-%S)" || fail "Could not stash local changes. Nothing was changed."
    stashed=1
else
    stashed=""
fi

put_back_stash() {
    [ -n "$stashed" ] || return 0
    local touched stash_files
    touched="$(git diff --name-only "$before" HEAD)"
    stash_files="$( { git stash show --name-only 'stash@{0}'; git ls-tree -r --name-only 'stash@{0}^3' 2>/dev/null; } | sort -u)"
    if [ -n "$touched" ] && [ -n "$(comm -12 <(sort -u <<<"$touched") <(sort -u <<<"$stash_files"))" ]; then
        bold "Your uncommitted changes stay stashed"
        echo "The update modified some of the same files. Restore them by hand with:"
        echo "    git -C \"$REPO\" stash pop"
    elif git stash pop --quiet; then
        bold "Uncommitted changes restored"
    else
        bold "Your uncommitted changes stay stashed"
        echo "    git -C \"$REPO\" stash pop"
    fi
}

before="$(git rev-parse HEAD)"

bold "Fetching $UPSTREAM and $FORK"
git fetch --prune "$UPSTREAM" || { put_back_stash; fail "Could not fetch $UPSTREAM."; }
git fetch --prune "$FORK" || { put_back_stash; fail "Could not fetch $FORK."; }

# Changes pushed to the fork's perso from another machine
if git rev-parse --verify --quiet "$FORK/$BRANCH" >/dev/null; then
    if ! git merge --ff-only --quiet "$FORK/$BRANCH" 2>/dev/null \
        && ! git merge-base --is-ancestor "$FORK/$BRANCH" HEAD; then
        put_back_stash
        fail "Local $BRANCH and $FORK/$BRANCH have diverged. Nothing was merged.
Merge them by hand: git -C \"$REPO\" merge $FORK/$BRANCH"
    fi
fi

bold "Merging $UPSTREAM/main into $BRANCH"
if ! git merge --no-edit "$UPSTREAM/main"; then
    git merge --abort
    git reset --quiet --hard "$before"
    put_back_stash
    fail "The merge conflicts and was aborted: $BRANCH is unchanged.
Resolve it by hand with: git -C \"$REPO\" merge $UPSTREAM/main"
fi

bold "Updating the fork"
git push "$FORK" "refs/remotes/$UPSTREAM/main:refs/heads/main" \
    || echo "The fork's main could not be fast-forwarded, leaving it alone."
git push "$FORK" "$BRANCH" || echo "Could not push $BRANCH to $FORK, try again later."
if ! git worktree list --porcelain | grep -qx 'branch refs/heads/main'; then
    git fetch --quiet "$UPSTREAM" main:main 2>/dev/null || true
fi

put_back_stash

if [ "$(git rev-parse HEAD)" = "$before" ]; then
    bold "Already up to date"
else
    bold "Updated $(git rev-parse --short "$before") -> $(git rev-parse --short HEAD)"
    git log --oneline --no-merges "$before..HEAD" | head -20
fi

restart_shell
