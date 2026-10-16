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
    property alias onlineFolderModel: onlinePresetsFolderModel
    property alias importedFolderModel: importedPresetsFolderModel

    signal renamed(string oldName, string newName)

    FolderListModel {
        id: presetsFolderModel
        folder: Qt.resolvedUrl(Directories.userPresetsPath)
        showDirs: false
        nameFilters: ["*.json"]
    }

    FolderListModel {
        id: onlinePresetsFolderModel
        folder: Qt.resolvedUrl(`${Quickshell.env("HOME")}/.cache/quickshell/presets`)
        showDirs: false
        nameFilters: ["*.json"]
    }

    FolderListModel {
        id: importedPresetsFolderModel
        folder: Qt.resolvedUrl(`${Quickshell.env("HOME")}/.cache/quickshell/presets_imported`)
        showDirs: false
        nameFilters: ["*.json"]
    }

    function previewImage(data) {
        const background = data?.background
        const raw = background?.wallpaperPath ?? ""
        if (/\.(mp4|webm|mkv|avi|mov)$/i.test(raw)) return background?.thumbnailPath ?? ""
        if (background?.collage?.enable) {
            try {
                let node = JSON.parse(background.collage.tree)
                while (node.t !== "leaf") node = node.a
                if (node.img) return node.img
            } catch (e) {}
        }
        return raw
    }

    function refresh() {
        const current = presetsFolderModel.folder
        presetsFolderModel.folder = ""
        presetsFolderModel.folder = current
    }

    function refreshOnline() {
        const current = onlinePresetsFolderModel.folder
        onlinePresetsFolderModel.folder = ""
        onlinePresetsFolderModel.folder = current
    }

    function refreshImported() {
        const current = importedPresetsFolderModel.folder
        importedPresetsFolderModel.folder = ""
        importedPresetsFolderModel.folder = current
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
        property string oldName: ""
        stdout: StdioCollector { id: renameOut }
        onExited: code => {
            root.refresh()
            root.renamed(renameProc.oldName, code === 0 ? renameOut.text.trim() : "")
        }
    }

    Process {
        id: deleteOnlineProc
        onExited: root.refreshOnline()
    }

    Process {
        id: deleteImportedProc
        onExited: root.refreshImported()
    }

    Process {
        id: overwriteProc
        onExited: root.refresh()
    }

    Process {
        id: exportZipProc
    }

    Process {
        id: installProc
        stdout: StdioCollector { id: installOut }
        onExited: code => {
            root.refresh()
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Install failed"), Translation.tr("Could not copy the preset files")])
                return
            }
            const lines = installOut.text.trim().split("\n")
            const saved = lines[0].split("/").pop().replace(".json", "")
            const missingLine = lines.find(l => l.startsWith("missing: "))
            if (missingLine) {
                const files = missingLine.slice(9)
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Preset installed with missing images"), Translation.tr("Saved as \"%1\", but these files were not found: %2").arg(saved).arg(files)])
                return
            }
            Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Preset installed"), Translation.tr("Saved as \"%1\" in My presets. Wallpapers are in Pictures/Wallpapers.").arg(saved)])
        }
    }

    Process {
        id: publishPickProc
        property string presetName: ""
        stdout: StdioCollector { id: publishPickOut }
        onExited: code => {
            const picked = publishPickOut.text.trim()
            if (code !== 0 || picked === "") return
            publishPrepProc.presetName = publishPickProc.presetName
            publishPrepProc.command = ["bash", Directories.presetsScriptPath, "--export-zip", publishPickProc.presetName, "--folder", "--preview", picked]
            publishPrepProc.running = true
        }
    }

    Process {
        id: publishPrepProc
        property string presetName: ""
        onExited: code => {
            if (code === 3) {
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Can't upload this preset"), Translation.tr("It was installed from the gallery and belongs to its author")])
                return
            }
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Upload failed"), Translation.tr("Could not prepare the preset folder")])
                return
            }
            root.setupOffered = false
            root.startShare(publishPrepProc.presetName)
        }
    }

    property var sharedNames: []
    property var ownedCache: ({})
    readonly property string sharedFilePath: `${Directories.shellConfig}/shared_presets.json`

    function isPublished(name) {
        return root.sharedNames.includes(name) || root.ownedCache[name] === true
    }

    function rememberShared(name) {
        const cache = Object.assign({}, root.ownedCache)
        cache[name] = true
        root.ownedCache = cache
        if (root.sharedNames.includes(name)) return
        root.sharedNames = root.sharedNames.concat([name])
        sharedFile.setText(JSON.stringify(root.sharedNames))
    }

    function forgetShared(name) {
        const cache = Object.assign({}, root.ownedCache)
        cache[name] = false
        root.ownedCache = cache
        root.sharedNames = root.sharedNames.filter(entry => entry !== name)
        sharedFile.setText(JSON.stringify(root.sharedNames))
    }

    function checkOwnership(name) {
        if (ownedProc.running) return
        ownedProc.presetName = name
        ownedProc.command = ["bash", `${Directories.scriptPath}/preset_unshare.sh`, "owned", name]
        ownedProc.running = true
    }

    function unpublish(name) {
        if (unshareProc.running) return
        unshareProc.presetName = name
        unshareProc.command = ["bash", `${Directories.scriptPath}/preset_unshare.sh`, "remove", name]
        unshareProc.running = true
        Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Removing from the gallery"), Translation.tr("Opening a pull request to remove \"%1\"").arg(name)])
    }

    FileView {
        id: sharedFile
        path: root.sharedFilePath
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(sharedFile.text())
                if (Array.isArray(saved)) root.sharedNames = saved
            } catch (e) {}
        }
    }

    Process {
        id: ownedProc
        property string presetName: ""
        stdout: StdioCollector { id: ownedOut }
        onExited: code => {
            if (code !== 0) return
            const verdict = ownedOut.text.trim()
            if (verdict === "none") {
                root.forgetShared(ownedProc.presetName)
                return
            }
            const cache = Object.assign({}, root.ownedCache)
            cache[ownedProc.presetName] = verdict === "yes"
            root.ownedCache = cache
        }
    }

    Process {
        id: unshareProc
        property string presetName: ""
        stdout: StdioCollector { id: unshareOut }
        stderr: StdioCollector { id: unshareErr }
        onExited: code => {
            const name = unshareProc.presetName
            if (code === 0) {
                const link = unshareOut.text.trim().split("\n").pop()
                root.forgetShared(name)
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Removal sent"), Translation.tr("\"%1\" leaves the gallery once the pull request is merged.").arg(name)])
                Quickshell.execDetached(["xdg-open", link])
                return
            }
            if (code === 14) {
                root.forgetShared(name)
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Already removed"), Translation.tr("\"%1\" is not in the gallery").arg(name)])
                return
            }
            if (code === 10 || code === 11) {
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("GitHub sign in needed"), Translation.tr("Upload a preset once, or run gh auth login in a terminal")])
                return
            }
            Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Could not remove it"), unshareErr.text.trim() || Translation.tr("Could not open the pull request")])
        }
    }

    property bool setupOffered: false
    property int setupWaitTicks: 0
    property string setupPresetName: ""

    function startShare(name) {
        publishShareProc.presetName = name
        publishShareProc.command = ["bash", `${Directories.scriptPath}/preset_share.sh`, name]
        publishShareProc.running = true
        Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Uploading your preset"), Translation.tr("Opening a pull request for \"%1\"").arg(name)])
    }

    function dragFallback(name) {
        const folder = `${Quickshell.env("HOME")}/.cache/quickshell/presets_share/${name}`
        const repo = PresetsOnline.sources[0].repo
        Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Upload your preset"), Translation.tr("Drag the \"%1\" folder into the GitHub page and press Propose changes").arg(name)])
        Quickshell.execDetached(["xdg-open", folder])
        Quickshell.execDetached(["xdg-open", `https://github.com/${repo}/upload/main/presets`])
    }

    function startGithubSetup(name) {
        root.setupOffered = true
        root.setupPresetName = name
        root.setupWaitTicks = 0
        const script = StringUtils.shellSingleQuoteEscape(`${Directories.scriptPath}/preset_share_setup.sh`)
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} bash '${script}'`])
        Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("One-time GitHub setup"), Translation.tr("Finish the steps in the terminal. Your preset is sent right after.")])
        setupTimer.restart()
    }

    Timer {
        id: setupTimer
        interval: 3000
        repeat: true
        onTriggered: {
            root.setupWaitTicks += 1
            if (root.setupWaitTicks > 200) {
                setupTimer.stop()
                root.dragFallback(root.setupPresetName)
                return
            }
            if (!setupCheckProc.running) setupCheckProc.running = true
        }
    }

    Process {
        id: setupCheckProc
        command: ["gh", "auth", "status"]
        onExited: code => {
            if (code !== 0) return
            setupTimer.stop()
            root.startShare(root.setupPresetName)
        }
    }

    Process {
        id: publishShareProc
        property string presetName: ""
        stdout: StdioCollector { id: publishShareOut }
        stderr: StdioCollector { id: publishShareErr }
        onExited: code => {
            if (code === 0) {
                const link = publishShareOut.text.trim().split("\n").pop()
                root.rememberShared(publishShareProc.presetName)
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Preset sent"), Translation.tr("\"%1\" is waiting for its check. It appears in the gallery once it is merged.").arg(publishShareProc.presetName)])
                Quickshell.execDetached(["xdg-open", link])
                return
            }
            if (code === 13) {
                Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Nothing to upload"), Translation.tr("\"%1\" is already published with these exact files").arg(publishShareProc.presetName)])
                return
            }
            if (code === 10 || code === 11) {
                if (root.setupOffered) root.dragFallback(publishShareProc.presetName)
                else root.startGithubSetup(publishShareProc.presetName)
                return
            }
            Quickshell.execDetached(["notify-send", "-a", "Presets", Translation.tr("Upload failed"), publishShareErr.text.trim() || Translation.tr("Could not open the pull request")])
        }
    }

    Process {
        id: importZipProc
        onExited: root.refreshImported()
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
        Collage.armEntrance()
        Wallpapers.confirmedPath = ""
        Wallpapers.previewPath = ""
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", name])
    }

    function applyOnline(name) {
        GlobalStates.settingsOpen = false
        Collage.armEntrance()
        Wallpapers.confirmedPath = ""
        Wallpapers.previewPath = ""
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", name, "--online"])
    }

    function remove(name) {
        deleteProc.command = ["bash", Directories.presetsScriptPath, "--remove", name]
        deleteProc.running = true
    }

    function rename(name, newName) {
        renameProc.oldName = name
        renameProc.command = ["bash", Directories.presetsScriptPath, "--rename", name, newName.trim()]
        renameProc.running = true
    }

    function removeOnline(name) {
        deleteOnlineProc.command = ["bash", Directories.presetsScriptPath, "--remove", name, "--online"]
        deleteOnlineProc.running = true
    }

    function removeImported(name) {
        deleteImportedProc.command = ["bash", Directories.presetsScriptPath, "--remove", name, "--imported"]
        deleteImportedProc.running = true
    }

    function applyImported(name) {
        GlobalStates.settingsOpen = false
        Collage.armEntrance()
        Wallpapers.confirmedPath = ""
        Wallpapers.previewPath = ""
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", name, "--imported"])
    }

    function overwrite(name) {
        // Overwrite with same name (presets.sh --save filters General+Services)
        overwriteProc.command = ["bash", Directories.presetsScriptPath, "--save", name]
        overwriteProc.running = true
    }

    function exportZip(name) {
        exportZipProc.command = ["bash", Directories.presetsScriptPath, "--export-zip", name]
        exportZipProc.running = true
    }

    function install(name, source) {
        const cmd = ["bash", Directories.presetsScriptPath, "--install", name, source === "imported" ? "--imported" : "--online"]
        if (source !== "imported") cmd.push("--origin", PresetsOnline.originOf(name), "--as", PresetsOnline.displayName(name))
        installProc.command = cmd
        installProc.running = true
    }

    property bool uploadGuideOpen: false
    property string uploadGuideName: ""

    function publish(name) {
        if (!Config.options.profile.uploadGuideSeen) {
            root.uploadGuideName = name
            root.uploadGuideOpen = true
            return
        }
        root.pickPreview(name)
    }

    function confirmUploadGuide() {
        Config.options.profile.uploadGuideSeen = true
        root.uploadGuideOpen = false
        root.pickPreview(root.uploadGuideName)
    }

    function cancelUploadGuide() {
        root.uploadGuideOpen = false
    }

    function pickPreview(name) {
        const title = Translation.tr("Choose the preview image (a screenshot of your desktop)")
        const start = `${Quickshell.env("HOME")}/Pictures`
        publishPickProc.presetName = name
        publishPickProc.command = ["bash", "-c",
            'if command -v kdialog >/dev/null 2>&1; then kdialog --title "$1" --getopenfilename "$2" "Images (*.png *.jpg *.jpeg *.webp)"; else zenity --file-selection --title="$1" --filename="$2/" --file-filter="Images | *.png *.jpg *.jpeg *.webp"; fi',
            "pick", title, start]
        publishPickProc.running = true
    }

    function importZip(path) {
        const clean = String(path).replace(/^file:\/\//, "")
        importZipProc.command = ["bash", Directories.presetsScriptPath, "--import-zip", clean]
        importZipProc.running = true
    }
}
