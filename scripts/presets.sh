#!/usr/bin/env bash
# presets.sh - manage shell config presets | just for fun I could have done it from quickshell directly =P
# Usage:
#   presets.sh --save <name> [description]
#   presets.sh --remove <name> [--online]
#   presets.sh --apply <name> [--online]
#   presets.sh --rename <name> <new_name>
#   presets.sh --export-zip <name>
#   presets.sh --import-zip <zip_path>

CONFIG_DIR="$HOME/.config/illogical-impulse"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOCAL_PRESETS_DIR="$CONFIG_DIR/presets"
ONLINE_PRESETS_DIR="$HOME/.cache/quickshell/presets"
IMPORTED_PRESETS_DIR="$HOME/.cache/quickshell/presets_imported"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHWALL="$SCRIPT_DIR/colors/switchwall.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

mkdir -p "$LOCAL_PRESETS_DIR" "$ONLINE_PRESETS_DIR" "$IMPORTED_PRESETS_DIR"

# Blacklist: appearance.fonts (UI font families can break the layout) + General (time/battery/audio/sounds/language/workSafety) + Services (ai/networking/musicRecognition/search/screenRecord/screenSnip/updates/bar.weather) + Hyprland non-styling
# Keep: appearance/background/bar(non-weather)/dock/lock/overview/panelFamily etc. + hyprland.decoration/gaps/animations
# Note: apps/profile/wallpaperSelector are NOT blacklisted here (would make preset look empty) - only General+Services per Settings tabs
BLACKLIST_FILTER='del(._presetMeta)
  | del(.time, .battery, .audio, .sounds, .language, .workSafety)
  | del(.ai, .networking, .musicRecognition, .search, .screenRecord, .screenSnip, .updates)
  | del(.bar.weather)
  | del(.appearance.fonts)
  | del(.profile.onlinePresets, .profile.uploadGuideSeen)
  | del(.hyprland.input, .hyprland.autostartApps, .hyprland.general.layout)
  | del(.dock.pinnedApps, .launcher.pinnedApps, .tray.pinnedItems)
  | del(.sidebar.booru, .wallpaperSelector.userPath)
  | walk(if type == "object" then with_entries(select(.key | test("^(.*api[-_]?key|secret|password|token|username|e-?mail)$"; "i") | not)) else . end)'

SHARE_FILTER='with_entries(select(.key as $k | ["appearance","background","bar","calendar","crosshair","dock","interactions","launcher","light","lock","media","notifications","osd","osk","overlay","overview","panelFamily","profile","regionSelector","resources","settings","sidebar","tray","wallpaperSelector","windows","hyprland"] | index($k)))
  | if (.hyprland | type) == "object" then .hyprland |= with_entries(select(.key as $k | ["decoration","gaps","animations","general"] | index($k))) else . end'

action="$1"
shift

