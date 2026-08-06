pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

LockScreen {
    id: root

    property var savedWorkspaces: ({})
    property string lastProcessedLockWall: ""
    property bool lastProcessedDarkmode: Appearance.m3colors.darkmode

    Timer {
        id: restoreTimer
        interval: 150
        repeat: false
        onTriggered: {
            var batch = ""
            for (var j = 0; j < Quickshell.screens.length; ++j) {
                var monName = Quickshell.screens[j].name
                var wsId = root.savedWorkspaces[monName]
                if (wsId !== undefined) {
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${monName}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${wsId}})';`
                }
            }
            if (batch.length > 0) {
                Quickshell.execDetached(["bash", "-c", batch])
            }
        }
    }

    lockSurface: LockSurface {
        context: root.context
    }

    Process {
        id: lockThemeProc
        command: ["bash", "-c",
            `${Directories.wallpaperSwitchScriptPath} --mode ${Appearance.m3colors.darkmode ? "dark" : "light"} --colors_lock --image '${Config.options.background.lockWall}'`
        ]
        onExited: {
            MaterialThemeLoader.useLockTheme()
            root.lastProcessedLockWall = Config.options.background.lockWall
            root.lastProcessedDarkmode = Appearance.m3colors.darkmode
        }
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            var wallChanged = Config.options.background.lockWall !== root.lastProcessedLockWall
            var modeChanged = Appearance.m3colors.darkmode !== root.lastProcessedDarkmode

            if (GlobalStates.screenLocked) {
                if (Config.options.background.lockWall !== "" && (wallChanged || modeChanged)) {
                    lockThemeProc.running = true
                } else if (Config.options.background.lockWall !== "") {
                    MaterialThemeLoader.useLockTheme()
                }
                
                if (WM.compositor === "niri") {
                    return;
                }

                var next = {}
                var batch = "keyword animation workspaces,1,7,menu_decel,slidevert; "
                for (var i = 0; i < Quickshell.screens.length; ++i) {
                    var mon = Quickshell.screens[i].name
                    var mData = HyprlandData.monitors.find(m => m.name === mon)
                    if (mData?.activeWorkspace == undefined) {
                        return;
                    }
                    var ws = (mData?.activeWorkspace?.id ?? 1)
                    next[mon] = ws
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${2147483647 - ws}})';`
                }
                root.savedWorkspaces = next
                Quickshell.execDetached(["bash", "-c", batch])
            } else {
                if (Config.options.background.lockWall !== "") {
                    MaterialThemeLoader.useLiveTheme()
                }
                if (WM.compositor !== "niri") {
                    restoreTimer.start()
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property ShellScreen modelData
            property bool shouldPush: GlobalStates.screenLocked
            property string targetMonitorName: modelData.name
            property int verticalMovementDistance: modelData.height
            property int horizontalSqueeze: modelData.width * 0.2
        }
    }
}