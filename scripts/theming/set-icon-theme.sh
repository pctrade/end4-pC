#!/usr/bin/env bash
# Apply icon theme system-wide. Usage: set-icon-theme.sh <theme>
# Ported from the rofi settings-menu script (gsettings + gtk2/3/4 + xsettingsd + rofi).
set -u

theme="$1"
[[ -z "$theme" ]] && { echo "usage: $0 <icon-theme>" >&2; exit 1; }

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

# Rofi
mkdir -p "$HOME/.config/rofi/themes"
cat >"$HOME/.config/rofi/themes/icons.rasi" <<EOF
* {
  icon-theme: "$theme";
}
EOF

gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null

set_ini_key "$HOME/.config/gtk-3.0/settings.ini" gtk-icon-theme-name "$theme"
set_ini_key "$HOME/.config/gtk-4.0/settings.ini" gtk-icon-theme-name "$theme"

# GTK 2
GTK2_CONFIG="$HOME/.gtkrc-2.0"
if grep -q "^gtk-icon-theme-name=" "$GTK2_CONFIG" 2>/dev/null; then
    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=\"$theme\"|" "$GTK2_CONFIG"
else
    echo "gtk-icon-theme-name=\"$theme\"" >>"$GTK2_CONFIG"
fi

# xsettingsd for X11/XWayland apps
XSETTINGSD_CONFIG="$HOME/.config/xsettingsd/xsettingsd.conf"
mkdir -p "$(dirname "$XSETTINGSD_CONFIG")"
if grep -q "^Net/IconThemeName" "$XSETTINGSD_CONFIG" 2>/dev/null; then
    sed -i "s|^Net/IconThemeName.*|Net/IconThemeName \"$theme\"|" "$XSETTINGSD_CONFIG"
else
    echo "Net/IconThemeName \"$theme\"" >>"$XSETTINGSD_CONFIG"
fi
pkill -HUP xsettingsd 2>/dev/null

exit 0
