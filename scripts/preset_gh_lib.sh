UPSTREAM="${PRESET_SHARE_REPO:-pctrade/end4-pCpresets}"
BASE_BRANCH="main"

die() { echo "$2" >&2; exit "$1"; }

require_gh() {
    command -v gh >/dev/null 2>&1 || die 10 "gh is not installed"
    command -v git >/dev/null 2>&1 || die 12 "git is not installed"
    gh auth status >/dev/null 2>&1 || die 11 "gh is not signed in"
}

read_account() {
    login=$(gh api user --jq .login) || die 12 "could not read the GitHub account"
    user_id=$(gh api user --jq .id) || die 12 "could not read the GitHub account"
}

gitgh() { git -c credential.helper= -c credential.helper='!gh auth git-credential' "$@"; }

is_published() {
    gh api "repos/$UPSTREAM/contents/presets/$1?ref=$BASE_BRANCH" >/dev/null 2>&1
}

first_author() {
    local raw
    raw=$(gh api --paginate "repos/$UPSTREAM/commits?sha=$BASE_BRANCH&path=presets/$1&per_page=100" \
        --jq '.[].author.login' 2>/dev/null) || return 1
    printf '%s\n' "$raw" | grep -v '^null$' | grep -v '^$' | tail -n 1
}

preset_owner() {
    local encoded owner
    encoded=$(gh api "repos/$UPSTREAM/contents/presets/$1/meta.json?ref=$BASE_BRANCH" --jq .content 2>/dev/null) || encoded=""
    owner=$(printf '%s' "$encoded" | base64 -d 2>/dev/null | jq -r '.author // empty' 2>/dev/null)
    if [ -n "$owner" ]; then
        echo "$owner"
        return
    fi
    first_author "$1"
}

open_workspace() {
    fork_repo="$login/${UPSTREAM#*/}"
    if [ "${login,,}" != "${UPSTREAM%%/*}" ]; then
        gh repo fork "$UPSTREAM" --clone=false >/dev/null 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            gh api "repos/$fork_repo" >/dev/null 2>&1 && break
            sleep 2
        done
        gh repo sync "$fork_repo" --branch "$BASE_BRANCH" >/dev/null 2>&1 || true
    else
        fork_repo="$UPSTREAM"
    fi

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    gitgh clone --depth 1 --branch "$BASE_BRANCH" "https://github.com/$fork_repo.git" "$work/repo" >/dev/null 2>&1 \
        || die 12 "could not clone $fork_repo"
    cd "$work/repo" || die 12 "clone failed"
}

commit_and_open_pr() {
    local message="$1" title="$2" body="$3" url
    git -c "user.name=$login" -c "user.email=$user_id+$login@users.noreply.github.com" \
        commit -q -m "$message" || die 12 "could not commit"
    gitgh push -q origin "$branch" >/dev/null 2>&1 || die 12 "could not push to $fork_repo"
    url=$(gh pr create --repo "$UPSTREAM" --base "$BASE_BRANCH" --head "$login:$branch" \
        --title "$title" --body "$body" 2>&1 | tail -n 1)
    case "$url" in
        https://*) echo "$url" ;;
        *) die 12 "$url" ;;
    esac
}
