import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode
    property bool showControls: false
    property string source: "local"
    property string selectedResolution: "1080p"

    property var quickDirs: [
        { icon: "home",       name: "Home   ",       path: `${Directories.home}`,                alwaysVisible: Config.options.wallpaperSelector.showHomePath },
        { icon: "wallpaper",  name: "Wallpapers   ", path: `${Directories.pictures}/Wallpapers`, alwaysVisible: true },
        { icon: "imagesmode", name: "Homework   ",   path: `${Directories.pictures}/homework`,   alwaysVisible: true },
        { icon: "casino",     name: "Random   ",     path: `${Directories.pictures}/Random`,     alwaysVisible: true },
    ]

    function updateThumbnails() {
        const item = gridLoader.item;
        const totalImageMargin = (Appearance.sizes.wallpaperSelectorItemMargins + Appearance.sizes.wallpaperSelectorItemPadding) * 2;
        const cellW = item?.cellWidth ?? (wallpaperGridBackground.width / root.columns);
        const cellH = item?.cellHeight ?? (cellW / root.previewCellAspectRatio);
        const thumbnailSizeName = Images.thumbnailSizeNameForDimensions(cellW - totalImageMargin, cellH - totalImageMargin);
        Wallpapers.setDirectory(`${Directories.pictures}/Wallpapers`);
        Qt.callLater(() => Wallpapers.generateThumbnail(thumbnailSizeName));
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0];
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            Wallpapers.select(filePath, root.useDarkMode);
        }
    }

    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            root.handleFilePasting(event);
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            showControls = !showControls;
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            Wallpapers.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            Wallpapers.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            Wallpapers.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            gridLoader.item?.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            gridLoader.item?.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            gridLoader.item?.moveSelection(-root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            gridLoader.item?.moveSelection(root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            gridLoader.item?.activateCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (filterField.text.length > 0) {
                filterField.text = filterField.text.substring(0, filterField.text.length - 1);
            }
            filterField.forceActiveFocus();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
            addressBar.focusBreadcrumb();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0) {
                filterField.text += event.text;
                filterField.cursorPosition = filterField.text.length;
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    StyledRectangularShadow {
        target: wallpaperGridBackground
    }
    Rectangle {
        id: wallpaperGridBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.screenRounding + 5

        implicitWidth: gridColumnLayout.implicitWidth
        implicitHeight: gridColumnLayout.implicitHeight

        // ─── Blur Background ───
        Item {
            anchors { fill: parent; margins: 8 }
            z: 0

            Rectangle {
                anchors.fill: parent
                radius: wallpaperGridBackground.radius - 4
                color: Appearance.colors.colLayer2
                visible: !Config.options.wallpaperSelector.showBlurBackground
            }

            StyledImage {
                id: wallpaperBgImage
                anchors.fill: parent
                visible: Config.options.wallpaperSelector.showBlurBackground
                fillMode: Image.PreserveAspectCrop
                source: Config.options.background.wallpaperPath
                cache: false
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: wallpaperGridBackground.width - 16
                        height: wallpaperGridBackground.height - 16
                        radius: wallpaperGridBackground.radius - 4
                    }
                }
            }

            FastBlur {
                anchors.fill: parent
                z: 0
                visible: Config.options.wallpaperSelector.showBlurBackground
                source: wallpaperBgImage
                radius: 48
                layer.enabled: visible
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: wallpaperGridBackground.width - 16
                        height: wallpaperGridBackground.height - 16
                        radius: wallpaperGridBackground.radius - 4
                    }
                }
            }
        }

        RowLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.topMargin: 0
            anchors.bottomMargin: 8
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: -4
            z: 1

            ColumnLayout {
                id: gridColumnLayout
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ─── Top bar ───
                Item {
                    id: topBar
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.leftMargin: 20
                    implicitHeight: 56

                    StyledComboBox {
                        id: sourceCombo
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: 150
                        model: [
                            { value: "local",     displayName: Translation.tr("Local") },
                            { value: "wallhaven", displayName: Translation.tr("Wallhaven") },
                            { value: "unsplash",  displayName: Translation.tr("Unsplash") },
                        ]
                        textRole: "displayName"
                        onCurrentIndexChanged: {
                            root.source = model[currentIndex].value
                        }
                    }

                    Toolbar {
                        anchors.centerIn: parent

                        Loader {
                            active: root.source === "local"
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: 4
                                Repeater {
                                    model: root.quickDirs
                                    delegate: RippleButton {
                                        id: dirBtn
                                        required property var modelData
                                        implicitHeight: 38
                                        buttonRadius: height / 2
                                        visible: modelData.alwaysVisible
                                        toggled: Wallpapers.directory === Qt.resolvedUrl(modelData.path)
                                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                        onClicked: Wallpapers.setDirectory(modelData.path)
                                        contentItem: RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 6
                                            MaterialSymbol {
                                                text: dirBtn.modelData.icon
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: dirBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                                fill: dirBtn.toggled ? 1 : 0
                                            }
                                            StyledText {
                                                text: dirBtn.modelData.name
                                                color: dirBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ─── Resolution buttons ───
                        Loader {
                            active: root.source !== "local"
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: 4
                                Repeater {
                                    model: ["1080p", "2K", "4K"]
                                    delegate: RippleButton {
                                        required property string modelData
                                        implicitHeight: 38
                                        buttonRadius: height / 2
                                        toggled: root.selectedResolution === modelData
                                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                        onClicked: root.selectedResolution = modelData
                                        contentItem: StyledText {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: parent.toggled
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colOnLayer2
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RippleButton {
                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: height / 2
                        toggled: showControls
                        colBackground: Appearance.colors.colSecondaryContainer
                        onClicked: showControls = !showControls
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "search"
                            iconSize: Appearance.font.pixelSize.larger
                            color: showControls
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnSecondaryContainer
                        }
                        StyledToolTip {
                            text: Translation.tr("Toggle search toolbar (Ctrl+F)")
                        }
                    }
                }

                // ─── Grid region ───
                Item {
                    id: gridDisplayRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: gridLoader
                        anchors.fill: parent
                        sourceComponent: root.source === "local" ? localGridComponent : onlineGridComponent
                    }

                    Component {
                        id: localGridComponent
                        LocalWallpaperGrid {
                            columns: root.columns
                            previewCellAspectRatio: root.previewCellAspectRatio
                            onWallpaperSelected: path => root.selectWallpaperPath(path)
                        }
                    }

                    Component {
                        id: onlineGridComponent
                        OnlineWallpaperGrid {
                            provider: root.source
                            resolution: root.selectedResolution
                            onWallpaperSelected: path => root.selectWallpaperPath(path)
                            onUpdateThumbnailsRequested: root.updateThumbnails()
                        }
                    }

                    // ─── Extra options ───
                    Row {
                        id: extraOptions
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 8
                        }
                        spacing: 6
                        z: showControls ? 2 : -1
                        opacity: showControls ? 1 : 0
                        transform: Translate {
                            y: showControls ? 0 : 20
                            Behavior on y {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        // ─── Toolbar local ───
                        Loader {
                            active: root.source === "local"
                            visible: active
                            sourceComponent: Toolbar {
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: {
                                        Wallpapers.openFallbackPicker(root.useDarkMode);
                                        GlobalStates.wallpaperSelectorOpen = false;
                                    }
                                    altAction: () => {
                                        Wallpapers.openFallbackPicker(root.useDarkMode);
                                        GlobalStates.wallpaperSelectorOpen = false;
                                        Config.options.wallpaperSelector.useSystemFileDialog = true;
                                    }
                                    text: "open_in_new"
                                    StyledToolTip {
                                        text: Translation.tr("Use the system file picker instead\nRight-click to make this the default behavior")
                                    }
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: Wallpapers.randomFromCurrentFolder()
                                    text: "ifl"
                                    StyledToolTip { text: Translation.tr("Pick random from this folder") }
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: root.useDarkMode = !root.useDarkMode
                                    text: root.useDarkMode ? "dark_mode" : "light_mode"
                                    StyledToolTip {
                                        text: Translation.tr("Click to toggle light/dark mode\n(applied when wallpaper is chosen)")
                                    }
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: root.updateThumbnails()
                                    text: "reset_image"
                                    StyledToolTip { text: Translation.tr("Update Thumbnails") }
                                }
                                ToolbarTextField {
                                    id: filterField
                                    placeholderText: focus
                                        ? Translation.tr("Search wallpapers")
                                        : Translation.tr("Hit \"/\" to search")
                                    clip: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    onTextChanged: Wallpapers.searchQuery = text
                                    Keys.onPressed: event => {
                                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                            root.handleFilePasting(event);
                                            return;
                                        } else if (text.length !== 0) {
                                            if (event.key === Qt.Key_Down) { event.accepted = true; return; }
                                            if (event.key === Qt.Key_Up)   { event.accepted = true; return; }
                                        }
                                        event.accepted = false;
                                    }
                                }
                            }
                        }

                        // ─── Toolbar online ───
                        Loader {
                            active: root.source !== "local"
                            visible: active
                            sourceComponent: Toolbar {
                                ToolbarTextField {
                                    placeholderText: Translation.tr("Search online wallpapers")
                                    clip: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    onTextChanged: OnlineWallpapers.query = text
                                    onAccepted: OnlineWallpapers.fetch()
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    enabled: OnlineWallpapers.page > 1
                                    text: "chevron_left"
                                    onClicked: OnlineWallpapers.prevPage()
                                    StyledToolTip { text: Translation.tr("Previous page") }
                                }
                                ToolbarTextField {
                                    id: pageField
                                    implicitWidth: Math.max(40, pageField.contentWidth + 24)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: OnlineWallpapers.page.toString()
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 1 }
                                    onAccepted: {
                                        const p = parseInt(text);
                                        if (p > 0) {
                                            OnlineWallpapers.page = p;
                                            OnlineWallpapers._doFetch();
                                        }
                                    }
                                    Connections {
                                        target: OnlineWallpapers
                                        function onFetched() {
                                            pageField.text = OnlineWallpapers.page.toString();
                                        }
                                    }
                                }
                                StyledText {
                                    visible: root.source !== "unsplash"
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "/ " + OnlineWallpapers.totalPages
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    text: "chevron_right"
                                    onClicked: OnlineWallpapers.nextPage()
                                    StyledToolTip { text: Translation.tr("Next page") }
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    text: "refresh"
                                    onClicked: OnlineWallpapers.fetch()
                                    StyledToolTip { text: Translation.tr("Fetch new wallpapers") }
                                }
                            }
                        }

                        ToolbarPairedFab {
                            iconText: "close"
                            onClicked: GlobalStates.wallpaperSelectorOpen = false
                            StyledToolTip { text: Translation.tr("Cancel wallpaper selection") }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && monitorIsFocused) {
                filterField.forceActiveFocus();
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() {
            if (Config.options.wallpaperSelector.closeAfterSelection)
                GlobalStates.wallpaperSelectorOpen = false;
        }
    }
}
