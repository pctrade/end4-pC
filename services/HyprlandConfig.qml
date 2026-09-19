pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root
    signal reloaded()

    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/hyprconfigurator.py")
    readonly property string shellOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/main.lua`)
    readonly property string animOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/animations.lua`)
    readonly property string applicationOpacityScriptPath: Quickshell.shellPath("scripts/appOpacitySync.py")
    readonly property string applicationOpacityOutputPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/appOpacity.lua`)

    function set(key: string, value: var) {
        Quickshell.execDetached([
            "python3", root.configuratorScriptPath,
            "--file", root.shellOverridesPath,
            "--set", key, String(value)
        ])
    }

    function setMany(entries: var) {
        let args = ["python3", root.configuratorScriptPath, "--file", root.shellOverridesPath]
        for (let key in entries) {
            args.push("--set", key, String(entries[key]))
        }
        Quickshell.execDetached(args)
    }

    function reset(key: string) {
        Quickshell.execDetached([
            "python3", root.configuratorScriptPath,
            "--file", root.shellOverridesPath,
            "--reset", key
        ])
    }

    function resetMany(keys: list<string>) {
        let args = ["python3", root.configuratorScriptPath, "--file", root.shellOverridesPath]
        for (let i = 0; i < keys.length; i++) {
            args.push("--reset", keys[i])
        }
        Quickshell.execDetached(args)
    }

    function setAnimPreset(preset: string) {
        Quickshell.execDetached([
            "python3", root.configuratorScriptPath,
            "--anim-preset", preset,
            "--anim-file", root.animOverridesPath
        ])
    }

    function syncApplicationOpacity() {
        if (!Config.ready)
            return

        applicationOpacitySyncTimer.restart()
    }

    function runApplicationOpacitySync() {
        Quickshell.execDetached([
            "python3",
            root.applicationOpacityScriptPath,
            "--config", Config.filePath,
            "--output", root.applicationOpacityOutputPath,
            "--main", root.shellOverridesPath
        ])
    }

    Timer {
        id: applicationOpacitySyncTimer
        interval: 300
        repeat: false

        onTriggered: root.runApplicationOpacitySync()
    }

    Connections {
        target: Config

        function onReadyChanged() {
            if (Config.ready)
                root.syncApplicationOpacity()
        }
    }

    Component.onCompleted: root.syncApplicationOpacity()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                root.reloaded()
            }
        }
    }
}