# Spun desktop widget

The **Spun** widget is an additional desktop media controller for
[Spun](https://github.com/yappologistic/Spun). Enable it under **Settings → Desktop
→ Widgets → Spun**, or in the desktop context menu's widget list. Unlock widget
positions to drag it. The existing Media Player widget remains independently
configurable.

The disc displays Spun's current artwork and spins during playback. Previous,
play/pause, next, seeking, and volume control use Spun's MPRIS interface. Other
players do not take over this widget. **Open Spun** opens or raises the full
application, where you add music, connect Cider, and choose Spun's 2D/3D players.
The desktop disc is a native Quickshell companion; the full Spun application
runs in its own window.

## Installation

If Spun is already installed, no second installation is necessary. The launcher
checks `spun` on PATH, `$SPUN_HOME/build/spun`,
`${XDG_DATA_HOME:-~/.local/share}/spun/build/spun`, and `~/Spun/build/spun`.
`SPUN_HOME`, when set, replaces the XDG data path.

For a new installation, follow the upstream README. On Arch Linux its current
build dependencies are:

```bash
sudo pacman -S --needed base-devel git cmake ninja python qt6-base qt6-declarative qt6-multimedia qt6-svg qt6-quick3d taglib
git clone https://github.com/yappologistic/Spun.git ~/Spun
cd ~/Spun
./scripts/build.sh -DBUILD_TESTING=OFF
./scripts/install-launcher.sh
```

Spun is installed separately and retains its upstream license. This integration
does not copy Spun's code or assets into the shell. Opening the widget does not
install packages, build software, start playback, or connect to Cider.

## Shell controls

```bash
qs -c end4-pC ipc call spun enableWidget
qs -c end4-pC ipc call spun disableWidget
qs -c end4-pC ipc call spun open
```

Widget preferences live under `background.widgets.spun` in the shell config:
`enable`, `x`, `y`, `z`, `placementStrategy`, `size`, and `animate`. The widget also
follows the shell's shared widget blur and stacking/selection controls.
