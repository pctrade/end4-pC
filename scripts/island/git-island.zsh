# Dynamic Island: network git commands (push/pull/fetch/clone) show up as live activities.
# Sourced from ~/.zshrc. Every other git command runs untouched.

git() {
    case "$1" in
        push|pull|fetch|clone) ;;
        *) command git "$@"; return ;;
    esac
    if ! command -v qs >/dev/null 2>&1 || [[ ! -o interactive ]]; then
        command git "$@"
        return
    fi

    local id="git-$$-$RANDOM" icon title repo
    repo=$(basename "$(command git rev-parse --show-toplevel 2>/dev/null || pwd)")
    case "$1" in
        push)  icon=upload;   title="git push" ;;
        pull)  icon=download; title="git pull" ;;
        fetch) icon=sync;     title="git fetch" ;;
        clone) icon=download; title="git clone"; repo="${${@[-1]##*/}%.git}" ;;
    esac

    # Synchronous so a very fast command can't finish before its activity exists
    qs -c end4-pC ipc call island indeterminate "$id" "$title" "$repo" "$icon" >/dev/null 2>&1
    local start=$SECONDS
    command git "$@"
    local code=$?
    local took=$(( SECONDS - start ))
    if (( code == 0 )); then
        qs -c end4-pC ipc call island done "$id" "$repo · ${took}s" >/dev/null 2>&1 &!
    else
        qs -c end4-pC ipc call island fail "$id" "$repo · erro $code" >/dev/null 2>&1 &!
    fi
    return $code
}
