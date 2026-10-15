pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

Singleton {
    id: root

    // Keep this widget attached to Spun even when another player becomes active.
    readonly property MprisPlayer player: Mpris.players.values.find(
        entry => entry.dbusName === "org.mpris.MediaPlayer2.spun") ?? null
    property string launchError: ""
    readonly property bool launching: locateProcess.running || startupTimer.running

    function load() {} // Register IPC controls even while the widget is disabled.

    function open() {
        root.launchError = ""
        if (root.player?.canRaise) {
            root.player.raise()
        } else if (!root.launching) {
            locateProcess.running = true
        }
    }

    onPlayerChanged: {
        if (player) {
            startupTimer.stop()
            launchError = ""
        }
    }

    Timer {
        id: startupTimer
        interval: 10000
        onTriggered: {
            if (!root.player)
                root.launchError = Translation.tr("Spun's media controls are not available yet. Try opening it from the application menu.")
        }
    }

    Process {
        id: locateProcess
        command: ["bash", Quickshell.shellPath("scripts/spun/launch.sh"), "--locate"]
        stdout: StdioCollector {
            onStreamFinished: {
                const executable = text.trim()
                if (!executable) return
                // Spun keeps running independently when the shell reloads or exits.
                Quickshell.execDetached([executable])
                startupTimer.restart()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.launchError = exitCode === 127
                    ? Translation.tr("Spun is not installed. See scripts/spun/README.md.")
                    : Translation.tr("Spun could not start. Try opening it from the application menu.")
        }
    }

    IpcHandler {
        target: "spun"
        function open(): void { root.open() }
        function enableWidget(): void { Config.options.background.widgets.spun.enable = true }
        function disableWidget(): void { Config.options.background.widgets.spun.enable = false }
    }
}
