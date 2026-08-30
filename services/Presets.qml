pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property alias folderModel: presetsFolderModel
    property string currentPreset: Persistent.states?.preset?.currentPreset ?? ""
    property string previousPreset: Persistent.states?.preset?.previousPreset ?? ""
    property string beforeGameMode: Persistent.states?.preset?.beforeGameMode ?? ""
    property string lastGameMode: Persistent.states?.preset?.lastGameMode ?? ""

    function syncFromPersistent() {
        const savedCurrent = Persistent.states?.preset?.currentPreset ?? ""
        const savedPrevious = Persistent.states?.preset?.previousPreset ?? ""
        const savedBeforeGameMode = Persistent.states?.preset?.beforeGameMode ?? ""

        if (savedCurrent.length > 0) root.currentPreset = savedCurrent
        if (savedPrevious.length > 0) root.previousPreset = savedPrevious
        if (savedBeforeGameMode.length > 0) root.beforeGameMode = savedBeforeGameMode
    }

    Component.onCompleted: root.syncFromPersistent()

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready) root.syncFromPersistent()
        }
    }

    FolderListModel {
        id: presetsFolderModel
        folder: Qt.resolvedUrl(Directories.userPresetsPath)
        showDirs: false
        nameFilters: ["*.json"]
    }

    function refresh() {
        const current = presetsFolderModel.folder
        presetsFolderModel.folder = ""
        presetsFolderModel.folder = current
    }

    Process {
        id: saveProc
        onExited: root.refresh()
    }

    Process {
        id: deleteProc
        onExited: root.refresh()
    }

    function save(rawInput) {
        const raw = (rawInput ?? "").trim()
        if (raw.length === 0) return

        const commaIndex = raw.indexOf(",")
        let name = raw
        let description = ""

        if (commaIndex !== -1) {
            name = raw.substring(0, commaIndex).trim()
            description = raw.substring(commaIndex + 1).trim()
        }

        name = name.replace(/\s/g, "_")
        if (name.length === 0) return

        saveProc.command = ["bash", Directories.presetsScriptPath, "--save", name, description]
        saveProc.running = true
    }

    function apply(name) {
        const presetName = (name ?? "").trim()
        if (presetName.length === 0) return

        GlobalStates.settingsOpen = false
        Wallpapers.confirmedPath = ""
        Wallpapers.previewPath = ""

        root.currentPreset = presetName
        Persistent.states.preset.currentPreset = presetName
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", presetName])
    }

    function gameModePresetName() {
        const presetName = (Config.options.profile.gameModePresetName ?? "").trim()
        return presetName.length > 0 ? presetName : "GameMode"
    }

    function ensureGameModePresetExists() {
        if (!Config.options.profile.gameModePresetEnabled) return

        const targetPreset = gameModePresetName()
        const targetFile = `${targetPreset}.json`
        let found = false

        for (let i = 0; i < presetsFolderModel.count; ++i) {
            const fileName = presetsFolderModel.get(i, "fileName") ?? ""
            if (fileName === targetFile) {
                found = true
                break
            }
        }

        if (!found) {
            save(targetPreset)
        }
    }

    function saveCurrentPresetBeforeGameMode() {
        if (!Config.options.profile.gameModePresetEnabled) return

        const activePreset = (root.currentPreset.length > 0 ? root.currentPreset : (Persistent.states?.preset?.currentPreset ?? "")).trim()
        const targetPreset = gameModePresetName()
        if (activePreset === "" || activePreset === targetPreset) {
            if (root.previousPreset.length > 0 && root.previousPreset !== targetPreset) {
                root.beforeGameMode = root.previousPreset
                Persistent.states.preset.beforeGameMode = root.previousPreset
            }
            return
        }

        root.beforeGameMode = activePreset
        Persistent.states.preset.beforeGameMode = activePreset
        root.previousPreset = activePreset
        Persistent.states.preset.previousPreset = activePreset

        save(activePreset)
    }

    function restorePreviousPreset() {
        save(gameModePresetName())
        if (!Config.options.profile.gameModePresetEnabled) {
            root.lastGameMode = ""
            Persistent.states.preset.lastGameMode = ""
            root.beforeGameMode = ""
            Persistent.states.preset.beforeGameMode = ""
            root.previousPreset = ""
            Persistent.states.preset.previousPreset = ""

            HyprlandConfig.resetMany([
                "animations:enabled",
                "decoration:shadow:enabled",
                "decoration:blur:enabled",
                "general:gaps_in",
                "general:gaps_out",
                "general:border_size",
                "decoration:rounding",
                "general:allow_tearing",
            ])
            return true
        }

        // Gather fallback chain across root and persistent states, filtering out the game mode name itself
        const targetPreset = gameModePresetName()
        let presetName = (root.beforeGameMode || Persistent.states?.preset?.beforeGameMode || "").trim()
        
        if (presetName === "" || presetName === targetPreset) {
            presetName = (root.previousPreset || Persistent.states?.preset?.previousPreset || "").trim()
        }

        if (presetName === "" || presetName === targetPreset) {
            console.warn("Presets: Cannot restore previous preset because no valid non-gamemode preset was found.")
            return false
        }

        // Clear tracking states
        root.lastGameMode = ""
        Persistent.states.preset.lastGameMode = ""
        root.beforeGameMode = ""
        Persistent.states.preset.beforeGameMode = ""
        root.previousPreset = ""
        Persistent.states.preset.previousPreset = ""

        HyprlandConfig.resetMany([
            "animations:enabled",
            "decoration:shadow:enabled",
            "decoration:blur:enabled",
            "general:gaps_in",
            "general:gaps_out",
            "general:border_size",
            "decoration:rounding",
            "general:allow_tearing",
        ])
        
        apply(presetName)
        return true
    }

    function activateGameMode() {
        if (!Config.options.profile.gameModePresetEnabled) {
            root.lastGameMode = ""
            Persistent.states.preset.lastGameMode = ""
            return
        }

        ensureGameModePresetExists()
        saveCurrentPresetBeforeGameMode()

        const targetPreset = gameModePresetName()
        root.lastGameMode = targetPreset
        Persistent.states.preset.lastGameMode = targetPreset
        apply(targetPreset)
    }

    
 
    function remove(name) {
        deleteProc.command = ["bash", Directories.presetsScriptPath, "--remove", name]
        deleteProc.running = true
    }
}