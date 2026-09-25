#!/usr/bin/env bash
# Codex and Gemini (Antigravity CLI) hooks -> Dynamic Island (Quickshell end4-pC). Same flow as claude-island.sh:
#   Codex:        ~/.codex/hooks.json          -> agent-island.sh codex            (event inside the JSON payload)
#   Antigravity:  ~/.gemini/config/hooks.json  -> agent-island.sh gemini <Event>   (event passed as an argument)
# Never blocks the agent: the island is told in the background and the script exits right away.
agent=$1
arg_event=$2
input=$(cat)

# Antigravity reads a decision from stdout; these keep its normal behavior. Codex needs no output.
if [[ $agent == gemini ]]; then
    if [[ $arg_event == Stop ]]; then printf '{"decision":""}\n'; else printf '{}\n'; fi
fi
command -v qs >/dev/null 2>&1 || exit 0
[[ -n $input ]] || input='{}'

# Unit-separated: with tabs, bash's read collapses empty fields
IFS=$'\x1f' read -r event sid cwd sub < <(jq -r '[
    .hook_event_name // .hookEventName // "",
    .session_id // .sessionId // .conversation_id // .conversationId // .thread_id // .threadId // "",
    .cwd // .workspace // .workspaceRoot // .workingDirectory // "",
    .agent_id // .subagent_id // ""
] | map(tostring | gsub("[\n]"; " ")) | join("")' <<< "$input" 2>/dev/null)
event=${arg_event:-$event}
cwd=${cwd:-$PWD}
[[ -n $event ]] || exit 0
# Subagent calls belong to the main session's turn
[[ -n $sub ]] && exit 0

# Latest payload of each event, kept to adjust the parsing if a CLI changes its format
samples="$HOME/.cache/claude-island/samples"
mkdir -p "$samples" && printf '%s' "$input" > "$samples/$agent-$event.json"

# The agent process and the terminal window it runs in, walking up from the hook
agent_pid=0 term=0
pid=$PPID
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    case "$comm" in
        codex|agy|antigravity) [[ $agent_pid == 0 ]] && agent_pid=$pid ;;
        foot|footclient|kitty|alacritty|wezterm-gui|ghostty|konsole|gnome-terminal-|xterm) term=$pid; break ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -n $pid && $pid -gt 1 ]] || break
done
# Without a session id in the payload, the agent process identifies the session
[[ -n $sid ]] || sid="pid-${agent_pid:-$term}"

detail=$(jq -r --arg event "$event" '
  def base: split("/") | last;
  def short: tostring | gsub("\\s+"; " ") | .[0:80];
  (.tool_input // .toolInput // .input // .arguments // {}) as $raw
  | ($raw | if type == "string" then (try fromjson catch {}) else . end) as $i
  | if ($event | IN("PreToolUse", "PostToolUse", "PermissionRequest")) then
      ((.tool_name // .toolName // .tool // "") | tostring) + "\t" + (
        ($i | if type == "object" then (.description // .command // .cmd // .file_path // .path // .pattern // .query // .url // "") else "" end)
        | if type == "array" then join(" ") else . end | tostring
        | if test("^/[^ ]+$") then base else . end | short)
    elif $event == "Stop" then
      (.last_assistant_message // .lastAssistantMessage // .response // .message // "")
      | tostring
      | gsub("```[\\s\\S]*?```"; " ")
      | gsub("(^|\\n)#+[^\\n]*"; " ")
      | gsub("\\[(?<t>[^\\]]*)\\]\\([^)]*\\)"; "\(.t)")
      | gsub("[#*_`>|]"; "")
      | gsub("\\s+"; " ")
      | ltrimstr(" ")
      | (capture("^(?<s>.{8,110}?[.!?])(\\s|$)").s // .[0:100])
    else "" end' <<< "$input" 2>/dev/null)

# Stop: what changed in the repository ("plus,minus,files"), after a record separator
if [[ $event == Stop && -n $cwd ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    stat=$(git -C "$cwd" diff --shortstat HEAD 2>/dev/null)
    if [[ -n $stat ]]; then
        files=$(grep -oE '[0-9]+ files? changed' <<< "$stat" | grep -oE '^[0-9]+')
        plus=$(grep -oE '[0-9]+ insertions?' <<< "$stat" | grep -oE '^[0-9]+')
        minus=$(grep -oE '[0-9]+ deletions?' <<< "$stat" | grep -oE '^[0-9]+')
        detail+=$'\x1e'"${plus:-0},${minus:-0},${files:-0}"
    fi
fi

qs -c end4-pC ipc call claude agent "$agent" "$event" "$sid" "$cwd" "$detail" "$term" >/dev/null 2>&1 &

# Codex: plan usage and context size from the session's rollout file
if [[ $agent == codex && ( $event == Stop || $event == UserPromptSubmit || $event == SessionStart ) ]]; then
    (
        rollout=$(ls -t "$HOME"/.codex/sessions/*/*/*/rollout-*"$sid"*.jsonl 2>/dev/null | head -1)
        [[ -n $rollout ]] || exit 0
        token=$(tail -c 800000 "$rollout" | grep '"type":"token_count"' | tail -1 | jq -c '.payload' 2>/dev/null)
        [[ -n $token ]] || exit 0
        IFS=$'\t' read -r five five_reset week week_reset ctx < <(jq -r '[
            (.rate_limits.primary.used_percent // -1), (.rate_limits.primary.resets_at // 0),
            (.rate_limits.secondary.used_percent // -1), (.rate_limits.secondary.resets_at // 0),
            (if (.info.model_context_window // 0) > 0 and .info.last_token_usage
             then ((.info.last_token_usage.input_tokens // .info.last_token_usage.total_tokens // 0) * 100 / .info.model_context_window | round)
             else -1 end)
        ] | @tsv' <<< "$token" 2>/dev/null)
        model=$(tail -c 800000 "$rollout" | grep '"type":"turn_context"' | tail -1 | jq -r '.payload.model // empty' 2>/dev/null)
        [[ ${five:--1} != -1 ]] && qs -c end4-pC ipc call claude limits codex "$five" "$five_reset" "$week" "$week_reset" >/dev/null 2>&1
        [[ ${ctx:--1} != -1 ]] && qs -c end4-pC ipc call claude context codex "$sid" "$ctx" "${model:-}" >/dev/null 2>&1
    ) >/dev/null 2>&1 &
fi
exit 0
