#!/usr/bin/env bash
# Claude Code hook -> Dynamic Island (Quickshell end4-pC).
# Registered as an async hook for session, prompt, tool, permission, notification, stop and compaction
# events in ~/.claude/settings.json. Never prints and never blocks Claude Code.
input=$(cat)
command -v qs >/dev/null 2>&1 || exit 0

IFS=$'\x1f' read -r event sid cwd agent tool < <(jq -r '[.hook_event_name // "", .session_id // "", .cwd // "", .agent_id // "", .tool_name // ""] | map(tostring | gsub("[\n\u001f]"; " ")) | join("\u001f")' <<< "$input" 2>/dev/null)
[ -n "$sid" ] || exit 0
[ -n "$agent" ] && exit 0

term=0
cache="$HOME/.cache/claude-island/term-$sid"
if [[ $event == SessionEnd ]]; then
    rm -f "$cache"
elif [[ -s $cache ]]; then
    term=$(<"$cache")
else
    pid=$PPID
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
        comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
        case "$comm" in
            foot|footclient|kitty|alacritty|wezterm-gui|ghostty|konsole|gnome-terminal-|xterm) term=$pid; break ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -n $pid && $pid -gt 1 ]] || break
    done
    mkdir -p "${cache%/*}" && echo "$term" > "$cache"
fi

detail=$(jq -r '
  def base: split("/") | last;
  def short: tostring | gsub("\\s+"; " ") | .[0:80];
  if (.hook_event_name | IN("PreToolUse", "PostToolUse", "PermissionRequest")) then
    (.tool_input // {}) as $i
    | if .tool_name == "AskUserQuestion" then
        ($i.questions // []) as $q
        | "AskUserQuestion\t" + (($q[0].question // "") | short) + "\t"
          + (if ($q | length) == 1 and (($q[0].multiSelect // false) | not) then ([$q[0].options[]?.label] | join("")) else "" end)
      else
        .tool_name + "\t" + (
          if .tool_name == "Bash" then ($i.description // $i.command // "")
          elif ($i.file_path // $i.notebook_path) then (($i.file_path // $i.notebook_path) | base)
          elif $i.pattern then $i.pattern
          elif $i.url then ($i.url | sub("^https?://"; "") | split("/")[0])
          elif $i.query then $i.query
          elif $i.description then $i.description
          else "" end | short)
      end
  elif .hook_event_name == "Notification" then (.notification_type // "") + "\t" + ((.message // "") | short)
  elif .hook_event_name == "StopFailure" then (.error_type // "") + "\t" + ((.error_message // "") | short)
  elif .hook_event_name == "Stop" then
    (.last_assistant_message // "")
    | gsub("```[\\s\\S]*?```"; " ")
    | gsub("(^|\\n)#+[^\\n]*"; " ")
    | gsub("\\[(?<t>[^\\]]*)\\]\\([^)]*\\)"; "\(.t)")
    | gsub("[#*_`>|]"; "")
    | gsub("\\s+"; " ")
    | ltrimstr(" ")
    | (capture("^(?<s>.{8,110}?[.!?])(\\s|$)").s // .[0:100])
  else "" end' <<< "$input" 2>/dev/null)

if [[ $event == Stop && -n $cwd ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    stat=$(git -C "$cwd" diff --shortstat HEAD 2>/dev/null)
    if [[ -n $stat ]]; then
        files=$(grep -oE '[0-9]+ files? changed' <<< "$stat" | grep -oE '^[0-9]+')
        plus=$(grep -oE '[0-9]+ insertions?' <<< "$stat" | grep -oE '^[0-9]+')
        minus=$(grep -oE '[0-9]+ deletions?' <<< "$stat" | grep -oE '^[0-9]+')
        detail+=$'\x1e'"${plus:-0},${minus:-0},${files:-0}"
    fi
fi

qs -c end4-pC ipc call claude hook "$event" "$sid" "$cwd" "$detail" "$term" >/dev/null 2>&1 &
exit 0
