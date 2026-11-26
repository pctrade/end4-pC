pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/named_scheme.py`)
    readonly property string userDir: FileUtils.trimFileProtocol(`${Directories.shellConfig}/schemes`)
    readonly property string templatePath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/schemes/_template.json`)
    property var schemes: ({})
    readonly property var schemeIds: Object.keys(root.schemes)

    readonly property string current: Config.options.appearance.palette.namedScheme
    readonly property var currentData: root.schemes[root.current] ?? null

    function schemeOptions() {
        const options = [{ displayName: "Material", value: "" }]
        for (const id of root.schemeIds)
            options.push({ displayName: root.schemes[id].name, value: id })
        return options
    }

    function materialPreview() {
        const colors = Appearance.colors
        return [
            { value: "primary", color: colors.colPrimary, displayName: "Primary" },
            { value: "secondary", color: colors.colSecondary, displayName: "Secondary" },
            { value: "tertiary", color: colors.colTertiary, displayName: "Tertiary" },
            { value: "primaryContainer", color: colors.colPrimaryContainer, displayName: "Primary container" },
            { value: "secondaryContainer", color: colors.colSecondaryContainer, displayName: "Secondary container" },
            { value: "tertiaryContainer", color: colors.colTertiaryContainer, displayName: "Tertiary container" },
            { value: "error", color: colors.colError, displayName: "Error" }
        ]
    }

    function accentOptions() {
        const data = root.currentData
        if (!data) return root.materialPreview()
        const accents = data.accents[Appearance.m3colors.darkmode ? "dark" : "light"]
        return Object.keys(accents).map(name => ({
            value: name,
            color: accents[name],
            displayName: name.charAt(0).toUpperCase() + name.slice(1)
        }))
    }

    function currentAccent(slot) {
        const data = root.currentData
        if (!data) return slot === "primary" ? "primary" : "secondary"
        const chosen = Config.options.appearance.palette[slot === "primary" ? "namedSchemePrimary" : "namedSchemeSecondary"]
        const accents = data.accents[Appearance.m3colors.darkmode ? "dark" : "light"]
        return chosen in accents ? chosen : data.defaults[slot]
    }

    property var pendingArgs: []

    function run(args, closeSettings = true) {
        const shouldClose = closeSettings && Config.options.settings.style !== "dashboard"
        root.pendingArgs = args
        if (shouldClose) GlobalStates.settingsOpen = false
        applyTimer.interval = shouldClose ? 800 : 100
        applyTimer.restart()
    }

    Timer {
        id: applyTimer
        interval: 800
        onTriggered: Quickshell.execDetached(["bash", FileUtils.trimFileProtocol(Directories.wallpaperSwitchScriptPath), "--noswitch", ...root.pendingArgs])
    }

    function setScheme(id, closeSettings = true) {
        root.run(["--scheme-name", id === "" ? "clear" : id], closeSettings)
    }

    function setAccent(slot, name, closeSettings = true) {
        if (root.current === "") return
        root.run(["--scheme-name", root.current, slot === "primary" ? "--scheme-primary" : "--scheme-secondary", name], closeSettings)
    }

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    function openFolder() {
        GlobalStates.settingsOpen = false
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p "${root.userDir}" && cp -n "${root.templatePath}" "${root.userDir}/_template.json"; xdg-open "${root.userDir}"`])
    }

    function addScheme() {
        GlobalStates.settingsOpen = false
        pickTimer.restart()
    }

    Timer {
        id: pickTimer
        interval: 500
        onTriggered: {
            pickProc.running = false
            pickProc.running = true
        }
    }

    Process {
        id: pickProc
        command: ["kdialog", "--getopenfilename", Quickshell.env("HOME"), "application/json"]
        stdout: StdioCollector { id: pickOutput }
        onExited: code => {
            const path = pickOutput.text.trim()
            if (code !== 0 || path === "") return
            importProc.command = ["python3", root.scriptPath, "--import-file", path]
            importProc.running = true
        }
    }

    Process {
        id: importProc
        stdout: StdioCollector { id: importOutput }
        stderr: StdioCollector { id: importError }
        onExited: code => {
            if (code === 0) {
                root.reload()
                Quickshell.execDetached(["notify-send", Translation.tr("Color scheme added"), importOutput.text.trim(), "-a", "Shell"])
            } else {
                Quickshell.execDetached(["notify-send", Translation.tr("Invalid color scheme"), importError.text.trim(), "-a", "Shell", "-u", "critical"])
            }
        }
    }

    Process {
        id: listProc
        command: ["python3", root.scriptPath, "--list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.schemes = JSON.parse(text)
                } catch (e) {
                    console.warn("[ColorSchemes] could not parse scheme list:", e)
                }
            }
        }
    }
}
