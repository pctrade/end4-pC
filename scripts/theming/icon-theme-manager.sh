#!/usr/bin/env bash
# icon-theme-manager.sh - selection, activation and KDE icon override handling.
#
# Usage:
#   icon-theme-manager.sh --sync --apply [--source manual|wallpaper|scheme] [--mode light|dark]
#   icon-theme-manager.sh --sync [--mode ...]
#   icon-theme-manager.sh --post-kde [--mode ...]
#   icon-theme-manager.sh --activate <name> --request-id <id> --selection-id <id>
#   icon-theme-manager.sh --cancel
#   icon-theme-manager.sh --restore-kmyc
#   icon-theme-manager.sh --status [--json]
#
# The manager never writes to the base icon themes and never deletes arbitrary
# directories. Generated themes are named deterministically and validated by
# manifest before use.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

SHELL_CONFIG="${ICON_MANAGER_CONFIG:-$CONFIG_HOME/illogical-impulse/config.json}"
KMYC_CONFIG="${ICON_MANAGER_KMYC_CONFIG:-$CONFIG_HOME/kde-material-you-colors/config.conf}"
ICONS_DIR="${ICON_MANAGER_ICONS_DIR:-$DATA_HOME/icons}"
STATE_DIR="${ICON_MANAGER_STATE_DIR:-$STATE_HOME/quickshell/user/generated/icons}"
SCSS="${ICON_MANAGER_SCSS:-$STATE_HOME/quickshell/user/generated/material_colors.scss}"
APPLY_CMD="${ICON_MANAGER_APPLY_CMD:-$SCRIPT_DIR/../system-appearance.sh}"
ADAPTER_CLI="$SCRIPT_DIR/icon_theme_adapters/cli.py"
WORKER="$SCRIPT_DIR/icon-theme-worker.py"

THEME="Tela"
FOLLOW=true
DYNAMIC=true
PREVENT=true
KEEP=6
LIGHT_OVERRIDE=""
DARK_OVERRIDE=""
ACCENT=""

usage() {
    sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

cfg_raw() {
    [ -f "$SHELL_CONFIG" ] || return 0
    # ``// empty`` would also swallow boolean false, so check presence instead.
    jq -r --arg key "$1" '
        .appearance.icons as $icons
        | if ($icons | type) == "object" and ($icons | has($key)) then $icons[$key]
          else empty end
    ' "$SHELL_CONFIG" 2>/dev/null
}

cfg_bool() {
    local raw
    raw=$(cfg_raw "$1")
    case "${raw,,}" in
        false|0|no|off) printf 'false\n' ;;
        *) printf 'true\n' ;;
    esac
}

json_bool() {
    if [ "$1" = "true" ]; then printf 'true'; else printf 'false'; fi
}

load_config() {
    THEME=$(cfg_raw theme)
    [ -n "$THEME" ] || THEME="Tela"
    FOLLOW=$(cfg_bool followScheme)
    DYNAMIC=$(cfg_bool dynamicColor)
    PREVENT=$(cfg_bool preventBreezeOverride)
    KEEP=$(cfg_raw keepGenerated)
    [[ "$KEEP" =~ ^[0-9]+$ ]] || KEEP=6
    [ "$KEEP" -le 100 ] || KEEP=100
    LIGHT_OVERRIDE=$(cfg_raw lightVariant)
    DARK_OVERRIDE=$(cfg_raw darkVariant)
}

new_id() {
    printf '%s-%04x%04x%04x' "$(date +%s%3N)" "$RANDOM" "$RANDOM" "$RANDOM"
}

manager_lock() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    exec 9>"$STATE_DIR/manager.lock" || return 1
    flock -w 10 9 || return 1
    return 0
}

manager_unlock() {
    flock -u 9 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
}

detect_mode() {
    local scheme=""
    if command -v gsettings >/dev/null 2>&1; then
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    fi
    if [ -z "$scheme" ] && command -v kreadconfig6 >/dev/null 2>&1; then
        scheme=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)
    fi
    case "$scheme" in
        *[Dd]ark*) printf 'dark\n' ;;
        *) printf 'light\n' ;;
    esac
}

