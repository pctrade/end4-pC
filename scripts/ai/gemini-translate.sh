#!/usr/bin/env bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <target_locale> [model]"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/../lib/config.sh"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_CONFIG_DIR="$XDG_CONFIG_HOME/illogical-impulse"
SHELL_CONFIG_FILE="${SHELL_CONFIG_DIR}/config.json"
TRANSLATIONS_DIR="${SCRIPT_DIR}/../../translations"
TRANSLATIONS_TARGET_DIR="${SHELL_CONFIG_DIR}/translations"
SOURCE_LOCALE="en_US"
NOTIFICATION_APP_NAME="Shell"
TARGET_LOCALE="$1"
MODEL="${2:-${GEMINI_MODEL:-gemini-2.5-flash}}"

# Update the source keys for translation
"${TRANSLATIONS_DIR}/tools/manage-translations.sh" update -l "$SOURCE_LOCALE" --yes
mkdir -p "$TRANSLATIONS_TARGET_DIR"

fail() {
    notify-send "Translation failed" "$1" -a "$NOTIFICATION_APP_NAME" -u critical
    echo "$1" >&2
    exit 1
}

API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.gemini // empty')
[[ -z "$API_KEY" ]] && fail "No Gemini API key found. Add it in Settings > Services > AI, then try again."

OUTPUT_FILE="${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json"
BUNDLED_FILE="${TRANSLATIONS_DIR}/${TARGET_LOCALE}.json"
CHUNK_SIZE=120

# Start from what is already translated, only ask Gemini for the missing keys
existing='{}'
[[ -f "$BUNDLED_FILE" ]] && existing=$(jq -c '.' "$BUNDLED_FILE")
[[ -f "$OUTPUT_FILE" ]] && existing=$(jq -c -s '.[0] * .[1]' <(echo "$existing") <(jq -c 'if type == "object" then . else {} end' "$OUTPUT_FILE" 2>/dev/null || echo '{}'))
missing=$(jq -c --argjson existing "$existing" 'with_entries(select(.key as $k | $existing | has($k) | not))' "${TRANSLATIONS_DIR}/en_US.json")
total=$(echo "$missing" | jq 'length')

if [[ "$total" -eq 0 ]]; then
    notify-send "Translation" "${TARGET_LOCALE} is already complete" -a "$NOTIFICATION_APP_NAME"
    exit 0
fi

notify-send "Translation started" "Translating $total texts to ${TARGET_LOCALE}. It can take a few minutes, you'll be notified when it's done." -a "$NOTIFICATION_APP_NAME"

instruction='You are to translate the user interface of a **desktop shell**. Given a JSON object of key-value pairs, return a JSON with the same structure, with keys unchanged and values translated to '"$TARGET_LOCALE"'. Be as **concise** as possible to save screen space, and make sure terminology is relevant (e.g. "discharging" refers to the battery status). Keep placeholders such as %1 and line breaks (\n) exactly as they are.'

result='{}'
chunk_count=$(( (total + CHUNK_SIZE - 1) / CHUNK_SIZE ))
for ((chunk = 0; chunk < chunk_count; chunk++)); do
    content=$(echo "$missing" | jq --argjson start $((chunk * CHUNK_SIZE)) --argjson size "$CHUNK_SIZE" 'to_entries | .[$start:$start+$size] | from_entries')
    prompt=$(jq -n --arg prompt_text "$instruction" --arg content "$content" '$prompt_text + "\n```\n" + $content + "\n```\n"')
    payload=$(jq -n --arg prompt "$prompt" --arg model "$MODEL" '{
        contents: [{ parts: [ {text: $prompt} ] }],
        generationConfig: { temperature: 0, responseMimeType: "application/json" }
    }')

    response=$(curl -sS --max-time 180 "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
        -H "x-goog-api-key: $API_KEY" -H 'Content-Type: application/json' -X POST -d "$payload" 2>&1)
    text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
    if [[ -z "$text" ]]; then
        reason=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        fail "Gemini returned no translation (part $((chunk + 1))/$chunk_count). ${reason:-$(echo "$response" | head -c 200)}"
    fi
    echo "$text" | jq -e 'type == "object"' >/dev/null 2>&1 || fail "Gemini returned invalid JSON (part $((chunk + 1))/$chunk_count)."
    result=$(jq -c -s '.[0] * .[1]' <(echo "$result") <(echo "$text"))
done

mkdir -p "$TRANSLATIONS_TARGET_DIR"
jq -S -s '.[0] * .[1]' <(echo "$existing") <(echo "$result") > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
config_json_update "$SHELL_CONFIG_FILE" --arg locale "$TARGET_LOCALE" '.language.ui = $locale'
notify-send "Translation complete" "Enjoy! In case you wanna refine it, the file is in ${OUTPUT_FILE}" -a "$NOTIFICATION_APP_NAME"
