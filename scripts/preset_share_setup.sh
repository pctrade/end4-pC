#!/usr/bin/env bash
set -u

BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

say() { printf '%s\n' "${BOLD}$*${RESET}"; }
note() { printf '%s\n' "${DIM}$*${RESET}"; }

finish() {
    printf '\n'
    read -rsn1 -p "Press any key to close this window... " _ || true
    printf '\n'
    exit "${1:-0}"
}

confirm() {
    local answer
    read -r -p "$1 [Y/n] " answer || return 1
    case "${answer,,}" in
        ""|y|yes|s|si) return 0 ;;
        *) return 1 ;;
    esac
}

install_gh() {
    local cmd
    if command -v pacman >/dev/null 2>&1; then
        if command -v yay >/dev/null 2>&1; then
            cmd="yay -S --needed github-cli"
        elif command -v paru >/dev/null 2>&1; then
            cmd="paru -S --needed github-cli"
        else
            cmd="sudo pacman -S --needed github-cli"
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        cmd="sudo apt-get install -y gh"
    elif command -v dnf >/dev/null 2>&1; then
        cmd="sudo dnf install -y gh"
    elif command -v zypper >/dev/null 2>&1; then
        cmd="sudo zypper install -y gh"
    else
        say "Could not find a package manager this script knows."
        note "Install the GitHub CLI from https://cli.github.com and press the Upload button again."
        finish 1
    fi

    say "The GitHub CLI (gh) is needed to send presets with one click."
    note "This will run: $cmd"
    confirm "Install it now?" || finish 1
    bash -c "$cmd" || { say "The installation failed."; finish 1; }
    command -v gh >/dev/null 2>&1 || { say "gh is still not available."; finish 1; }
}

command -v git >/dev/null 2>&1 || { say "git is required and is not installed."; finish 1; }
command -v gh >/dev/null 2>&1 || install_gh

if gh auth status >/dev/null 2>&1; then
    say "You are already signed in to GitHub."
    finish 0
fi

say "Sign in to GitHub"
note "A browser window opens with a one-time code. Nothing is typed here and no password is stored by the shell."
gh auth login --hostname github.com --git-protocol https --web || { say "Sign in did not finish."; finish 1; }

gh auth status >/dev/null 2>&1 || finish 1
say "Done. Your preset is being sent now."
sleep 2
exit 0
