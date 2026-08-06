#!/usr/bin/env bash
# Apply GTK widget theme. Usage: set-gtk-theme.sh <theme>
set -u

theme="$1"
[[ -z "$theme" ]] && { echo "usage: $0 <gtk-theme>" >&2; exit 1; }

set_ini_key() { # file key value
    local file="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$file")"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        [[ -f "$file" ]] || echo "[Settings]" >"$file"
        echo "${key}=${value}" >>"$file"
    fi
}

gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null

set_ini_key "$HOME/.config/gtk-3.0/settings.ini" gtk-theme-name "$theme"
set_ini_key "$HOME/.config/gtk-4.0/settings.ini" gtk-theme-name "$theme"

# GTK 2
GTK2_CONFIG="$HOME/.gtkrc-2.0"
if grep -q "^gtk-theme-name=" "$GTK2_CONFIG" 2>/dev/null; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=\"$theme\"|" "$GTK2_CONFIG"
else
    echo "gtk-theme-name=\"$theme\"" >>"$GTK2_CONFIG"
fi

exit 0
