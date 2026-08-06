pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    Connections {
        target: Config.options.background
        function onLockWallChanged() {
            if (!Config.options.background.lockWall || Config.options.background.lockWall.length === 0) return
            genProc.command = [
                "bash", Directories.wallpaperSwitchScriptPath,
                "--lock-colors-only", FileUtils.trimFileProtocol(Config.options.background.lockWall)
            ]
            genProc.running = true
        }
    }

    Process {
        id: genProc
        onExited: (exitCode) => {
            if (exitCode !== 0) console.warn("[LockWallpaperColorGen] switchwall.sh --lock-colors-only failed")
        }
    }
}