#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_kitty() {  
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/kitty-theme.conf" ]; then
    echo "Template file not found for Kitty theme. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/kitty-theme.conf" "$STATE_DIR"/user/generated/terminal/kitty-theme.conf
  # Apply colors
  for i in "${!colorlist[@]}"; do
    val="${colorvalues[$i]#\#}"
    # Skip malformed entries (empty / not #RRGGBB). Substituting garbage is
    # exactly what produces Kitty "invalid colour name" errors on reload.
    [[ "$val" =~ ^[0-9A-Fa-f]{6}$ ]] || continue
    sed -i "s/${colorlist[$i]} #/${val}/g" "$STATE_DIR"/user/generated/terminal/kitty-theme.conf
  done

  # Reload
  kill -SIGUSR1 $(pidof kitty)
}

apply_anyterm() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    val="${colorvalues[$i]#\#}"
    # Same validation as apply_kitty: never emit malformed sequences.
    [[ "$val" =~ ^[0-9A-Fa-f]{6}$ ]] || continue
    sed -i "s/${colorlist[$i]} #/${val}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  # Target only the current controlling terminal instead of blasting
  # every /dev/pts/*; the caller's tty already knows which terminal
  # wants the palette, and writing to unrelated PTYs is what makes the
  # OSC sequences appear as stray output (e.g. when opening a video).
  local tty_dev
  tty_dev=$(tty 2>/dev/null)
  if [[ -n "$tty_dev" && "$tty_dev" =~ ^/dev/pts/[0-9]+$ ]]; then
    cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$tty_dev" & disown || true
  else
    # Fallback when there is no controlling terminal: apply to all PTYs.
    for file in /dev/pts/*; do
      if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
        cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file" & disown || true
      fi
    done
  fi
}

apply_term() {
  apply_kitty
  # Kitty is already themed via kitty-theme.conf + SIGUSR1. Skip the
  # raw-OSC write so it does not blast every /dev/pts/* with palette
  # sequences (which is what makes them appear when opening a video).
  pidof kitty >/dev/null 2>&1 || apply_anyterm
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    # Never theme from a missing/empty scss: that stamps unsubstituted
    # template tokens into kitty-theme.conf (Kitty "invalid colour name").
    if [ -s "$STATE_DIR/user/generated/material_colors.scss" ]; then
      apply_term &
    else
      echo "material_colors.scss missing or empty — keeping previous terminal theme."
    fi
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
