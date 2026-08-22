#!/usr/bin/env bash
# presets.sh - manage shell config presets | just for fun I could have done it from quickshell directly =P
# Usage:
#   presets.sh --save <name>
#   presets.sh --remove <name>
#   presets.sh --apply <name>
#   presets.sh --rename <name> <new_name> [description]

CONFIG_DIR="$HOME/.config/illogical-impulse"
CONFIG_FILE="$CONFIG_DIR/config.json"
PRESETS_DIR="$CONFIG_DIR/presets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHWALL="$SCRIPT_DIR/colors/switchwall.sh"

mkdir -p "$PRESETS_DIR"

action="$1"
name="$2"

if [ -z "$name" ]; then
    echo "Error: missing preset name" >&2
    exit 1
fi

case "$action" in
    --save)
        description="$3"
        jq 'del(._presetMeta)' "$CONFIG_FILE" > "$PRESETS_DIR/${name}.json"
        if [ -n "$description" ]; then
            jq --arg desc "$description" '._presetMeta = {"description": $desc}' \
                "$PRESETS_DIR/${name}.json" > "$PRESETS_DIR/${name}.json.tmp" \
                && mv "$PRESETS_DIR/${name}.json.tmp" "$PRESETS_DIR/${name}.json"
        fi
        ;;
    --remove)
        rm -f "$PRESETS_DIR/${name}.json"
        ;;
    --apply)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        jq -s '.[0] * .[1] | del(._presetMeta)' "$CONFIG_FILE" "$preset_file" \
            > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        "$SWITCHWALL" --noswitch
        ;;
    --rename|--edit)
        new_name="$3"
        description="$4"
        if [ -z "$new_name" ]; then
            echo "Error: missing new preset name" >&2
            exit 1
        fi
        old_file="$PRESETS_DIR/${name}.json"
        new_file="$PRESETS_DIR/${new_name}.json"
        if [ ! -f "$old_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        if [ $# -ge 4 ]; then
            if [ -n "$description" ]; then
                jq --arg desc "$description" '._presetMeta = {"description": $desc}' "$old_file" > "$new_file.tmp" \
                    && mv "$new_file.tmp" "$new_file"
            else
                jq 'del(._presetMeta)' "$old_file" > "$new_file.tmp" \
                    && mv "$new_file.tmp" "$new_file"
            fi
        else
            cp "$old_file" "$new_file"
        fi
        if [ "$name" != "$new_name" ] && [ -f "$new_file" ]; then
            rm -f "$old_file"
        fi
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac