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
    property var pushedTargets: ({})
    property string lastProcessedLockWall: ""
    property bool lastProcessedDarkmode: Appearance.m3colors.darkmode

    function occupiedWorkspaceIds() {
        var ids = new Set()
        var list = Hyprland.workspaces.values
        for (var k = 0; k < list.length; ++k) {
            if ((list[k].toplevels?.values?.length ?? 0) > 0) {
                ids.add(list[k].id)
            }
        }
        return ids
    }

    function nearestEmptyWorkspace(from, taken) {
        var id = Math.max(from, 0) + 1
        while (taken.has(id)) {
            id++
        }
        return id
    }

    function pushWorkspaces() {
        var currents = {}
        var taken = root.occupiedWorkspaceIds()
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            var current = Hyprland.monitorFor(Quickshell.screens[i])?.activeWorkspace?.id
            if (current == undefined) {
                return
            }
            currents[Quickshell.screens[i].name] = current
            taken.add(current)
        }

        var saved = {}
        var targets = {}
        var batch = "keyword animation workspaces,1,7,menu_decel,slidevert; "
        for (var name in currents) {
            if (root.pushedTargets[name] === currents[name]) {
                saved[name] = root.savedWorkspaces[name]
                targets[name] = currents[name]
                continue
            }
            var target = root.nearestEmptyWorkspace(currents[name], taken)
            taken.add(target)
            saved[name] = currents[name]
            targets[name] = target
            batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${name}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${target}})';`
        }
        root.savedWorkspaces = saved
        root.pushedTargets = targets
        Quickshell.execDetached(["bash", "-c", batch])
    }

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
            root.pushedTargets = ({})
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

                root.pushWorkspaces()
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
