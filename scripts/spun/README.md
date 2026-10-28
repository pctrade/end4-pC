# Spun desktop widget

The **Spun** widget is a spinning-disc desktop media controller. It follows the
same active music player as the regular Media Player widget and does not require
the standalone Spun app. Enable it under **Settings → Desktop
→ Widgets → Spun**, or in the desktop context menu's widget list. Unlock widget
positions to drag it. The existing Media Player widget remains independently
configurable.

Start playback in any player that exposes MPRIS media controls. The disc displays
that player's artwork and spins during playback. Previous, play/pause, next,
seeking, and volume control operate on the active player, with unsupported
controls disabled. Player selection, including preferred or manually selected
players, is shared with the regular Media Player widget.

**Open music player** raises the active player's window when supported. With no
player detected, the widget waits for playback and disables its controls.

## Shell controls

```bash
qs -c end4-pC ipc call spun enableWidget
qs -c end4-pC ipc call spun disableWidget
qs -c end4-pC ipc call spun open
```

The `open` command raises the active player when supported; it does not launch an
application.

Widget preferences live under `background.widgets.spun` in the shell config:
`enable`, `x`, `y`, `z`, `placementStrategy`, `size`, and `animate`. The widget also
follows the shell's shared widget blur and stacking/selection controls.
