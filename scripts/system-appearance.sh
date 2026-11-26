#!/usr/bin/env bash
# system-appearance.sh - list and apply system icons, cursors and fonts (Qt via kdeglobals/kcminputrc + GTK via gsettings)
# Usage:
#   system-appearance.sh --list-icons | --list-cursors | --list-fonts
#   system-appearance.sh --get
#   system-appearance.sh --set-icons <theme>
#   system-appearance.sh --set-cursor <theme> <size>
#   system-appearance.sh --set-font <ui|mono> <family> <size>
#   system-appearance.sh --apply-cursor

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_DIRS=(/usr/share/icons "$DATA_HOME/icons" "$HOME/.icons")

theme_dirs() {
    for dir in "${ICON_DIRS[@]}"; do
        [ -d "$dir" ] && find -L "$dir" -mindepth 1 -maxdepth 1 -type d
    done
}

notify_qt() {
    dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:"$1" int32:"$2" 2>/dev/null
}

read_cursor() {
    cursor_theme=$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme)
    cursor_size=$(kreadconfig6 --file kcminputrc --group Mouse --key cursorSize)
    [ -z "$cursor_theme" ] && cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
    [ -z "$cursor_size" ] && cursor_size=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)
    [ -z "$cursor_size" ] && cursor_size=24
}

apply_cursor() {
    hyprctl setcursor "$1" "$2" >/dev/null 2>&1
    gsettings set org.gnome.desktop.interface cursor-theme "$1" 2>/dev/null
    gsettings set org.gnome.desktop.interface cursor-size "$2" 2>/dev/null
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$1" > "$HOME/.icons/default/index.theme"
}

replace_font_field() {
    awk -F, -v OFS=, -v family="$1" -v size="$2" '{ $1 = family; $2 = size; print }'
}

set_qt_font() {
    local key="$1" family="$2" size="$3" current
    current=$(kreadconfig6 --file kdeglobals --group General --key "$key")
    [ -z "$current" ] && current="$family,$size,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kwriteconfig6 --notify --file kdeglobals --group General --key "$key" "$(echo "$current" | replace_font_field "$family" "$size")"
}

action="$1"
shift

case "$action" in
    --list-icons)
        theme_dirs | while read -r dir; do
            name=$(basename "$dir")
            case "$name" in default|hicolor) continue ;; esac
            [ -f "$dir/index.theme" ] && grep -q "^Directories=" "$dir/index.theme" && echo "$name"
        done | grep -Ev -- '-Dynamic-' | sort -u
        ;;
    --list-cursors)
        theme_dirs | while read -r dir; do
            [ -d "$dir/cursors" ] && basename "$dir"
        done | sort -u
        ;;
    --list-fonts)
        fc-list : family | sed 's/,.*//' | sort -u
        ;;
    --get)
        read_cursor
        jq -n \
            --arg icons "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" \
            --arg cursor "$cursor_theme" \
            --argjson cursorSize "${cursor_size:-24}" \
            --arg font "$(kreadconfig6 --file kdeglobals --group General --key font)" \
            --arg mono "$(kreadconfig6 --file kdeglobals --group General --key fixed)" \
            '{
                icons: $icons,
                cursor: $cursor,
                cursorSize: $cursorSize,
                fontFamily: ($font | split(",")[0]),
                fontSize: (($font | split(",")[1]) // "11" | tonumber? // 11),
                monoFamily: ($mono | split(",")[0]),
                monoSize: (($mono | split(",")[1]) // "11" | tonumber? // 11)
            }'
        ;;
    --set-icons)
        kwriteconfig6 --notify --file kdeglobals --group Icons --key Theme "$1"
        gsettings set org.gnome.desktop.interface icon-theme "$1" 2>/dev/null
        notify_qt 4 0
        ;;
    --set-cursor)
        kwriteconfig6 --notify --file kcminputrc --group Mouse --key cursorTheme "$1"
        kwriteconfig6 --notify --file kcminputrc --group Mouse --key cursorSize "$2"
        apply_cursor "$1" "$2"
        notify_qt 5 0
        ;;
    --apply-cursor)
        read_cursor
        apply_cursor "$cursor_theme" "$cursor_size"
        ;;
    --set-font)
        role="$1"; family="$2"; size="$3"
        if [ "$role" = "mono" ]; then
            set_qt_font fixed "$family" "$size"
            gsettings set org.gnome.desktop.interface monospace-font-name "$family $size" 2>/dev/null
        else
            for key in font menuFont toolBarFont; do set_qt_font "$key" "$family" "$size"; done
            set_qt_font smallestReadableFont "$family" "$((size > 2 ? size - 2 : size))"
            gsettings set org.gnome.desktop.interface font-name "$family $size" 2>/dev/null
        fi
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac
