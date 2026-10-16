import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    signal pageExitRequested()

    property int currentPage: GlobalStates.dashboardPage
    property int pendingPage: GlobalStates.dashboardPage
    property int staggerMs: 45 / Math.max(0.5, Config.options.settings.animationSpeed ?? 1)
    property var pageBoxes: buildPage(GlobalStates.dashboardPage)
    property int selectedIndex: 0
    property bool searchOpen: false
    property var thumbsRequested: ({})
    property string searchQuery: ""
    readonly property int wallpapersPage: 1
    readonly property bool wallpaperMode: currentPage === wallpapersPage
    readonly property int homePage: 0
    readonly property int settingsPage: 4
    readonly property int presetsPage: 2
    readonly property int mediaPage: 3
    readonly property bool mediaVisible: currentPage === mediaPage && mediaState.displayedArtFilePath !== ""
    readonly property var mediaColors: mediaVisible ? mediaState.blendedColors : Appearance.colors

    QtObject {
        id: ui

        readonly property var blended: mediaState.blendedColors
        readonly property bool media: root.mediaVisible && root.pendingPage === root.mediaPage

        readonly property color surface: media ? blended.colLayer1 : Appearance.colors.colLayer1
        readonly property color fgSurface: media ? blended.colOnLayer1 : Appearance.colors.colOnLayer1
        readonly property color subtext: media ? blended.colSubtext : Appearance.colors.colSubtext
        readonly property color hover: media ? blended.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
        readonly property color accent: media ? blended.colPrimary : Appearance.colors.colPrimary
        readonly property color accentHover: media ? blended.colPrimaryHover : Appearance.colors.colPrimaryHover
        readonly property color accentActive: media ? blended.colPrimaryActive : Appearance.colors.colPrimaryActive
        readonly property color fgAccent: media ? blended.colOnPrimary : Appearance.colors.colOnPrimary
        readonly property color container: media ? blended.colSecondaryContainer : Appearance.colors.colPrimaryContainer
        readonly property color fgContainer: media ? blended.colOnSecondaryContainer : Appearance.colors.colOnPrimaryContainer
    }
    focus: true

    DashboardMediaState {
        id: mediaState
    }

    Component.onCompleted: {
        Wallpapers.load();
        forceActiveFocus();
    }

    Connections {
        target: Wallpapers
        function onWallpapersChanged() {
            if (root.wallpaperMode && root.pageBoxes.length > 0 && root.pageBoxes[0].wallpaper === "" && Wallpapers.wallpapers.length > 0)
                root.pageBoxes = root.buildPage(root.currentPage);
        }
    }

    function moveSelection(dx, dy) {
        const cur = boxRepeater.itemAt(selectedIndex);
        if (!cur) return;
        const cx = cur.x + cur.width / 2;
        const cy = cur.y + cur.height / 2;
        let best = -1;
        let bestScore = Infinity;
        for (let i = 0; i < boxRepeater.count; i++) {
            if (i === selectedIndex) continue;
            const it = boxRepeater.itemAt(i);
            if (!it) continue;
            const ox = it.x + it.width / 2 - cx;
            const oy = it.y + it.height / 2 - cy;
            const along = dx !== 0 ? ox * dx : oy * dy;
            const across = dx !== 0 ? Math.abs(oy) : Math.abs(ox);
            if (along <= 1) continue;
            const score = along + across * 2;
            if (score < bestScore) {
                bestScore = score;
                best = i;
            }
        }
        if (best >= 0) selectedIndex = best;
    }

    function activateSelected() {
        const box = pageBoxes[selectedIndex];
        if (wallpaperMode && box && box.wallpaper !== "")
            Wallpapers.apply(box.wallpaper);
    }

    property bool editingText: false

    Keys.onPressed: event => {
        if (editingText) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            if (currentPage === presetsPage && presetsLoader.item?.selected) presetsLoader.item.back();
            else GlobalStates.settingsOpen = false;
        } else if (currentPage === mediaPage && event.key === Qt.Key_Left) {
            mediaState.player?.previous();
        } else if (currentPage === mediaPage && event.key === Qt.Key_Right) {
            mediaState.player?.next();
        } else if (currentPage === mediaPage && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            mediaState.player?.togglePlaying();
        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            if (searchOpen) closeSearch();
            else openSearch();
        } else if (currentPage === settingsPage && event.key === Qt.Key_Slash) {
            openSearch();
        } else if (currentPage === wallpapersPage && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            const dx = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0;
            const dy = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0;
            wallpapersLoader.item?.moveSelection(dx, dy);
        } else if (currentPage === wallpapersPage && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            wallpapersLoader.item?.activate();
        } else if (currentPage === wallpapersPage && event.key === Qt.Key_L && wallpapersLoader.item && !wallpapersLoader.item.synced) {
            wallpapersLoader.item.activateLock();
        } else if (currentPage === settingsPage && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            settingsLoader.item?.scrollBy(event.key === Qt.Key_Down ? 120 : -120);
        } else if (currentPage === settingsPage && (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)) {
            settingsLoader.item?.scrollBy(event.key === Qt.Key_PageDown ? 420 : -420);
        } else if (event.key === Qt.Key_Left) {
            moveSelection(-1, 0);
        } else if (event.key === Qt.Key_Right) {
            moveSelection(1, 0);
        } else if (event.key === Qt.Key_Up) {
            moveSelection(0, -1);
        } else if (event.key === Qt.Key_Down) {
            moveSelection(0, 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activateSelected();
        } else if (event.key === Qt.Key_Tab) {
            goToPage((pendingPage + 1) % pageNames.length);
        } else if (event.key === Qt.Key_Backtab) {
            goToPage((pendingPage - 1 + pageNames.length) % pageNames.length);
        } else if (currentPage === homePage && homeLoader.item?.typing) {
            return;
        } else if ((isSearchablePage || currentPage === homePage) && typedCharacter(event)) {
            typeIntoSearch(event.text);
            if (currentPage === homePage) goToPage(settingsPage);
        } else {
            return;
        }
        event.accepted = true;
    }

    readonly property var pageNames: [
        { name: Translation.tr("Home"), icon: "home" },
        { name: Translation.tr("Wallpapers"), icon: "wallpaper" },
        { name: Translation.tr("Presets"), icon: "hallway" },
        { name: Translation.tr("Media"), icon: "play_circle" },
        { name: Translation.tr("Settings"), icon: "settings" }
    ]

    readonly property var layouts: [
        [[2, 2], [1, 1], [1, 1], [1, 1], [1, 1], [2, 1], [1, 1], [1, 1]],
        [[1, 1], [1, 1], [2, 1], [1, 2], [2, 1], [1, 2], [1, 1], [1, 1]],
        [[4, 1], [2, 1], [2, 1], [1, 1], [1, 1], [1, 1], [1, 1]],
        [[2, 2], [2, 1], [2, 1], [2, 1], [1, 1], [1, 1]],
        [[1, 1], [1, 1], [1, 1], [1, 1], [2, 2], [2, 1], [2, 1]]
    ]

    readonly property var palette: [
        { bg: Appearance.colors.colPrimaryContainer, fg: Appearance.colors.colOnPrimaryContainer },
        { bg: Appearance.colors.colSecondaryContainer, fg: Appearance.colors.colOnSecondaryContainer },
        { bg: Appearance.colors.colTertiaryContainer, fg: Appearance.colors.colOnTertiaryContainer },
        { bg: Appearance.colors.colLayer1, fg: Appearance.colors.colOnLayer1 },
        { bg: Appearance.colors.colSurfaceContainerHigh, fg: Appearance.colors.colOnLayer1 }
    ]

    readonly property var icons: ["wallpaper", "palette", "style", "download", "upload", "favorite", "tune", "widgets", "auto_awesome", "dark_mode"]

    function shuffled(list) {
        const copy = list.slice();
        for (let i = copy.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const t = copy[i];
            copy[i] = copy[j];
            copy[j] = t;
        }
        return copy;
    }

    function buildPage(page) {
        if (page === mediaPage || page === homePage || page === settingsPage || page === wallpapersPage || page === presetsPage) return [];
        const spans = layouts[page % layouts.length];
        const pool = page === wallpapersPage ? shuffled(Wallpapers.wallpapers) : [];
        return spans.map((s, i) => {
            const c = palette[Math.floor(Math.random() * palette.length)];
            return {
                colSpan: s[0],
                rowSpan: s[1],
                bg: c.bg,
                fg: c.fg,
                icon: icons[Math.floor(Math.random() * icons.length)],
                wallpaper: pool.length > 0 ? pool[i % pool.length] : "",
                travelX: (Math.random() - 0.5) * 500,
                travelY: (Math.random() - 0.5) * 400
            };
        });
    }

    function scrollSettingsBy(delta) {
        settingsLoader.item?.scrollBy(delta);
    }

    readonly property bool isSearchablePage: currentPage === settingsPage || currentPage === wallpapersPage || currentPage === presetsPage

    function typedCharacter(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false;
        return event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127;
    }

    function typeIntoSearch(character) {
        const previous = searchOpen ? searchInput.text : "";
        searchOpen = true;
        searchInput.text = previous + character;
        searchInput.cursorPosition = searchInput.text.length;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function openSearch() {
        searchOpen = true;
        if (pendingPage !== settingsPage && pendingPage !== wallpapersPage && pendingPage !== presetsPage) goToPage(settingsPage);
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function closeSearch() {
        searchInput.text = "";
        searchOpen = false;
        forceActiveFocus();
    }

    function goToPage(index) {
        if (index === currentPage || switchTimer.running) return;
        if (currentPage !== homePage && searchInput.text !== "") searchInput.text = "";
        pendingPage = index;
        pageExitRequested();
        forceActiveFocus();
        switchTimer.restart();
    }

    Timer {
        id: switchTimer
        interval: (320 / Math.max(0.5, Config.options.settings.animationSpeed ?? 1)) + Math.max(root.pageBoxes.length, 6) * (root.staggerMs - 4)
        onTriggered: {
            root.currentPage = root.pendingPage;
            GlobalStates.dashboardPage = root.currentPage;
            root.selectedIndex = 0;
            root.pageBoxes = root.buildPage(root.currentPage);
        }
    }

    Image {
        id: dashboardArtSource
        anchors.fill: parent
        source: mediaState.displayedArtFilePath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(800, 800)
        visible: false
    }

    FastBlur {
        id: dashboardArt
        anchors.fill: parent
        source: dashboardArtSource
        radius: 64
        opacity: root.mediaVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        color: mediaState.blendedColors.colLayer0
        opacity: root.mediaVisible ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Item {
            id: headerBar
            Layout.fillWidth: true
            implicitHeight: 56

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: ui.surface
                border.width: 2
                border.color: ui.accent
                implicitHeight: 44
                implicitWidth: distroPillRow.implicitWidth + 28

                RowLayout {
                    id: distroPillRow
                    anchors.centerIn: parent
                    spacing: 8

                    IconImage {
                        implicitSize: 22
                        source: Quickshell.iconPath(SystemInfo.logo)
                    }

                    StyledText {
                        text: SystemInfo.distroName
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: ui.fgSurface
                    }
                }
            }

            Toolbar {
                id: navToolbar
                anchors.centerIn: parent
                colBackground: ui.surface
                outerShadow: true

                Repeater {
                    model: root.pageNames

                    delegate: RippleButton {
                        id: navBtn
                        required property int index
                        required property var modelData

                        implicitHeight: 38
                        implicitWidth: navContentRow.implicitWidth + 28
                        buttonRadius: height / 2
                        toggled: root.pendingPage === index
                        onClicked: root.goToPage(index)
                        colBackgroundToggled: ui.accent
                        colBackgroundToggledHover: ui.accentHover
                        colRippleToggled: ui.accentActive
                        colBackgroundHover: ui.hover

                        contentItem: RowLayout {
                            id: navContentRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: navBtn.modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: navBtn.toggled ? ui.fgAccent : ui.fgSurface
                                fill: navBtn.toggled ? 1 : 0
                            }

                            StyledText {
                                text: navBtn.modelData.name
                                color: navBtn.toggled ? ui.fgAccent : ui.fgSurface
                                visible: navBtn.toggled
                            }
                        }
                    }
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    id: searchPill
                    implicitHeight: 44
                    implicitWidth: root.searchOpen ? Math.max(120, Math.min(220, (headerBar.width - navToolbar.width) / 2 - 12 - 108)) : 44
                    radius: height / 2
                    color: ui.surface
                    border.width: searchInput.activeFocus ? 2 : 0
                    border.color: ui.accent
                    clip: true

                    Behavior on implicitWidth {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    RippleButton {
                        id: searchButton
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 44
                        implicitHeight: 44
                        buttonRadius: 22
                        colBackground: "transparent"
                        onClicked: root.searchOpen ? root.closeSearch() : root.openSearch()
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "search"
                                iconSize: Appearance.font.pixelSize.larger
                                color: ui.fgSurface
                            }
                        }
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: searchButton.right
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.searchOpen
                        clip: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        color: ui.fgSurface
                        selectionColor: ui.accent
                        onTextChanged: root.searchQuery = text
                        Keys.onEscapePressed: {
                            if (text !== "") text = "";
                            else root.closeSearch();
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                                root.closeSearch();
                                event.accepted = true;
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: root.pendingPage === root.presetsPage ? Translation.tr("Search presets") : root.pendingPage === root.wallpapersPage ? Translation.tr("Search wallpapers") : Translation.tr("Search settings")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: ui.subtext
                        }
                    }
                }

                Repeater {
                    model: ["notifications"]

                    delegate: RippleButton {
                        required property string modelData

                        implicitWidth: 44
                        implicitHeight: 44
                        buttonRadius: height / 2
                        colBackground: ui.surface
                        colBackgroundHover: ui.hover
                        onClicked: {
                            if (modelData === "notifications")
                                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                        }
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData
                                iconSize: Appearance.font.pixelSize.larger
                                color: ui.fgSurface
                            }

                            Rectangle {
                                visible: modelData === "notifications" && Notifications.list.length > 0
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -2
                                anchors.rightMargin: -4
                                radius: height / 2
                                color: Appearance.colors.colError
                                implicitHeight: 16
                                implicitWidth: Math.max(16, badgeText.implicitWidth + 8)

                                StyledText {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: Notifications.list.length > 9 ? "9+" : Notifications.list.length
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnError
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: avatarRect
                    width: 44
                    height: 44
                    radius: width / 2
                    color: ui.container

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: Config.options.profile.avatarPath !== ""
                            ? "file://" + Config.options.profile.avatarPicture
                            : "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face"
                        sourceSize.width: avatarImage.width * 2
                        sourceSize.height: avatarImage.height * 2
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarRect.width
                                height: avatarRect.height
                                radius: avatarRect.radius
                            }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "account_circle"
                        iconSize: 30
                        color: ui.fgContainer
                        visible: avatarImage.status !== Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: avatarRect.radius
                        color: Qt.rgba(0, 0, 0, 0.55)
                        opacity: avatarArea.containsMouse ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 24
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: avatarArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.settingsOpen = false
                    }
                }
            }
        }

        GridLayout {
            id: boxGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentPage !== root.mediaPage && root.currentPage !== root.homePage && root.currentPage !== root.settingsPage && root.currentPage !== root.wallpapersPage && root.currentPage !== root.presetsPage
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                id: boxRepeater
                model: root.pageBoxes

                delegate: DashboardCard {
                    id: boxDelegate
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    Layout.rowSpan: modelData.rowSpan
                    Layout.columnSpan: modelData.colSpan

                    tint: modelData.bg

                    pager: root
                    animIndex: index
                    staggerMs: root.staggerMs
                    travelX: modelData.travelX
                    travelY: modelData.travelY

                    readonly property bool selected: root.selectedIndex === index
                    readonly property bool hasWallpaper: root.wallpaperMode && modelData.wallpaper !== ""

                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        visible: boxDelegate.hasWallpaper
                        source: boxDelegate.hasWallpaper ? "file://" + boxDelegate.modelData.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(640, 640)
                        layer.enabled: visible
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: boxDelegate.width
                                height: boxDelegate.height
                                radius: boxDelegate.cardRadius
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: !boxDelegate.hasWallpaper

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: boxDelegate.modelData.icon
                            iconSize: 32
                            color: boxDelegate.modelData.fg
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Card") + " " + (boxDelegate.index + 1)
                            color: boxDelegate.modelData.fg
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: boxDelegate.cardRadius
                        color: "transparent"
                        border.width: boxDelegate.selected ? 3 : 0
                        border.color: Appearance.colors.colPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = boxDelegate.index;
                            root.forceActiveFocus();
                            root.activateSelected();
                        }
                    }
                }
            }
        }

        Loader {
            id: presetsLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.currentPage === root.presetsPage

            sourceComponent: DashboardPresetsPage {
                pager: root
                staggerMs: root.staggerMs
            }
        }

        Loader {
            id: wallpapersLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.currentPage === root.wallpapersPage

            sourceComponent: DashboardWallpapersPage {
                pager: root
                staggerMs: root.staggerMs
            }
        }

        Loader {
            id: settingsLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.currentPage === root.settingsPage

            sourceComponent: DashboardSettingsPage {
                pager: root
                staggerMs: root.staggerMs
            }
        }

        Loader {
            id: homeLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.currentPage === root.homePage

            sourceComponent: DashboardHomePage {
                pager: root
                staggerMs: root.staggerMs
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: active
            active: root.currentPage === root.mediaPage

            sourceComponent: DashboardMediaPage {
                media: mediaState
                colors: root.mediaColors
                pager: root
                blurSource: dashboardArt
                staggerMs: root.staggerMs
            }
        }
    }
}