online=false
args=()
imported=false
preview=""
origin=""
display=""
folder_out=false
while [ $# -gt 0 ]; do
    arg="$1"
    if [ "$arg" = "--online" ]; then
        online=true
    elif [ "$arg" = "--imported" ]; then
        imported=true
    elif [ "$arg" = "--folder" ]; then
        folder_out=true
    elif [ "$arg" = "--preview" ]; then
        shift
        preview="$1"
    elif [ "$arg" = "--origin" ]; then
        shift
        origin="$1"
    elif [ "$arg" = "--as" ]; then
        shift
        display="$1"
    else
        args+=("$arg")
    fi
    shift
done

name="${args[0]}"
description="${args[1]}"

if [ "$action" = "--import-zip" ]; then
    if [ -z "$name" ]; then
        echo "Error: missing zip path" >&2
        exit 1
    fi
    zip_path="$name"
    if [ ! -f "$zip_path" ]; then
        echo "Error: zip not found: $zip_path" >&2
        exit 1
    fi
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$zip_path" -d "$tmpdir"
    else
        python3 -c "import zipfile, sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$zip_path" "$tmpdir"
    fi
    # Find json (first *.json not meta.json)
    json_file=$(find "$tmpdir" -maxdepth 4 -name "*.json" ! -name "meta.json" | head -n1)
    if [ -z "$json_file" ]; then
        echo "Error: no preset json in zip" >&2
        exit 1
    fi
    base=$(basename "$json_file" .json)
    # Collect assets from the same folder as the json (images etc, exclude json/meta).
    # Anchoring to the json dir (instead of the zip root) supports flat zips as well
    # as folder-wrapped ones (e.g. Blapples' assets/ layout).
    json_dir=$(dirname "$json_file")
    asset_files=$(find "$json_dir" -maxdepth 1 -type f ! -name "*.json" ! -name "meta.json" -exec basename {} \; | jq -R . | jq -s .)
    asset_cache="$IMPORTED_PRESETS_DIR/assets/$base"
    mkdir -p "$asset_cache"
    # Copy assets to cache (plug-and-play like online presets)
    find "$json_dir" -maxdepth 1 -type f ! -name "*.json" ! -name "meta.json" -exec cp -L {} "$asset_cache/" \; 2>/dev/null || true
    # Rewrite json paths to point to cached assets (reuse online jqFilter Profile.qml:250)
    jq --arg dir "$asset_cache" --argjson files "$asset_files" '
      $files as $files | walk(if type == "string" then ((split("/") | last) as $base | if ($files | index($base)) then ($dir + "/" + $base) else . end) else . end)
      | if (.background.collage.tree? // null) != null then
          .background.collage.tree |= (try (fromjson
            | walk(if type == "object" and .t == "leaf" and (.img | type) == "string" and .img != ""
                   then ((.img | split("/") | last) as $base | if ($files | index($base)) then .img = ($dir + "/" + $base) else . end)
                   else . end)
            | tojson) catch .)
        else . end
      | del(._presetMeta) | ._presetMeta.source = "imported"
    ' "$json_file" | jq "$BLACKLIST_FILTER" > "$IMPORTED_PRESETS_DIR/${base}.json"
    echo "Imported $base to $IMPORTED_PRESETS_DIR/${base}.json with assets in $asset_cache"
    trap - EXIT
    rm -rf "$tmpdir"
    exit 0
fi

if [ -z "$name" ]; then
    echo "Error: missing preset name" >&2
    exit 1
fi

if $imported; then
    PRESETS_DIR="$IMPORTED_PRESETS_DIR"
elif $online; then
    PRESETS_DIR="$ONLINE_PRESETS_DIR"
else
    PRESETS_DIR="$LOCAL_PRESETS_DIR"
fi

case "$action" in
    --save)
        jq "$BLACKLIST_FILTER" "$CONFIG_FILE" > "$PRESETS_DIR/${name}.json"
        if [ -n "$description" ]; then
            jq --arg desc "$description" '._presetMeta = {"description": $desc}' \
                "$PRESETS_DIR/${name}.json" > "$PRESETS_DIR/${name}.json.tmp" \
                && mv "$PRESETS_DIR/${name}.json.tmp" "$PRESETS_DIR/${name}.json"
        fi
        ;;
    --remove)
        rm -f "$PRESETS_DIR/${name}.json"
        if $online; then
            rm -rf "$ONLINE_PRESETS_DIR/assets/${name}"
        elif $imported; then
            rm -rf "$IMPORTED_PRESETS_DIR/assets/${name}"
        fi
        ;;
    --rename)
        new_name="${description//[[:space:]]/_}"
        if [ -z "$new_name" ] || [ ! -f "$PRESETS_DIR/${name}.json" ] || [ -e "$PRESETS_DIR/${new_name}.json" ]; then
            exit 1
        fi
        mv "$PRESETS_DIR/${name}.json" "$PRESETS_DIR/${new_name}.json"
        echo "$new_name"
        ;;
    --apply)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        # Filter preset input before merge so blacklisted keys never overwrite local config
        tmp=$(mktemp)
        jq "$BLACKLIST_FILTER" "$preset_file" > "$tmp"
        jq -s '.[0] * .[1] | del(._presetMeta)' "$CONFIG_FILE" "$tmp" | config_json_replace "$CONFIG_FILE"
        rm -f "$tmp"
        "$SWITCHWALL" --noswitch
        ;;
    --install)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        python3 "$SCRIPT_DIR/preset_install.py" "$preset_file" "$PRESETS_DIR/assets/$name" "$LOCAL_PRESETS_DIR" "${origin:-$($imported && echo imported || echo gallery)}" "${display:-$name}"
        ;;
    --export-zip)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        origin_tag=$(jq -r '._presetMeta.origin // empty' "$preset_file")
        if [ -n "$origin_tag" ]; then
            echo "Error: this preset comes from $origin_tag and can't be exported" >&2
            exit 3
        fi
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT
        # Use filtered preset for export
        filtered="$tmpdir/${name}.json"
        jq "$BLACKLIST_FILTER | $SHARE_FILTER" "$preset_file" > "$filtered"
        # Build meta.json + collect all image assets like online presets (ahri/meta.json)
        collect_asset() {
            local src="$1"; local key="$2"
            if [ -n "$src" ] && [ -f "$src" ]; then
                cp -L "$src" "$tmpdir/" 2>/dev/null || true
                echo "$(basename "$src")"
            fi
        }
        wallpaper=$(jq -r '.background.wallpaperPath // empty' "$filtered")
        lockwall=$(jq -r '.background.lockWall // empty' "$filtered")
        banner=$(jq -r '.sidebar.bannerImage // empty' "$filtered")
        customImg=$(jq -r '.background.widgets.customImage.path // empty' "$filtered")
        avatar=$(jq -r '.profile.avatarPicture // .profile.avatarPath // empty' "$filtered")
        # avatar path may be empty or not a file
        wallpapers="[]"
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then wallpapers=$(jq -n --arg b "$(basename "$wallpaper")" '[$b]'); fi

        if [ "$(jq -r '.background.collage.enable // false' "$filtered")" = "true" ]; then
            while IFS= read -r collage_img; do
                if [ -f "$collage_img" ]; then
                    collect_asset "$collage_img" >/dev/null
                    wallpapers=$(jq -c --arg b "$(basename "$collage_img")" '. + [$b] | unique' <<< "$wallpapers")
                fi
            done < <(jq -r '.background.collage.tree | try (fromjson | [.. | objects | select(.t == "leaf") | .img] | map(select(type == "string" and . != "")) | .[]) catch empty' "$filtered")
        fi

        # copy assets and build meta fields
        meta_avatar=""; meta_banner=""; meta_custom=""; meta_lock=""
        [ -n "$wallpaper" ] && collect_asset "$wallpaper" >/dev/null
        if [ -n "$lockwall" ] && [ -f "$lockwall" ]; then meta_lock=$(collect_asset "$lockwall"); fi
        if [ -n "$banner" ] && [ -f "$banner" ]; then meta_banner=$(collect_asset "$banner"); fi
        if [ -n "$customImg" ] && [ -f "$customImg" ]; then meta_custom=$(collect_asset "$customImg"); fi
        if [ -n "$avatar" ] && [ -f "$avatar" ]; then meta_avatar=$(collect_asset "$avatar"); fi

        jq -n --argjson w "$wallpapers" \
              --arg avatar "$meta_avatar" --arg banner "$meta_banner" \
              --arg custom "$meta_custom" --arg lock "$meta_lock" \
              '{preview: "", screenshots: [], wallpapers: $w} + (if $avatar != "" then {avatar: $avatar} else {} end)
               + (if $banner != "" then {banner: $banner} else {} end)
               + (if $custom != "" then {customImage: $custom} else {} end)
               + (if $lock != "" then {lockWall: $lock} else {} end)' > "$tmpdir/meta.json"
        jq -r '([.. | strings] + ((.background.collage.tree? // "") | try (fromjson | [.. | strings]) catch [])) | unique | .[]' "$filtered" | while IFS= read -r ref; do
            case "${ref,,}" in
                *.png|*.jpg|*.jpeg|*.webp) ;;
                *) continue ;;
            esac
            ref="${ref/#\~/$HOME}"
            [ -f "$ref" ] && cp -L "$ref" "$tmpdir/" 2>/dev/null
        done
        if [ -n "$preview" ] && [ -f "$preview" ] && command -v magick >/dev/null 2>&1; then
            if magick "$preview" -auto-orient -resize '1920x1080>' "png:$tmpdir/preview.png"; then
                jq '.preview = "preview.png"' "$tmpdir/meta.json" > "$tmpdir/.meta.tmp" && mv "$tmpdir/.meta.tmp" "$tmpdir/meta.json"
            fi
        fi
        scrubbed="$tmpdir/.scrubbed.json"
        jq 'def scrub: walk(if type == "string" and test("^(/|~/)") then (sub("/+$"; "") | split("/") | last) else . end);
            scrub
            | walk(if type == "string" and test("^[A-Za-z][A-Za-z0-9+.-]*://") then "" else . end)
            | if (.background.collage.tree? // null) != null then .background.collage.tree |= (try (fromjson | scrub | tojson) catch .) else . end' \
            "$filtered" > "$scrubbed" && mv "$scrubbed" "$filtered"
        fix_extension() {
            local img="$1" want base new current
            case "$(file -b --mime-type "$img" 2>/dev/null)" in
                image/png) want=png ;;
                image/jpeg) want=jpg ;;
                image/webp) want=webp ;;
                *) return 0 ;;
            esac
            base="${img##*/}"
            current="${base##*.}"
            [ "$current" = jpeg ] && current=jpg
            [ "${current,,}" = "$want" ] && return 0
            new="${base%.*}.$want"
            [ -e "$tmpdir/$new" ] && new="${base%.*}-fixed.$want"
            mv "$img" "$tmpdir/$new"
            for target in "$filtered" "$tmpdir/meta.json"; do
                jq --arg old "$base" --arg new "$new" \
                    'def swap: walk(if type == "string" and . == $old then $new else . end);
                     swap | if (.background.collage.tree? // null) != null then .background.collage.tree |= (try (fromjson | swap | tojson) catch .) else . end' \
                    "$target" > "$target.tmp" && mv "$target.tmp" "$target"
            done
        }
        if command -v file >/dev/null 2>&1; then
            for img in "$tmpdir"/*.png "$tmpdir"/*.jpg "$tmpdir"/*.jpeg "$tmpdir"/*.webp; do
                [ -f "$img" ] && fix_extension "$img"
            done
        fi
        # preview: try to generate or copy existing preview if exists in assets
        # Just include filtered json + meta + wallpaper basename
        size_limit=$((9 * 1024 * 1024 + 512 * 1024))
        for img in "$tmpdir"/*.png "$tmpdir"/*.jpg "$tmpdir"/*.jpeg "$tmpdir"/*.webp; do
            [ -f "$img" ] || continue
            [ "$(stat -c %s "$img")" -le "$size_limit" ] && continue
            command -v magick >/dev/null 2>&1 || continue
            case "${img##*.}" in
                png) fmt=png ;;
                webp) fmt=webp ;;
                *) fmt=jpeg ;;
            esac
            for width in 3840 2560 1920; do
                magick "$img" -auto-orient -resize "${width}x>" -quality 88 "$fmt:$img.shrunk" 2>/dev/null && mv -f "$img.shrunk" "$img"
                [ "$(stat -c %s "$img")" -le "$size_limit" ] && break
            done
            rm -f "$img.shrunk"
        done
        if $folder_out; then
            share_dir="$HOME/.cache/quickshell/presets_share/$name"
            rm -rf "$share_dir"
            mkdir -p "$share_dir"
            cp -a "$tmpdir"/. "$share_dir"/
            echo "Prepared $share_dir"
            trap - EXIT
            rm -rf "$tmpdir"
            exit 0
        fi
        zip_name="${name}.zip"
        if command -v zip >/dev/null 2>&1; then
            (cd "$tmpdir" && zip -r "$LOCAL_PRESETS_DIR/$zip_name" . >/dev/null)
        else
            python3 -c "import zipfile, pathlib, sys; z=zipfile.ZipFile(sys.argv[1],'w',zipfile.ZIP_DEFLATED); [z.write(str(p), arcname=p.name) for p in pathlib.Path(sys.argv[2]).iterdir()]; z.close()" "$LOCAL_PRESETS_DIR/$zip_name" "$tmpdir"
        fi
        echo "Exported $LOCAL_PRESETS_DIR/$zip_name"
        trap - EXIT
        rm -rf "$tmpdir"
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac
