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

    Process {
        id: renameProc
        onExited: root.refresh()
    }

    function rename(oldName, rawInput, newDescription) {
        const old = (oldName ?? "").trim()
        if (old.length === 0) return

        let name = (rawInput ?? "").trim()
        let description = newDescription

        if (description === undefined) {
            const commaIndex = name.indexOf(",")
            if (commaIndex !== -1) {
                description = name.substring(commaIndex + 1).trim()
                name = name.substring(0, commaIndex).trim()
            }
        }

        name = name.replace(/\s/g, "_")
        if (name.length === 0) return

        const cmd = ["bash", Directories.presetsScriptPath, "--rename", old, name]
        if (description !== undefined) {
            cmd.push(description)
        }
        renameProc.command = cmd
        renameProc.running = true
    }

    function save(rawInput) {
        const raw = rawInput.trim()
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
        GlobalStates.settingsOpen = false
        Wallpapers.confirmedPath = ""
        Wallpapers.previewPath = ""
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", name])
    }

    function remove(name) {
        deleteProc.command = ["bash", Directories.presetsScriptPath, "--remove", name]
        deleteProc.running = true
    }
}