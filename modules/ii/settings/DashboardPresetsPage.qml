import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property Item pager
    property int staggerMs: 45
    property string source: "mine"
    property var selected: null

    readonly property var sources: [
        { id: "mine", name: Translation.tr("My presets"), icon: "person", model: Presets.folderModel, count: Presets.folderModel.count },
        { id: "downloaded", name: Translation.tr("Downloaded"), icon: "cloud_download", model: Presets.onlineFolderModel, count: Presets.onlineFolderModel.count },
        { id: "imported", name: Translation.tr("Imported"), icon: "upload", model: Presets.importedFolderModel, count: Presets.importedFolderModel.count },
        { id: "online", name: Translation.tr("Browse online"), icon: "public", model: null, count: PresetsOnline.pending.length }
    ]
    readonly property var currentModel: sources.find(s => s.id === source).model
    readonly property bool onlineEnabled: Config.options.profile.onlinePresets
    readonly property string query: pager.searchQuery ?? ""
    readonly property var tokens: Wallpapers.normalizeText(query).split(/\s+/).filter(t => t.length > 0)

    function rankBy(items, keyOf) {
        if (tokens.length === 0) return items;
        const scored = [];
        items.forEach(item => {
            const key = Wallpapers.normalizeText(keyOf(item)).replace(/[_\-.]+/g, " ");
            const score = Wallpapers.scoreItem(key, tokens);
            if (score >= 0) scored.push({ item: item, score: score });
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.map(e => e.item);
    }

    function rankOnline(items) {
        if (tokens.length === 0) return items;
        const forceAuthor = tokens.some(t => t.startsWith("@"));
        const plain = tokens.map(t => t.replace(/^@+/, "")).filter(t => t.length > 0);
        if (plain.length === 0) return items;
        const scored = [];
        items.forEach(entry => {
            const nameKey = Wallpapers.normalizeText(entry.title + " " + entry.name.replace(/^[^\s]+?--/, "")).replace(/[_\-.]+/g, " ");
            const authorKey = Wallpapers.normalizeText(entry.author ?? "").replace(/[_\-.]+/g, " ");
            if (!forceAuthor) {
                const nameScore = Wallpapers.scoreItem(nameKey, plain);
                if (nameScore >= 0) {
                    scored.push({ item: entry, score: 2000 + nameScore });
                    return;
                }
            }
            if (authorKey !== "") {
                const authorScore = Wallpapers.scoreItem(authorKey, plain);
                if (authorScore >= 0) {
                    scored.push({ item: entry, score: authorScore });
                    return;
                }
                if (!forceAuthor) {
                    const mixedScore = Wallpapers.scoreItem(nameKey + " " + authorKey, plain);
                    if (mixedScore >= 0) scored.push({ item: entry, score: 1000 + mixedScore });
                }
            }
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.map(e => e.item);
    }

    readonly property var localEntries: {
        const model = currentModel;
        if (!model) return [];
        const items = [];
        for (let i = 0; i < model.count; i++)
            items.push({ fileName: model.get(i, "fileName"), filePath: model.get(i, "filePath") });
        return rankBy(items, item => item.fileName.replace(".json", ""));
    }

    readonly property var onlineEntries: rankOnline(PresetsOnline.pending)
    readonly property int columns: Math.max(2, Math.round(width / 340))

    readonly property var barPositions: [Translation.tr("Top"), Translation.tr("Bottom"), Translation.tr("Left"), Translation.tr("Right")]
    readonly property var barStyles: ["Hug", "Float", "Islands", "M3", "M3 Hug", "Panel", "Split Hug"]

    function summaryOf(data) {
        const bar = data?.bar ?? {};
        const position = (bar.bottom ? 1 : 0) | (bar.vertical ? 2 : 0);
        const palette = data?.appearance?.palette ?? {};
        const named = palette.namedScheme ?? "";
        const paletteType = (palette.type ?? "auto").replace("scheme-", "").replace(/-/g, " ");
        const clockStyle = data?.background?.widgets?.clock?.style ?? "";
        return {
            description: data?._presetMeta?.description ?? "",
            origin: data?._presetMeta?.origin ?? "",
            wallpaper: Presets.previewImage(data),
            vertical: bar.vertical ?? false,
            bottom: bar.bottom ?? false,
            cornerStyle: bar.cornerStyle ?? 0,
            barPosition: barPositions[position],
            barStyle: barStyles[bar.cornerStyle ?? 0] ?? "",
            palette: named !== "" ? (ColorSchemes.schemes[named]?.name ?? named) : paletteType.charAt(0).toUpperCase() + paletteType.slice(1),
            clock: clockStyle.charAt(0).toUpperCase() + clockStyle.slice(1),
            dock: data?.dock?.enable ?? false,
            blur: data?.background?.showBlur ?? false,
            leftLayout: Array.from(bar.layouts?.leftLayout ?? []),
            middleLayout: Array.from(bar.layouts?.middleLayout ?? []),
            rightLayout: Array.from(bar.layouts?.rightLayout ?? [])
        };
    }

    function applyPreset(preset) {
        if (preset.source === "downloaded") Presets.applyOnline(preset.name);
        else if (preset.source === "imported") Presets.applyImported(preset.name);
        else Presets.apply(preset.name);
    }

    function removePreset(preset) {
        if (preset.source === "downloaded") Presets.removeOnline(preset.name);
        else if (preset.source === "imported") Presets.removeImported(preset.name);
        else Presets.remove(preset.name);
    }

    property bool leaving: false

    function back() {
        if (selected === null || leaving) return;
        leaving = true;
        detailLoader.item?.requestExit();
        leaveTimer.restart();
    }

    Timer {
        id: leaveTimer
        interval: 340
        onTriggered: {
            root.selected = null;
            root.leaving = false;
        }
    }

    function enableOnline() {
        Config.options.profile.onlinePresets = true;
        PresetsOnline.refresh();
    }

    onSourceChanged: {
        if (source === "online" && onlineEnabled) PresetsOnline.ensureFresh();
    }

    Connections {
        target: PresetsOnline
        function onPendingChanged() {
            if (root.selected && root.selected.source === "online" && !PresetsOnline.pending.some(p => p.name === root.selected.name)) {
                root.selected = null;
                root.source = "downloaded";
            }
        }
    }

    Process {
        id: importPicker
        command: ["kdialog", "--getopenfilename", Quickshell.env("HOME"), "*.zip | Preset ZIP"]
        stdout: StdioCollector { id: importOutput }
        onExited: code => {
            const path = importOutput.text.trim();
            if (code === 0 && path.length > 0) {
                Presets.importZip(path);
                root.source = "imported";
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        opacity: root.selected === null || root.leaving ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.sources

                delegate: RippleButton {
                    id: sourceButton
                    required property var modelData

                    readonly property bool active: root.source === modelData.id

                    implicitHeight: 44
                    horizontalPadding: 18
                    buttonRadius: 22
                    toggled: active
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colBackgroundToggled: Appearance.colors.colPrimary
                    colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                    downAction: () => {
                        const id = modelData.id;
                        Qt.callLater(() => { root.source = id; });
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: sourceButton.modelData.icon
                            iconSize: 20
                            fill: sourceButton.active ? 1 : 0
                            color: sourceButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: sourceButton.modelData.name
                            font.weight: Font.Medium
                            color: sourceButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                        Rectangle {
                            implicitWidth: Math.max(22, countText.implicitWidth + 12)
                            implicitHeight: 22
                            radius: 11
                            color: sourceButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colSecondaryContainer

                            StyledText {
                                id: countText
                                anchors.centerIn: parent
                                text: sourceButton.modelData.count
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: sourceButton.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSecondaryContainer
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                visible: root.source === "online" && root.onlineEnabled
                text: PresetsOnline.error !== "" ? PresetsOnline.error
                    : PresetsOnline.loading ? Translation.tr("Loading…")
                    : PresetsOnline.pending.length + " " + Translation.tr("presets available")
                font.pixelSize: Appearance.font.pixelSize.small
                color: PresetsOnline.error !== "" ? Appearance.colors.colError : Appearance.colors.colSubtext
            }

            RippleButton {
                visible: root.source === "online" && root.onlineEnabled
                implicitWidth: 44
                implicitHeight: 44
                buttonRadius: 22
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                downAction: () => Qt.callLater(() => PresetsOnline.refresh())
                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 22
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }

            Rectangle {
                visible: root.source === "mine"
                Layout.fillWidth: true
                Layout.maximumWidth: 330
                Layout.minimumWidth: 160
                implicitHeight: 44
                radius: 22
                color: Appearance.colors.colLayer1
                border.width: saveInput.activeFocus ? 2 : 0
                border.color: Appearance.colors.colPrimary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 4
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: saveInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.main
                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimary
                            onAccepted: root.saveCurrent()
                            Keys.onEscapePressed: {
                                focus = false;
                                root.pager.forceActiveFocus();
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: saveInput.text === "" && !saveInput.activeFocus
                                text: Translation.tr("Save current setup as…  name, description")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: 18
                        enabled: saveInput.text.trim() !== ""
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        downAction: () => Qt.callLater(() => root.saveCurrent())
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "save"
                                iconSize: 20
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }

            RippleButton {
                id: importButton
                visible: root.source !== "online"
                implicitWidth: 44
                implicitHeight: 44
                buttonRadius: 22
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                downAction: () => Qt.callLater(() => { importPicker.running = true; })
                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "upload_file"
                        iconSize: 22
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    StyledToolTip {
                        extraVisibleCondition: false
                        alternativeVisibleCondition: importButton.hovered
                        text: Translation.tr("Import ZIP")
                    }
                }
            }
        }

        GridView {
            id: grid
            visible: root.source !== "online"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: Math.floor(width / root.columns)
            cellHeight: Math.max(120, Math.floor(height / 2))
            cacheBuffer: 0
            model: root.source === "online" ? [] : root.localEntries

            delegate: Item {
                id: cell
                required property int index
                required property var modelData

                readonly property string fileName: modelData.fileName
                readonly property string filePath: modelData.filePath
                readonly property string presetName: fileName.replace(".json", "")
                property var summary: ({})
                property bool loaded: false

                width: grid.cellWidth
                height: grid.cellHeight

                FileView {
                    path: cell.filePath
                    onLoaded: {
                        try {
                            cell.summary = root.summaryOf(JSON.parse(text()));
                            cell.loaded = true;
                            PresetThumbs.request(cell.summary.wallpaper);
                        } catch (e) {
                            cell.summary = {};
                        }
                    }
                }

                DashboardCard {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 6
                    tint: Appearance.colors.colLayer1
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: cell.index % 6
                    travelX: 0
                    travelY: 90

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: card.cardRadius
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: PresetThumbs.thumbFor(cell.summary.wallpaper) || (cell.summary.wallpaper ?? "")
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(560, 380)
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: cell.loaded && !(cell.summary.wallpaper ?? "")
                            text: "wallpaper"
                            iconSize: 64
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.35
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * 0.55
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.78) }
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: PresetsOnline.displayName(cell.presetName).replace(/_/g, " ")
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.DemiBold
                                color: "white"
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: (cell.summary.description ?? "") !== ""
                                text: cell.summary.description ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Qt.rgba(1, 1, 1, 0.78)
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            Repeater {
                                model: [
                                    { icon: "toast", on: cell.loaded },
                                    { icon: "dock_to_bottom", on: cell.summary.dock ?? false },
                                    { icon: "blur_on", on: cell.summary.blur ?? false }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    visible: modelData.on
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: Qt.rgba(0, 0, 0, 0.5)

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        iconSize: 16
                                        color: "white"
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selected = { name: cell.presetName, source: root.source, summary: cell.summary, wallpaper: cell.summary.wallpaper ?? "" };
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.source !== "online" && root.localEntries.length === 0
                text: root.tokens.length > 0 ? Translation.tr("No presets match your search") : Translation.tr("No presets here yet")
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }
        }

        Item {
            visible: root.source === "online"
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: onlineGrid
                anchors.fill: parent
                visible: root.onlineEnabled
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: Math.floor(width / root.columns)
                cellHeight: Math.max(120, Math.floor(height / 2))
                cacheBuffer: 0
                model: root.source === "online" ? root.onlineEntries : []

                delegate: Item {
                    id: onlineCell
                    required property int index
                    required property var modelData

                    readonly property bool busy: PresetsOnline.downloadingName === modelData.name

                    width: onlineGrid.cellWidth
                    height: onlineGrid.cellHeight

                    DashboardCard {
                        id: onlineCard
                        anchors.fill: parent
                        anchors.margins: 6
                        tint: Appearance.colors.colLayer1
                        pager: root.pager
                        staggerMs: root.staggerMs
                        animIndex: onlineCell.index % 6
                        travelX: 0
                        travelY: 90

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: onlineCard.cardRadius
                            color: "transparent"

                            Image {
                                id: remoteImage
                                property bool finished: false
                                anchors.fill: parent
                                source: {
                                    const local = PresetsOnline.thumbFor(onlineCell.modelData);
                                    if (local !== "") return local;
                                    return onlineCell.index < PresetsOnline.previewLimit ? onlineCell.modelData.screenshot : "";
                                }
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize: Qt.size(560, 380)
                                onStatusChanged: {
                                    if (!finished && (status === Image.Ready || status === Image.Error)) {
                                        finished = true;
                                        PresetsOnline.previewLimit += 1;
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.55
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.78) }
                                }
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 14
                                spacing: 4

                                StyledText {
                                    Layout.fillWidth: true
                                    text: onlineCell.modelData.title
                                    font.pixelSize: Appearance.font.pixelSize.larger
                                    font.weight: Font.DemiBold
                                    color: "white"
                                    elide: Text.ElideRight
                                }

                                PresetAuthorChip {
                                    Layout.fillWidth: true
                                    author: onlineCell.modelData.author ?? ""
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selected = { name: onlineCell.modelData.name, source: "online", summary: ({}), wallpaper: onlineCell.modelData.screenshot, thumb: PresetsOnline.thumbFor(onlineCell.modelData), entry: onlineCell.modelData };
                                }
                            }

                            RippleButton {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                implicitWidth: 38
                                implicitHeight: 38
                                buttonRadius: 19
                                enabled: !onlineCell.busy
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                colRipple: Appearance.colors.colPrimaryActive
                                downAction: () => {
                                    const entry = onlineCell.modelData;
                                    Qt.callLater(() => PresetsOnline.download(entry));
                                }
                                contentItem: Item {
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: onlineCell.busy ? "hourglass_top" : "download"
                                        iconSize: 20
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !PresetsOnline.loading && root.onlineEntries.length === 0
                    text: PresetsOnline.error !== "" ? PresetsOnline.error : root.tokens.length > 0 ? Translation.tr("No presets match your search") : Translation.tr("Nothing new to download")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: PresetsOnline.error !== "" ? Appearance.colors.colError : Appearance.colors.colSubtext
                }
            }

            DashboardCard {
                anchors.centerIn: parent
                visible: !root.onlineEnabled
                width: 420
                height: 240
                tint: Appearance.colors.colPrimaryContainer
                pager: root.pager
                staggerMs: root.staggerMs
                travelX: 0
                travelY: 160

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        shape: MaterialShape.Shape.SoftBurst
                        text: "public"
                        iconSize: 30
                        fill: 1
                        padding: 14
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Online presets")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Browse presets shared by the community on blapples.github.io. Nothing is downloaded until you press the button.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    RippleButton {
                        Layout.alignment: Qt.AlignHCenter
                        implicitHeight: 44
                        horizontalPadding: 24
                        buttonRadius: 22
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        downAction: () => Qt.callLater(() => root.enableOnline())
                        contentItem: StyledText {
                            text: Translation.tr("Enable online presets")
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: detailLoader
        anchors.fill: parent
        active: root.selected !== null
        visible: !Presets.uploadGuideOpen

        sourceComponent: DashboardPresetDetail {
            preset: root.selected
            pager: root.pager
            staggerMs: root.staggerMs
            onBack: root.back()
            onApplyRequested: {
                if (root.selected.source === "online") PresetsOnline.download(root.selected.entry);
                else root.applyPreset(root.selected);
            }
            onOverwriteRequested: Presets.overwrite(root.selected.name)
            onExportRequested: Presets.exportZip(root.selected.name)
            onRenameRequested: newName => Presets.rename(root.selected.name, newName)
            onUploadRequested: Presets.publish(root.selected.name)
            onUnshareRequested: Presets.unpublish(root.selected.name)
            onInstallRequested: Presets.install(root.selected.name, root.selected.source)
            onDeleteRequested: {
                root.removePreset(root.selected);
                root.back();
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: Presets.uploadGuideOpen

        sourceComponent: DashboardPresetUploadGuide {
            presetName: Presets.uploadGuideName
            onProceed: Presets.confirmUploadGuide()
            onCancel: Presets.cancelUploadGuide()
        }
    }

    Connections {
        target: Presets
        function onRenamed(oldName, newName) {
            if (newName === "" || root.selected === null || root.selected.name !== oldName) return;
            root.selected = Object.assign({}, root.selected, { name: newName });
        }
    }

    function saveCurrent() {
        const text = saveInput.text.trim();
        if (text === "") return;
        Presets.save(text);
        saveInput.text = "";
        saveInput.focus = false;
        pager.forceActiveFocus();
    }
}
