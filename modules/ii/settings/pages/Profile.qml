import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ContentPage {
    id: page
    property string descriptionMode: {
        if (Config.options.profile.descriptionText === "::uptime::") return "uptime"
        return "distro"
    }
    property string hostnameInput: SystemInfo.hostname

    property list<var> onlinePresets: []
    property string onlinePresetsError: ""
    property bool onlinePresetsLoading: false

    property var pendingOnlinePresets: {
        const downloadedNames = new Set()
        for (let i = 0; i < Presets.onlineFolderModel.count; i++) {
            downloadedNames.add(Presets.onlineFolderModel.get(i, "fileName").replace(".json", ""))
        }
        return page.onlinePresets.filter(p => !downloadedNames.has(p.name))
    }

    function refreshOnlinePresets() {
        page.onlinePresetsLoading = true
        page.onlinePresetsError = ""
        onlinePresetsListProc.running = true
    }

    function rawPresetUrl(path) {
        return `https://raw.githubusercontent.com/Blapples/wallpapers/main/${path.split("/").map(encodeURIComponent).join("/")}`
    }

    function onlinePresetsDir() {
        return `${Quickshell.env("HOME")}/.cache/quickshell/presets`
    }

    function assetCacheDir(name) {
        return `${page.onlinePresetsDir()}/assets/${name}`
    }

    function shQuote(str) {
        return "'" + String(str).replace(/'/g, "'\"'\"'") + "'"
    }

    function startOnlineAssetsFetch(name, stagingJsonPath, folderAssets, wallpaperFiles) {
        const dir = page.assetCacheDir(name)
        presetAssetsFetchProc.entryName = name
        presetAssetsFetchProc.stagingJsonPath = stagingJsonPath
        presetAssetsFetchProc.assetCacheDirPath = dir

        const wallpaperAssets = wallpaperFiles.map(f => ({ filename: f.split("/").pop(), url: page.rawPresetUrl(f) }))
        const seen = new Set()
        const toDownload = [...wallpaperAssets, ...folderAssets].filter(a => {
            if (seen.has(a.filename)) return false
            seen.add(a.filename)
            return true
        })
        presetAssetsFetchProc.assetFilenames = toDownload.map(a => a.filename)

        let cmd = `mkdir -p ${page.shQuote(dir)}`
        for (const asset of toDownload) {
            cmd += ` && curl -sSL ${page.shQuote(asset.url)} -o ${page.shQuote(dir + "/" + asset.filename)}`
        }
        presetAssetsFetchProc.command = ["bash", "-c", cmd]
        presetAssetsFetchProc.running = true
    }

    function downloadOnlinePreset(entry) {
        page.onlinePresetsError = ""
        const stagingJsonPath = `${page.onlinePresetsDir()}/.${entry.name}.online.json.tmp`
        presetJsonFetchProc.entryName = entry.name
        presetJsonFetchProc.entryAssets = entry.assets
        presetJsonFetchProc.metaUrl = entry.metaUrl
        presetJsonFetchProc.stagingJsonPath = stagingJsonPath
        presetJsonFetchProc.command = ["bash", "-c",
            `mkdir -p ${page.shQuote(page.onlinePresetsDir())} && curl -sSL ${page.shQuote(entry.jsonUrl)} -o ${page.shQuote(stagingJsonPath)}`]
        presetJsonFetchProc.running = true
    }

    Component.onCompleted: {
        if (Config.options.profile.onlinePresets) page.refreshOnlinePresets()
    }

    FolderListModel {
        id: avatarFolderModel
        folder: Config.options.profile.avatarPath !== "" ? Qt.resolvedUrl(Config.options.profile.avatarPath) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
    }

    Process {
        id: hostnameSetProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                SystemInfo.refreshHostname()
            }
        }
    }

    Process {
        id: onlinePresetsListProc
        command: ["curl", "-sSL", "-w", "\nHTTP_STATUS:%{http_code}",
            "-H", "Accept: application/vnd.github+json",
            "-H", "User-Agent: end4-pC-quickshell",
            "https://api.github.com/repos/Blapples/wallpapers/git/trees/main?recursive=1"]
        stdout: StdioCollector { id: onlinePresetsListCollector }
        onExited: (code) => {
            page.onlinePresetsLoading = false
            const raw = onlinePresetsListCollector.text
            console.log("[onlinePresets] curl exit code:", code)
            const statusMatch = raw.match(/HTTP_STATUS:(\d+)\s*$/)
            const httpStatus = statusMatch ? parseInt(statusMatch[1]) : -1
            const body = statusMatch ? raw.slice(0, statusMatch.index) : raw
            console.log("[onlinePresets] http status:", httpStatus)
            try {
                const data = JSON.parse(body)
                if (!Array.isArray(data.tree)) throw new Error("unexpected response: " + JSON.stringify(data))

                const prefix = "presets/"
                const imageExt = /\.(png|jpe?g|webp)$/i
                const groups = {}

                for (const entry of data.tree) {
                    if (entry.type !== "blob") continue
                    if (!entry.path.startsWith(prefix)) continue
                    const rel = entry.path.slice(prefix.length)
                    const slashIdx = rel.indexOf("/")
                    if (slashIdx === -1) continue
                    const folder = rel.slice(0, slashIdx)
                    const filename = rel.slice(slashIdx + 1)
                    if (filename.includes("/")) continue

                    if (!groups[folder]) groups[folder] = { images: [], assets: [], jsonPath: "", metaPath: "" }
                    if (filename.toLowerCase() === "meta.json") {
                        groups[folder].metaPath = entry.path
                    } else if (/\.json$/i.test(filename)) {
                        groups[folder].jsonPath = entry.path
                    } else {
                        groups[folder].assets.push({ path: entry.path, filename })
                        if (imageExt.test(filename)) {
                            groups[folder].images.push({ path: entry.path, filename })
                        }
                    }
                }

                const presets = []
                for (const folder in groups) {
                    const g = groups[folder]
                    if (!g.jsonPath || g.images.length === 0) continue

                    const exactPreview = /^preview\.png$/i
                    const genericPreview = /^preview?\.png$/i
                    const nonGeneric = g.images.filter(img => !genericPreview.test(img.filename))
                    const mainCandidates = nonGeneric.length > 0 ? nonGeneric : g.images

                    const main = g.images.find(img => exactPreview.test(img.filename))
                        || mainCandidates.find(img => /desktop/i.test(img.filename))
                        || mainCandidates.find(img => !/pfp|avatar|banner/i.test(img.filename))
                        || mainCandidates[0]

                    presets.push({
                        name: folder,
                        title: folder.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase()),
                        jsonUrl: page.rawPresetUrl(g.jsonPath),
                        metaUrl: g.metaPath ? page.rawPresetUrl(g.metaPath) : "",
                        screenshot: page.rawPresetUrl(main.path),
                        assets: g.assets.map(a => ({ filename: a.filename, url: page.rawPresetUrl(a.path) })),
                    })
                }
                presets.sort((a, b) => a.title.localeCompare(b.title))
                page.onlinePresets = presets
            } catch (e) {
                console.log("[onlinePresets] parse error:", e)
                page.onlinePresets = []
                page.onlinePresetsError = Translation.tr("Failed to load online presets")
            }
        }
    }

    Process {
        id: presetJsonFetchProc
        property string entryName: ""
        property var entryAssets: []
        property string metaUrl: ""
        property string stagingJsonPath: ""
        onExited: (code) => {
            console.log("[presetDownload] json fetch exit code:", code)
            if (code !== 0) {
                page.onlinePresetsError = Translation.tr("Failed to download preset")
                return
            }
            if (presetJsonFetchProc.metaUrl !== "") {
                presetMetaFetchProc.entryName = presetJsonFetchProc.entryName
                presetMetaFetchProc.entryAssets = presetJsonFetchProc.entryAssets
                presetMetaFetchProc.stagingJsonPath = presetJsonFetchProc.stagingJsonPath
                presetMetaFetchProc.command = ["curl", "-sSL", presetJsonFetchProc.metaUrl]
                presetMetaFetchProc.running = true
            } else {
                page.startOnlineAssetsFetch(presetJsonFetchProc.entryName, presetJsonFetchProc.stagingJsonPath, presetJsonFetchProc.entryAssets, [])
            }
        }
    }

    Process {
        id: presetMetaFetchProc
        property string entryName: ""
        property var entryAssets: []
        property string stagingJsonPath: ""
        stdout: StdioCollector { id: presetMetaCollector }
        onExited: (code) => {
            let wallpaperFiles = []
            if (code === 0) {
                try {
                    const meta = JSON.parse(presetMetaCollector.text)
                    if (Array.isArray(meta.wallpapers)) wallpaperFiles = meta.wallpapers
                } catch (e) {
                    console.log("[presetDownload] meta.json parse error:", e)
                }
            } else {
                console.log("[presetDownload] meta.json fetch exit code:", code)
            }
            page.startOnlineAssetsFetch(presetMetaFetchProc.entryName, presetMetaFetchProc.stagingJsonPath, presetMetaFetchProc.entryAssets, wallpaperFiles)
        }
    }

    Process {
        id: presetAssetsFetchProc
        property string entryName: ""
        property string stagingJsonPath: ""
        property string assetCacheDirPath: ""
        property var assetFilenames: []
        onExited: (code) => {
            console.log("[presetDownload] assets fetch exit code:", code)
            if (code !== 0) {
                page.onlinePresetsError = Translation.tr("Failed to download preset assets")
                return
            }
            const finalJsonPath = `${page.onlinePresetsDir()}/${presetAssetsFetchProc.entryName}.json`
            const jqFilter = '$files as $files | walk(if type == "string" then ((split("/") | last) as $base | if ($files | index($base)) then ($dir + "/" + $base) else . end) else . end) | if has("profile") then .profile.avatarPath = $dir else . end | ._presetMeta.source = "online"'
            const filesJson = JSON.stringify(presetAssetsFetchProc.assetFilenames)
            const cmd = `jq --arg dir ${page.shQuote(presetAssetsFetchProc.assetCacheDirPath)} --argjson files ${page.shQuote(filesJson)} ${page.shQuote(jqFilter)} ${page.shQuote(presetAssetsFetchProc.stagingJsonPath)} > ${page.shQuote(finalJsonPath)} && rm -f ${page.shQuote(presetAssetsFetchProc.stagingJsonPath)}`
            presetRewriteProc.command = ["bash", "-c", cmd]
            presetRewriteProc.running = true
        }
    }

    Process {
        id: presetRewriteProc
        onExited: (code) => {
            console.log("[presetDownload] rewrite exit code:", code)
            if (code === 0) {
                Presets.refreshOnline()
            } else {
                page.onlinePresetsError = Translation.tr("Failed to finalize preset")
            }
        }
    }

    function applyHostname() {
        const newName = page.hostnameInput.trim()
        if (newName.length === 0 || newName === SystemInfo.hostname) return
        hostnameSetProc.command = ["hostnamectl", "set-hostname", newName]
        hostnameSetProc.running = true
    }

    Connections {
        target: SystemInfo
        function onHostnameChanged() {
            hostnameField.value = Qt.binding(() => SystemInfo.hostname)
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "person"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Avatar")

            GroupedList {
                ConfigTextArea {
                    id: avatarField
                    Layout.fillWidth: true
                    buttonIcon: "folder_open"
                    text: Translation.tr("Avatar path")
                    placeholderText: Translation.tr("Leave empty to use ~/.face, e.g. /home/youruser/Pictures/avatar")
                    value: Config.options.profile.avatarPath
                    onValueChanged: {
                        avatarDebounceTimer.restart()
                    }

                    Timer {
                        id: avatarDebounceTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            Config.options.profile.avatarPath = avatarField.value
                        }
                    }

                    confirmButtonVisible: Config.options.profile.avatarPath !== ""
                    confirmButtonIcon: "add"
                    onConfirmClicked: {
                        GlobalStates.settingsOpen = false
                        if (Config.options.profile.avatarPath !== "") {
                            Quickshell.execDetached(["dolphin", Config.options.profile.avatarPath])
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Config.options.profile.avatarPath === "" ? placeholderCol.implicitHeight : avatarFlow.implicitHeight

                    Flow {
                        id: avatarFlow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Repeater {
                            model: avatarFolderModel
                            delegate: Rectangle {
                                required property string fileName
                                required property string filePath
                                width: 64
                                height: 64
                                radius: width / 2
                                color: Appearance.colors.colLayer2

                                property bool isSelected: FileUtils.trimFileProtocol(filePath.toString()) === Config.options.profile.avatarPicture

                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    source: filePath
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: avatarImage.width * 2
                                    sourceSize.height: avatarImage.height * 2
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 64; height: width; radius: width / 2 
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: parent.isSelected
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 2
                                    anchors.bottomMargin: 2
                                    width: 20
                                    height: width
                                    radius: width / 2
                                    color: Appearance.colors.colPrimary

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.options.profile.avatarPicture = FileUtils.trimFileProtocol(filePath.toString())
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: placeholderCol
                        visible: Config.options.profile.avatarPath === ""
                        anchors.centerIn: parent
                        z: 1
                        spacing: 4

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "image"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Pick a folder above to see avatars here")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Identity")

                GroupedList {
                    ConfigTextArea {
                        id: displayNameField
                        buttonIcon: "badge"
                        placeholderText: SystemInfo.username
                        text: Translation.tr("Display name")
                        value: Config.options.profile.displayName

                        Timer {
                            id: displayNameDebounceTimer
                            interval: 800
                            running: false
                            onTriggered: {
                                Config.options.profile.displayName = displayNameField.value
                            }
                        }
                        onValueChanged: displayNameDebounceTimer.restart()
                    }

                    ConfigTextArea {
                        id: hostnameField
                        Layout.fillWidth: true
                        buttonIcon: "dns"
                        placeholderText: SystemInfo.hostname
                        text: Translation.tr("Hostname")
                        description: Translation.tr("Requires authentication to change")
                        value: page.hostnameInput
                        onValueChanged: page.hostnameInput = value

                        confirmButtonVisible: page.hostnameInput.trim() !== "" && page.hostnameInput.trim() !== SystemInfo.hostname
                        onConfirmClicked: {
                            page.applyHostname();
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Description text")
                        icon: "subtitles"
                        currentValue: page.descriptionMode
                        onSelected: newValue => {
                            page.descriptionMode = newValue
                            if (newValue === "distro") Config.options.profile.descriptionText = "::distro::"
                            if (newValue === "uptime") Config.options.profile.descriptionText = "::uptime::"
                        }
                        options: [
                            { displayName: Translation.tr("Distro"), icon: "deployed_code", value: "distro" },
                            { displayName: Translation.tr("Uptime"), icon: "timelapse",     value: "uptime" },
                        ]
                    }
                }
            }
        }

        ContentSection {
            icon: "wall_art"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Presets")

            GroupedList {
                ConfigTextArea {
                    id: presetNameField
                    Layout.fillWidth: true
                    fieldWidth: 300
                    buttonIcon: "newsmode"
                    text: Translation.tr("Save as")
                    placeholderText: Translation.tr("Name, description (optional)")

                    confirmButtonVisible: presetNameField.value.trim() !== ""
                    confirmButtonIcon: "save"
                    onConfirmClicked: {
                        Presets.save(presetNameField.value)
                        presetNameField.value = ""
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colRipple: Appearance.colors.colLayer1Active
                    horizontalPadding: 8
                    onClicked: importDialog.open()
                    contentItem: RowLayout {
                        spacing: 10
                        MaterialSymbol {
                            text: "upload"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Import ZIP")
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "cloud_download"
                    text: Translation.tr("Show online presets")
                    checked: Config.options.profile.onlinePresets
                    onCheckedChanged: {
                        Config.options.profile.onlinePresets = checked
                        if (checked) page.refreshOnlinePresets()
                    }
                }
            }

            Loader {
                id: importDialogLoader
                active: false
                sourceComponent: Item {
                    // Use kdialog like wallpaper selector for consistency, fallback to Qt dialog
                    Component.onCompleted: {
                        const proc = importFilePicker
                        proc.command = ["kdialog", "--getopenfilename", Quickshell.env("HOME"), "*.zip | Preset ZIP"]
                        proc.running = true
                    }
                    Process {
                        id: importFilePicker
                        stdout: StdioCollector { id: importCollector }
                        onExited: (code) => {
                            const path = importCollector.text.trim()
                            if (code === 0 && path.length > 0) Presets.importZip(path)
                            importDialogLoader.active = false
                        }
                    }
                }
            }
            // Helper to trigger
            Item { id: importDialog; function open(){ importDialogLoader.active = true } }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: Presets.folderModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No presets yet")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Flow {
                Layout.topMargin: 10
                Layout.fillWidth: true
                width: parent.width
                spacing: 12
                visible: Presets.folderModel.count > 0

                Repeater {
                    model: Presets.folderModel
                    delegate: PresetsCard {
                        id: presetDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: fileName.replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        FileView {
                            path: presetDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text())
                                    const rawWallpaper = data?.background?.wallpaperPath ?? ""
                                    const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper)
                                    presetDelegate.presetWallpaper = isVideo
                                        ? (data?.background?.thumbnailPath ?? "")
                                        : rawWallpaper
                                    presetDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                } catch (e) {
                                    console.log("Failed to parse preset:", e)
                                }
                            }
                        }

                        imageSource: presetDelegate.presetWallpaper
                        title: presetDelegate.presetName
                        description: presetDelegate.presetDescription !== "" ? presetDelegate.presetDescription : Translation.tr("Saved preset")
                        onApply: () => Presets.apply(presetDelegate.presetName)
                        onRemove: () => Presets.remove(presetDelegate.presetName)
                        onOverwrite: () => Presets.overwrite(presetDelegate.presetName)
                        onExportZip: () => Presets.exportZip(presetDelegate.presetName)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Downloaded")
                visible: Presets.onlineFolderModel.count > 0

                Flow {
                    Layout.fillWidth: true
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: Presets.onlineFolderModel
                        delegate: PresetsCard {
                            id: onlineDelegate
                            required property string fileName
                            required property string filePath

                            property string presetName: fileName.replace(".json", "")
                            property string presetWallpaper: ""
                            property string presetDescription: ""

                            FileView {
                                path: onlineDelegate.filePath
                                onLoaded: {
                                    try {
                                        const data = JSON.parse(text())
                                        const rawWallpaper = data?.background?.wallpaperPath ?? ""
                                        const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper)
                                        onlineDelegate.presetWallpaper = isVideo
                                            ? (data?.background?.thumbnailPath ?? "")
                                            : rawWallpaper
                                        onlineDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                    } catch (e) {
                                        console.log("Failed to parse online preset:", e)
                                    }
                                }
                            }

                            imageSource: onlineDelegate.presetWallpaper
                            title: onlineDelegate.presetName
                            description: onlineDelegate.presetDescription !== "" ? onlineDelegate.presetDescription : Translation.tr("Downloaded preset")
                            onApply: () => Presets.applyOnline(onlineDelegate.presetName)
                            onRemove: () => Presets.removeOnline(onlineDelegate.presetName)
                            onOverwrite: () => Presets.overwrite(onlineDelegate.presetName)
                            onExportZip: () => Presets.exportZip(onlineDelegate.presetName)
                        }
                    }
                }
            }

        }

        ContentSection {
            icon: "upload"
            shape: MaterialShape.Shape.Slanted
            title: Translation.tr("Imported")
            visible: Presets.importedFolderModel.count > 0

            Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 12

                Repeater {
                    model: Presets.importedFolderModel
                    delegate: PresetsCard {
                        id: importedDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: fileName.replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        FileView {
                            path: importedDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text())
                                    const rawWallpaper = data?.background?.wallpaperPath ?? ""
                                    const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper)
                                    importedDelegate.presetWallpaper = isVideo
                                        ? (data?.background?.thumbnailPath ?? "")
                                        : rawWallpaper
                                    importedDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                } catch (e) {
                                    console.log("Failed to parse imported preset:", e)
                                }
                            }
                        }

                        imageSource: importedDelegate.presetWallpaper
                        title: importedDelegate.presetName
                        description: importedDelegate.presetDescription !== "" ? importedDelegate.presetDescription : Translation.tr("Imported preset")
                        onApply: () => Presets.applyImported(importedDelegate.presetName)
                        onRemove: () => Presets.removeImported(importedDelegate.presetName)
                        onOverwrite: () => Presets.overwrite(importedDelegate.presetName)
                        onExportZip: () => Presets.exportZip(importedDelegate.presetName)
                    }
                }
            }
        }

        ContentSection {
            icon: "link_2"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Browse Online")
            visible: Config.options.profile.onlinePresets

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                GroupedList {
                    RippleButton {
                        id: refreshOnlineBtn
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        implicitHeight: refreshContentItem.implicitHeight + 8
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: page.refreshOnlinePresets()

                        contentItem: RowLayout {
                            id: refreshContentItem
                            spacing: 10

                            OptionalMaterialSymbol {
                                icon: "cloud_download"
                                iconSize: Appearance.font.pixelSize.larger
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "blapples.github.io"
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            MaterialSymbol {
                                text: "refresh"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        MaterialSymbol {
                            text: page.onlinePresetsError !== "" ? "error" : "wallpaper"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            text: page.onlinePresetsError !== ""
                                ? page.onlinePresetsError
                                : (page.pendingOnlinePresets.length + " " + Translation.tr("presets available"))
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    width: parent.width
                    spacing: 8
                    visible: page.pendingOnlinePresets.length > 0

                    Repeater {
                        model: page.pendingOnlinePresets
                        delegate: Rectangle {
                            id: onlineCard
                            required property var modelData
                            implicitWidth: 293
                            implicitHeight: 186
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    id: onlineImageRect
                                    Layout.fillWidth: true
                                    implicitHeight: 130
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colors.colLayer2

                                    StyledImage {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: onlineCard.modelData.screenshot
                                        cache: false
                                        antialiasing: true
                                        sourceSize.width: onlineImageRect.width * 2
                                        sourceSize.height: onlineImageRect.height * 2
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("[onlineCard] failed to load image:", onlineCard.modelData.name, source)
                                            }
                                        }
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Item {
                                                width: onlineImageRect.width
                                                height: onlineImageRect.height
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: onlineImageRect.radius
                                                }
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: onlineImageRect.radius
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.margins: 10
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: onlineCard.modelData.title
                                        elide: Text.ElideRight
                                        color: Appearance.colors.colOnLayer1
                                    }

                                    RippleButton {
                                        implicitWidth: 32; implicitHeight: 32
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colPrimary
                                        colBackgroundHover: Appearance.colors.colPrimaryHover
                                        colRipple: Appearance.colors.colPrimaryActive
                                        downAction: () => page.downloadOnlinePreset(onlineCard.modelData)

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "download"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colOnPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}