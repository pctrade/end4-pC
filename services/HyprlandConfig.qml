pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root
    signal reloaded()

    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/hyprconfigurator.py")
    readonly property string shellOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/main.lua`)
    readonly property string animOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/animations.lua`)

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

    readonly property string borderActiveKey: "general:col:active_border"
    readonly property string borderInactiveKey: "general:col:inactive_border"

    // Hyprland wants rgba(RRGGBBAA) without a leading '#'. Only the RGB of the
    // palette color is kept: some Appearance colors carry an alpha that encodes
    // a layer opacity inside the shell, which has nothing to do with a border.
    function toHyprColor(color, opacity) {
        const c = Qt.color(color)
        const hex = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
        return `rgba(${hex(c.r)}${hex(c.g)}${hex(c.b)}${hex(opacity)})`
    }

    // Custom window border colors, or {} when the option is off so the colors
    // matugen writes to hyprland/colors.lua keep applying. Roles are resolved
    // here rather than stored as colors, so the borders follow the wallpaper.
    function borderColorEntries() {
        const opts = Config.options?.hyprland?.general?.borderColor
        if (WM.compositor !== "hyprland" || !Config.ready || !opts?.enable) return ({})
        let entries = ({})
        entries[root.borderActiveKey] = root.toHyprColor(
            Appearance.getColorFromName(opts.activeRole), opts.activeOpacity)
        entries[root.borderInactiveKey] = root.toHyprColor(
            Appearance.getColorFromName(opts.inactiveRole), opts.inactiveOpacity)
        return entries
    }

    // Also called by MaterialThemeLoader on every palette change.
    function applyBorderColors() {
        const entries = root.borderColorEntries()
        if (Object.keys(entries).length > 0) root.setMany(entries)
    }

    function resetBorderColors() {
        if (WM.compositor !== "hyprland") return
        root.resetMany([root.borderActiveKey, root.borderInactiveKey])
    }

    function setAnimPreset(preset: string) {
        Quickshell.execDetached([
            "python3", root.configuratorScriptPath,
            "--anim-preset", preset,
            "--anim-file", root.animOverridesPath
        ])
    }

    // The palette can be loaded before the config, in which case the first
    // apply from MaterialThemeLoader was skipped.
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root.applyBorderColors()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                root.reloaded()
            }
        }
    }
}