current_icon_theme() {
    local value=""
    if command -v kreadconfig6 >/dev/null 2>&1; then
        value=$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || true)
    fi
    if [ -z "$value" ] && command -v gsettings >/dev/null 2>&1; then
        value=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    fi
    printf '%s' "$value" | sed -E 's/-Dynamic-(Light-|Dark-)?[0-9a-f]{6}$//'
}

get_primary() {
    local value=""
    if [ -f "$SCSS" ]; then
        value=$(sed -n 's/^[[:space:]]*\$primary:[[:space:]]*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$SCSS" 2>/dev/null | head -n1)
    fi
    if [ -z "$value" ]; then
        value=$(jq -r '.primary // empty' "$STATE_HOME/quickshell/user/generated/colors.json" 2>/dev/null || true)
    fi
    value=$(printf '%s' "$value" | tr 'A-F' 'a-f')
    if [[ "$value" =~ ^#[0-9a-f]{6}$ ]]; then
        printf '%s\n' "$value"
    fi
}

resolve_json() {
    local theme="$1" mode="$2" accent="$3" dynamic="$4"
    local -a args=(resolve --theme "$theme" --mode "$mode"
        --light-override "$LIGHT_OVERRIDE" --dark-override "$DARK_OVERRIDE")
    [ -n "$accent" ] && args+=(--accent "$accent")
    [ "$dynamic" = "true" ] && args+=(--dynamic)
    python3 "$ADAPTER_CLI" "${args[@]}" 2>/dev/null
}

manifest_matches() {
    local name="$1" resolved="$2"
    local file="$ICONS_DIR/$name/.icon-theme-meta.json"
    [ -f "$file" ] || return 1
    local adapter version base basePath mode accent
    adapter=$(jq -r '.adapter // empty' <<<"$resolved")
    version=$(jq -r '.adapterVersion // 0' <<<"$resolved")
    base=$(jq -r '.base // empty' <<<"$resolved")
    basePath=$(jq -r '.basePath // empty' <<<"$resolved")
    mode=$(jq -r '.mode // empty' <<<"$resolved")
    accent=$(jq -r '.accent // empty' <<<"$resolved")
    jq -e --arg adapter "$adapter" --arg base "$base" --arg basePath "$basePath" \
        --arg mode "$mode" --arg accent "$accent" --argjson version "${version:-0}" '
        .format == 1 and .generated == true
        and .adapter == $adapter and .adapterVersion == $version
        and .base == $base and .basePath == $basePath
        and .mode == $mode and .accent == $accent
    ' "$file" >/dev/null 2>&1
}

name_for_mode() {
    local mode="$1" resolved out base dynamic
    resolved=$(resolve_json "$THEME" "$mode" "$ACCENT" "$DYNAMIC")
    [ -n "$resolved" ] || return 0
    [ "$(jq -r '.ok // false' <<<"$resolved")" = "true" ] || return 0
    out=$(jq -r '.out' <<<"$resolved")
    base=$(jq -r '.base' <<<"$resolved")
    dynamic=$(jq -r '.dynamic' <<<"$resolved")
    if [ "$dynamic" = "true" ] && manifest_matches "$out" "$resolved"; then
        printf '%s\n' "$out"
    else
        printf '%s\n' "$base"
    fi
}

write_selection() {
    local sel="$1" source="$2" mode="$3" accent="$4" tmp
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    tmp=$(mktemp "$STATE_DIR/selection.json.tmp.XXXXXX") || return 1
    if jq -n --arg sel "$sel" --arg source "$source" --arg theme "$THEME" \
        --arg mode "$mode" --arg accent "$accent" \
        --argjson dynamic "$(json_bool "$DYNAMIC")" \
        --argjson follow "$(json_bool "$FOLLOW")" '
        {format:1, selectionId:$sel, source:$source, theme:$theme, mode:$mode,
         accent:$accent, dynamicColor:$dynamic, followScheme:$follow,
         createdAt:(now|todateiso8601)}' >"$tmp"; then
        mv -f "$tmp" "$STATE_DIR/selection.json"
    else
        rm -f "$tmp"
        return 1
    fi
}

write_request() {
    local id="$1" sel="$2" resolved="$3" keep="$4" tmp
    tmp=$(mktemp "$STATE_DIR/request.json.tmp.XXXXXX") || return 1
    if jq -n --arg id "$id" --arg sel "$sel" --arg theme "$THEME" \
        --arg adapter "$(jq -r '.adapter' <<<"$resolved")" \
        --argjson version "$(jq -r '.adapterVersion' <<<"$resolved")" \
        --arg base "$(jq -r '.base' <<<"$resolved")" \
        --arg basePath "$(jq -r '.basePath' <<<"$resolved")" \
        --arg mode "$(jq -r '.mode' <<<"$resolved")" \
        --arg accent "$(jq -r '.accent' <<<"$resolved")" \
        --arg out "$(jq -r '.out' <<<"$resolved")" \
        --arg capability "$(jq -r '.capability' <<<"$resolved")" \
        --argjson keep "$keep" '
        {format:1, id:$id, selectionId:$sel, cancelled:false, theme:$theme,
         adapter:$adapter, adapterVersion:$version, base:$base, basePath:$basePath,
         mode:$mode, accent:$accent, out:$out, capability:$capability,
         keepGenerated:$keep, createdAt:(now|todateiso8601)}' >"$tmp"; then
        mv -f "$tmp" "$STATE_DIR/request.json"
    else
        rm -f "$tmp"
        return 1
    fi
}

cancel_pending() {
    local sel="$1" tmp
    tmp=$(mktemp "$STATE_DIR/request.json.tmp.XXXXXX") || return 0
    if jq -n --arg id "$(new_id)" --arg sel "$sel" '
        {format:1, id:$id, selectionId:$sel, cancelled:true,
         createdAt:(now|todateiso8601)}' >"$tmp"; then
        mv -f "$tmp" "$STATE_DIR/request.json"
    else
        rm -f "$tmp"
    fi
}

set_status() {
    local state="$1" active="$2" base="$3" mode="$4" accent="$5" capability="$6"
    local pending_id="$7" pending_out="$8" error="$9" sel="${10:-}"
    local tmp
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    exec 7>"$STATE_DIR/status.lock" || return 0
    flock -w 2 7 || { exec 7>&-; return 0; }
    tmp=$(mktemp "$STATE_DIR/status.json.tmp.XXXXXX") || { flock -u 7; exec 7>&-; return 1; }
    if jq -n --arg state "$state" --arg active "$active" --arg base "$base" \
        --arg mode "$mode" --arg accent "$accent" --arg capability "$capability" \
        --arg pending_id "$pending_id" --arg pending_out "$pending_out" \
        --arg error "$error" --arg sel "$sel" '
        {format:1, state:$state,
         active:(if $active=="" then null else $active end),
         base:$base, mode:$mode, accent:$accent, capability:$capability,
         selectionId:(if $sel=="" then null else $sel end),
         pending:(if $pending_id=="" then null else {id:$pending_id,out:$pending_out} end),
         lastError:(if $error=="" then null else $error end),
         updatedAt:(now|todateiso8601)}' >"$tmp"; then
        mv -f "$tmp" "$STATE_DIR/status.json"
    else
        rm -f "$tmp"
    fi
    flock -u 7
    exec 7>&-
}

write_kmyc_key() {
    local key="$1" value="$2" tmp mode
    [ -f "$KMYC_CONFIG" ] || return 0
    mode=$(stat -c '%a' "$KMYC_CONFIG" 2>/dev/null || printf '644')
    tmp=$(mktemp "${KMYC_CONFIG}.tmp.XXXXXX") || return 1
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$KMYC_CONFIG"; then
        # Replace the last active occurrence: configparser uses the last value
        # if a key was duplicated by an external tool.
        awk -v key="$key" -v value="$value" '
            { lines[NR] = $0 }
            $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { last = NR }
            END {
                for (i = 1; i <= NR; i++) {
                    if (i == last) print key " = " value
                    else print lines[i]
                }
            }
        ' "$KMYC_CONFIG" >"$tmp"
    elif grep -qE '^\[CUSTOM\][[:space:]]*$' "$KMYC_CONFIG"; then
        awk -v key="$key" -v value="$value" '
            { print }
            /^\[CUSTOM\][[:space:]]*$/ && !done { print key " = " value; done = 1 }
            END { if (!done) print key " = " value }
        ' "$KMYC_CONFIG" >"$tmp"
    else
        { cat "$KMYC_CONFIG"; printf '%s = %s\n' "$key" "$value"; } >"$tmp"
    fi
    chmod "$mode" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$KMYC_CONFIG"
}

sync_policy() {
    local light="$1" dark="$2"
    [ "$PREVENT" = "true" ] || return 0
    [ -f "$KMYC_CONFIG" ] || return 0
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    exec 8>"$STATE_DIR/kmyc.lock" || return 0
    flock -w 5 8 || { exec 8>&-; return 0; }
    if [ ! -f "$STATE_DIR/kmyc-original" ]; then
        {
            if grep -qE '^[[:space:]]*iconslight[[:space:]]*=' "$KMYC_CONFIG"; then
                grep -E '^[[:space:]]*iconslight[[:space:]]*=' "$KMYC_CONFIG" | tail -n1
            else
                printf 'absent iconslight\n'
            fi
            if grep -qE '^[[:space:]]*iconsdark[[:space:]]*=' "$KMYC_CONFIG"; then
                grep -E '^[[:space:]]*iconsdark[[:space:]]*=' "$KMYC_CONFIG" | tail -n1
            else
                printf 'absent iconsdark\n'
            fi
        } >"$STATE_DIR/kmyc-original"
    fi
    write_kmyc_key iconslight "$light"
    write_kmyc_key iconsdark "$dark"
    printf 'managed = true\nlastWrittenLight = %s\nlastWrittenDark = %s\n' "$light" "$dark" \
        >"$STATE_DIR/kmyc-state"
    flock -u 8
    exec 8>&-
}

sync_policy_for() {
    local mode="$1" light="" dark=""
    if [ "$mode" = "static" ]; then
        light=$(name_for_mode static)
        dark="$light"
    else
        light=$(name_for_mode light)
        dark=$(name_for_mode dark)
    fi
    # If only one variant is installed, keep both KDE keys on a theme that
    # actually exists instead of writing an empty or stale name.
    if [ -z "$light" ] && [ -n "$dark" ]; then
        light="$dark"
    elif [ -z "$dark" ] && [ -n "$light" ]; then
        dark="$light"
    fi
    if [ -n "$light" ] && [ -n "$dark" ]; then
        sync_policy "$light" "$dark"
    fi
}

remove_kmyc_key() {
    local key="$1" tmp mode
    [ -f "$KMYC_CONFIG" ] || return 0
    mode=$(stat -c '%a' "$KMYC_CONFIG" 2>/dev/null || printf '644')
    tmp=$(mktemp "${KMYC_CONFIG}.tmp.XXXXXX") || return 1
    awk -v key="$key" '$0 !~ "^[[:space:]]*" key "[[:space:]]*=" { print }' \
        "$KMYC_CONFIG" >"$tmp"
    chmod "$mode" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$KMYC_CONFIG"
}

restore_kmyc() {
    local mode="${1:-}"
    [ -f "$STATE_DIR/kmyc-original" ] || return 0
    [ -f "$KMYC_CONFIG" ] || return 0
    exec 8>"$STATE_DIR/kmyc.lock" || return 0
    flock -w 5 8 || { exec 8>&-; return 0; }
    local key value line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [[ "$line" == "absent "* ]]; then
            remove_kmyc_key "${line#absent }"
            continue
        fi
        key=$(sed -E 's/^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=.*$/\1/' <<<"$line")
        value=$(sed -E 's/^[^=]*=[[:space:]]*//' <<<"$line")
        if [ -n "$key" ]; then
            write_kmyc_key "$key" "$value"
        fi
    done <"$STATE_DIR/kmyc-original"
    printf 'managed = false\n' >"$STATE_DIR/kmyc-state"
    flock -u 8
    exec 8>&-
}

restore_live_theme() {
    # Restore is an explicit action: put the original KDE theme back on screen
    # as well as back in the wrapper config. The next managed apply will use
    # the selected shell theme again, so the UI also disables the override.
    local mode="${1:-}" key restored
    [ -f "$KMYC_CONFIG" ] || return 0
    if [ -z "$mode" ]; then
        mode=$(jq -r '.mode // empty' "$STATE_DIR/status.json" 2>/dev/null || true)
    fi
    [ -n "$mode" ] || mode=$(detect_mode)
    key="iconsdark"
    [ "$mode" = "light" ] && key="iconslight"
    restored=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$KMYC_CONFIG" 2>/dev/null \
        | tail -n1 | sed -E 's/[[:space:]]+$//')
    if [ -n "$restored" ]; then
        apply_theme "$restored" || true
    fi
}

apply_theme() {
    local name="$1"
    [ -n "$name" ] || return 1
    [ -f "$APPLY_CMD" ] || return 1
    bash "$APPLY_CMD" --set-icons "$name" >/dev/null 2>&1
}

spawn_worker() {
    [ "${ICON_MANAGER_NO_SPAWN:-0}" = "1" ] && return 0
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    # Workers serialize on worker.lock. New workers wait for the current build
    # and then read the latest request, so no request can be lost between a
    # build finishing and a new wallpaper change. last-processed.json lets
    # queued workers exit immediately when the request is already done.
    local debounce="${ICON_MANAGER_DEBOUNCE:-1200}"
    local -a command=(python3 "$WORKER"
        --request-file "$STATE_DIR/request.json"
        --icons-dir "$ICONS_DIR"
        --state-dir "$STATE_DIR"
        --debounce "$debounce"
        --manager "$SCRIPT_DIR/icon-theme-manager.sh")
    if command -v setsid >/dev/null 2>&1; then
        setsid nohup "${command[@]}" >>"$STATE_DIR/worker.log" 2>&1 </dev/null &
    else
        nohup "${command[@]}" >>"$STATE_DIR/worker.log" 2>&1 </dev/null &
    fi
    disown 2>/dev/null || true
}

cmd_apply() {
    local source="$1" mode="$2"
    manager_lock || exit 3
    if [ "$FOLLOW" = "false" ]; then
        mode="static"
    else
        mode="${mode:-$(detect_mode)}"
    fi
    ACCENT=$(get_primary)
    local sel resolved
    sel=$(new_id)
    resolved=$(resolve_json "$THEME" "$mode" "$ACCENT" "$DYNAMIC")

    if [ -z "$resolved" ] || [ "$(jq -r '.ok // false' <<<"$resolved")" != "true" ]; then
        # The configured theme may have been uninstalled. Keep icons usable by
        # falling back to the current theme (minus generated suffix), then to a
        # few common themes, without rewriting the user's config.
        local alternative attempt
        for alternative in "$(current_icon_theme)" "Papirus" "Tela" "Adwaita"; do
            [ -n "$alternative" ] || continue
            [ "$alternative" = "$THEME" ] && continue
            attempt=$(resolve_json "$alternative" "$mode" "$ACCENT" "$DYNAMIC")
            if [ -n "$attempt" ] && [ "$(jq -r '.ok // false' <<<"$attempt")" = "true" ]; then
                THEME="$alternative"
                resolved="$attempt"
                break
            fi
        done
    fi

    if [ -z "$resolved" ] || [ "$(jq -r '.ok // false' <<<"$resolved")" != "true" ]; then
        local error
        error=$(jq -r '.error // "theme resolution failed"' <<<"$resolved" 2>/dev/null)
        write_selection "$sel" "$source" "$mode" "$ACCENT"
        set_status error "" "" "$mode" "$ACCENT" none "" "" "$error" "$sel"
        manager_unlock
        return 4
    fi

    write_selection "$sel" "$source" "$mode" "$ACCENT"

    local base out dynamic capability spawn=0
    base=$(jq -r '.base' <<<"$resolved")
    out=$(jq -r '.out' <<<"$resolved")
    dynamic=$(jq -r '.dynamic' <<<"$resolved")
    capability=$(jq -r '.capability' <<<"$resolved")

    if [ "$dynamic" = "true" ] && manifest_matches "$out" "$resolved"; then
        if apply_theme "$out"; then
            set_status idle "$out" "$base" "$mode" "$ACCENT" "$capability" "" "" "" "$sel"
        else
            set_status error "" "$base" "$mode" "$ACCENT" "$capability" "" "" \
                "failed to apply $out" "$sel"
            manager_unlock
            return 4
        fi
        sync_policy_for "$mode"
    else
        if ! apply_theme "$base"; then
            set_status error "" "$base" "$mode" "$ACCENT" "$capability" "" "" \
                "failed to apply $base" "$sel"
            manager_unlock
            return 4
        fi
        if [ "$dynamic" = "true" ]; then
            local id
            id=$(new_id)
            if write_request "$id" "$sel" "$resolved" "$KEEP"; then
                set_status queued "$base" "$base" "$mode" "$ACCENT" "$capability" \
                    "$id" "$out" "" "$sel"
                spawn=1
            else
                set_status error "$base" "$base" "$mode" "$ACCENT" "$capability" "" "" \
                    "failed to write generation request" "$sel"
            fi
        else
            cancel_pending "$sel"
            local state="idle"
            if [ "$capability" = "none" ]; then
                state="unsupported"
            elif [ -z "$ACCENT" ] && [ "$DYNAMIC" = "true" ]; then
                state="unsupported"
            fi
            set_status "$state" "$base" "$base" "$mode" "$ACCENT" "$capability" "" "" "" "$sel"
        fi
        sync_policy_for "$mode"
    fi

    manager_unlock
    if [ "$spawn" = "1" ]; then
        spawn_worker
    fi
    return 0
}

cmd_activate() {
    local out="$1" request_id="$2" selection_id="$3"
    manager_lock || exit 3

    local selection
    selection=$(cat "$STATE_DIR/selection.json" 2>/dev/null || printf '{}')
    if [ "$(jq -r '.selectionId // empty' <<<"$selection")" != "$selection_id" ]; then
        manager_unlock
        exit 2
    fi

    local request
    request=$(cat "$STATE_DIR/request.json" 2>/dev/null || printf '{}')
    if [ "$(jq -r '.id // empty' <<<"$request")" != "$request_id" ]; then
        manager_unlock
        exit 2
    fi
    if [ "$(jq -r '.cancelled // false' <<<"$request")" = "true" ]; then
        manager_unlock
        exit 2
    fi

    THEME=$(jq -r '.theme // empty' <<<"$selection")
    FOLLOW=$(jq -r '.followScheme // true' <<<"$selection")
    DYNAMIC=$(jq -r '.dynamicColor // true' <<<"$selection")
    ACCENT=$(jq -r '.accent // empty' <<<"$selection")
    local mode
    mode=$(jq -r '.mode // empty' <<<"$selection")

    local resolved expected dynamic capability
    resolved=$(resolve_json "$THEME" "$mode" "$ACCENT" "$DYNAMIC")
    expected=$(jq -r '.out // empty' <<<"$resolved")
    dynamic=$(jq -r '.dynamic // false' <<<"$resolved")
    capability=$(jq -r '.capability // "none"' <<<"$resolved")
    if [ "$dynamic" != "true" ] || [ "$out" != "$expected" ]; then
        manager_unlock
        exit 2
    fi
    if ! manifest_matches "$out" "$resolved"; then
        manager_unlock
        exit 3
    fi

    if ! apply_theme "$out"; then
        set_status error "" "$(jq -r '.base // empty' <<<"$resolved")" "$mode" "$ACCENT" \
            "$capability" "" "" "failed to apply $out" "$selection_id"
        manager_unlock
        exit 4
    fi

    set_status idle "$out" "$(jq -r '.base // empty' <<<"$resolved")" "$mode" "$ACCENT" \
        "$capability" "" "" "" "$selection_id"
    sync_policy_for "$mode"
    manager_unlock
    exit 0
}

cmd_post_kde() {
    local mode="$1"
    [ "$PREVENT" = "true" ] || return 0
    if [ "$FOLLOW" = "false" ]; then
        mode="static"
    else
        mode="${mode:-$(detect_mode)}"
    fi
    ACCENT=$(get_primary)
    manager_lock || return 0
    local name
    name=$(name_for_mode "$mode")
    if [ -n "$name" ]; then
        apply_theme "$name" || true
    fi
    sync_policy_for "$mode"
    manager_unlock
}

cmd_sync() {
    local mode="$1"
    if [ "$FOLLOW" = "false" ]; then
        mode="static"
    else
        mode="${mode:-$(detect_mode)}"
    fi
    ACCENT=$(get_primary)
    sync_policy_for "$mode"
}

cmd_status() {
    local json="$1"
    if [ ! -f "$STATE_DIR/status.json" ]; then
        [ "$json" = "1" ] && printf '{}\n'
        return 0
    fi
    if [ "$json" = "1" ]; then
        cat "$STATE_DIR/status.json"
    else
        jq -r '"state=\(.state // "unknown") active=\(.active // "-") base=\(.base // "-") capability=\(.capability // "-") pending=\(.pending.out // "-")"' \
            "$STATE_DIR/status.json" 2>/dev/null
    fi
}

main() {
    local do_apply=0 do_sync=0 do_activate=0 do_restore=0 do_cancel=0
    local do_post=0 do_status=0 json=0
    local mode="" source="auto" out="" request_id="" selection_id=""

    while (($#)); do
        case "$1" in
            --apply) do_apply=1; shift ;;
            --sync) do_sync=1; shift ;;
            --activate) do_activate=1; out="${2:-}"; shift 2 ;;
            --request-id) request_id="${2:-}"; shift 2 ;;
            --selection-id) selection_id="${2:-}"; shift 2 ;;
            --restore-kmyc) do_restore=1; shift ;;
            --cancel) do_cancel=1; shift ;;
            --post-kde) do_post=1; shift ;;
            --status) do_status=1; shift ;;
            --json) json=1; shift ;;
            --mode) mode="${2:-}"; shift 2 ;;
            --source) source="${2:-auto}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "icon-theme-manager: unknown option: $1" >&2; usage >&2; exit 2 ;;
        esac
    done

    load_config
    mkdir -p "$STATE_DIR" 2>/dev/null || true

    if [ "$do_restore" = "1" ]; then
        manager_lock || exit 3
        restore_kmyc
        restore_live_theme "$mode"
        manager_unlock
    fi
    if [ "$do_cancel" = "1" ]; then
        manager_lock || exit 3
        local sel
        sel=$(jq -r '.selectionId // empty' "$STATE_DIR/selection.json" 2>/dev/null || true)
        cancel_pending "$sel"
        manager_unlock
    fi
    if [ "$do_activate" = "1" ]; then
        cmd_activate "$out" "$request_id" "$selection_id"
    fi
    if [ "$do_post" = "1" ]; then
        cmd_post_kde "$mode"
    fi
    if [ "$do_apply" = "1" ]; then
        cmd_apply "$source" "$mode"
    fi
    if [ "$do_sync" = "1" ] && [ "$do_apply" = "0" ] && [ "$do_post" = "0" ]; then
        cmd_sync "$mode"
    fi
    if [ "$do_status" = "1" ]; then
        cmd_status "$json"
    fi

    if [ "$do_apply$do_sync$do_activate$do_restore$do_cancel$do_post$do_status" = "0000000" ]; then
        usage >&2
        exit 2
    fi
    exit 0
}

main "$@"
