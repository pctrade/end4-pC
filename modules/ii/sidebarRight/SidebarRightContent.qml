import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

import qs.modules.ii.sidebarRight.quickToggles
import qs.modules.ii.sidebarRight.quickToggles.classicStyle
import qs.modules.ii.sidebarRight.bluetoothDevices
import qs.modules.ii.sidebarRight.nightLight
import qs.modules.ii.sidebarRight.volumeMixer
import qs.modules.ii.sidebarRight.wifiNetworks
import qs.modules.ii.sidebarRight.vpnConnections
import qs.modules.ii.sidebarRight.vpn
import qs.modules.ii.sidebarRight.iconPicker

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool showVpnDialog: false
    property bool editMode: false
    property string editTab: Config.options.sidebar.quickToggles.style === "android" ? "toggles" : "layout"
    readonly property var editTabs: Config.options.sidebar.quickToggles.style === "android"
        ? [
            { id: "toggles", name: Translation.tr("Toggles"), icon: "toggle_on" },
            { id: "layout", name: Translation.tr("Layout"), icon: "dashboard_customize" }
        ]
        : [{ id: "layout", name: Translation.tr("Layout"), icon: "dashboard_customize" }]
    property bool showIconPickerDialog: false

    readonly property bool animatedEntrance: WM.compositor !== "hyprland"
    readonly property bool sidebarOpen: GlobalStates.sidebarRightOpen

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();
        for (let i = 0; i < players.length; ++i) {
            if (used.has(i)) continue;
            let p1 = players[i];
            let group = [i];
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if ((p1.trackTitle && p2.trackTitle &&
                    (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle))) ||
                    (Math.abs(p1.position - p2.position) <= 2 && Math.abs(p1.length - p2.length) <= 2)) {
                    group.push(j);
                    used.add(j);
                }
            }
            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            filtered.push(players[chosenIdx !== undefined ? chosenIdx : group[0]]);
        }
        return filtered;
    }

    readonly property var meaningfulPlayers: {
        const preferred = Config.options.bar.media.preferredPlayer.trim().toLowerCase()
        if (preferred.length === 0) return filterDuplicatePlayers(realPlayers)
        const filtered = realPlayers.filter(p =>
            (p.identity ?? "").toLowerCase().includes(preferred) ||
            (p.desktopEntry ?? "").toLowerCase().includes(preferred)
        )
        if (filtered.length === 0) return filterDuplicatePlayers(realPlayers)
        return filterDuplicatePlayers(filtered)
    }

    function filterDuplicatePlayers(players) {
        if (!players) return [];
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i))
                continue;
            let p1 = players[i];
            let group = [i];

            // Find duplicates by trackTitle prefix
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (p1.trackTitle && p2.trackTitle && (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle)) || (p1.position - p2.position <= 2 && p1.length - p2.length <= 2)) {
                    group.push(j);
                }
            }

            // Pick the one with non-empty trackArtUrl, or fallback to the first
            let chosenIdx = group.find(idx => players[idx]?.trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined)
                chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Connections {
        target: Vpn
        function onDialogRequested() { root.showVpnDialog = true; }
    }

    Connections {
        target: GlobalStates
        function onRequestBluetoothDialog() {
            if (!BluetoothStatus.available) return;
            root.showBluetoothDialog = true;
            GlobalStates.sidebarRightOpen = true;
        }

        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.editMode = false;
                root.showWifiDialog = false;
                root.showVpnDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
            }
        }
    }

    Process {
        id: fileChooser
        command: ["kdialog", "--getopenfilename", Quickshell.env("HOME") + "/Pictures", "image/png image/jpg image/jpeg image/webp"]
        
        stdout: StdioCollector {
            id: fileChooserOutput
        }
        
        onExited: (code) => {
            if (code === 0) {
                const path = fileChooserOutput.text.trim()
                if (path !== "") {
                    Config.options.sidebar.bannerImage = path
                }
            }
        }
    }

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    StyledRectangularShadow {
        target: sidebarRightBackground
    }
    Rectangle {
        id: sidebarRightBackground

        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        color: Appearance.colors.colUiBackground
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.8) 
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 5

        ReorderableColumn {
            id: sectionColumn
            anchors.fill: parent
            anchors.margins: sidebarPadding
            itemSpacing: sidebarPadding
            order: root.sectionOrder
            editMode: root.editMode && root.editTab === "layout"
            fillKey: "notifications"
            fillMinHeight: 120
            onReordered: newOrder => Config.options.sidebar.sectionOrder = newOrder
            componentForKey: key => root.sectionComponents[key] ?? null
            isKeyActive: key => root.sectionActive(key)
        }
    }

    readonly property var sectionComponents: ({
        "banner": bannerSection,
        "quickToggles": quickTogglesSection,
        "sliders": slidersSection,
        "media": mediaSection,
        "notifications": notificationsSection,
        "bottom": bottomSection
    })

    function sectionActive(key) {
        const sidebar = Config.options.sidebar
        switch (key) {
        case "sliders":
            return sidebar.quickSliders.enable && (sidebar.quickSliders.showMic || sidebar.quickSliders.showVolume || sidebar.quickSliders.showBrightness)
        case "media":
            return root.activePlayer !== null && sidebar.mediaPlayer
        case "bottom":
            return sidebar.bottomGroup
        default:
            return true
        }
    }

    readonly property var defaultSectionOrder: ["banner", "quickToggles", "sliders", "media", "notifications", "bottom"]
    readonly property var sectionOrder: {
        const saved = Array.from(Config.options.sidebar.sectionOrder).filter(key => defaultSectionOrder.includes(key))
        const unique = saved.filter((key, i) => saved.indexOf(key) === i)
        return unique.concat(defaultSectionOrder.filter(key => !unique.includes(key)))
    }

    Component {
        id: bannerSection
        Loader {
            sourceComponent: Config.options.sidebar.banner ? bannerComponent : normalComponent
        }
    }

        Component {
            id: bannerComponent
            Item {
                implicitHeight: 180
                implicitWidth: parent?.width ?? 0

                Rectangle {
                    id: sysRect
                    readonly property real inset: 5
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    Rectangle {
                        id: wallpaperRect
                        property bool panning: false
                        property real dragDX: 0
                        property real dragDY: 0
                        readonly property real aspect: bannerImage.implicitHeight > 0 ? bannerImage.implicitWidth / bannerImage.implicitHeight : 1
                        readonly property real coverWidth: aspect > width / height ? height * aspect : width
                        readonly property real coverHeight: aspect > width / height ? height : width / aspect
                        readonly property real overflowX: Math.max(0, coverWidth - width)
                        readonly property real overflowY: Math.max(0, coverHeight - height)
                        readonly property real focusX: overflowX > 0 ? Math.max(0, Math.min(1, Config.options.sidebar.bannerFocusX - dragDX / overflowX)) : 0.5
                        readonly property real focusY: overflowY > 0 ? Math.max(0, Math.min(1, Config.options.sidebar.bannerFocusY - dragDY / overflowY)) : 0.5

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            topMargin: sysRect.inset
                            leftMargin: sysRect.inset
                            rightMargin: sysRect.inset
                        }
                        height: 120
                        radius: Math.max(0, sysRect.radius - sysRect.inset)
                        color: "transparent"

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: wallpaperRect.width
                                    height: wallpaperRect.height
                                    radius: wallpaperRect.radius
                                }
                            }

                            StyledImage {
                                id: bannerImage
                                x: -wallpaperRect.overflowX * wallpaperRect.focusX
                                y: -wallpaperRect.overflowY * wallpaperRect.focusY
                                width: wallpaperRect.coverWidth
                                height: wallpaperRect.coverHeight
                                fillMode: Image.PreserveAspectCrop
                                source: Config.options.sidebar.bannerImage !== "" 
                                    ? Config.options.sidebar.bannerImage 
                                    : Config.options.background.wallpaperPath
                                cache: false
                                antialiasing: true
                                sourceSize.width: wallpaperRect.width * 2
                                sourceSize.height: wallpaperRect.height * 2
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: wallpaperRect.radius
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                            border.width: 2
                            border.color: Appearance.colors.colPrimary
                            opacity: wallpaperRect.panning ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 44
                                radius: height / 2
                                color: Appearance.colors.colPrimary

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "open_with"
                                    iconSize: 24
                                    color: Appearance.colors.colOnPrimary
                                }
                            }
                        }

                            ButtonGroup {
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: 4
                                }
                                color: "transparent"
                                padding: 4

                                QuickToggleButton {
                                    toggled: root.editMode
                                    buttonIcon: "edit"
                                    onClicked: root.editMode = !root.editMode
                                    StyledToolTip {
                                        text: Translation.tr("Edit quick toggles") + (root.editMode ? (Config.options.sidebar.quickToggles.style === "android" ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : Translation.tr("\nDrag to reorder\nClick × to remove\nDrag from below to add")) : "")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "restart_alt"
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "reload"])
                                        Quickshell.reload(true);
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Reload Hyprland & Quickshell")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: GlobalStates.settingsOpen
                                    buttonIcon: "settings"
                                    onClicked: {
                                        GlobalStates.sidebarRightOpen = false;
                                        GlobalStates.settingsOpen = !GlobalStates.settingsOpen
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Settings")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "mode_off_on"
                                    onClicked: GlobalStates.sessionOpen = true
                                    StyledToolTip {
                                        text: Translation.tr("Session")
                                    }
                        MouseArea {
                            property real lastX: 0
                            property real lastY: 0
                            anchors.fill: parent
                            cursorShape: wallpaperRect.panning ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: mouse => {
                                lastX = mouse.x
                                lastY = mouse.y
                            }
                            onPressAndHold: mouse => {
                                if (mouse.button === Qt.LeftButton) wallpaperRect.panning = true
                            }
                            onPositionChanged: mouse => {
                                if (!wallpaperRect.panning) return
                                wallpaperRect.dragDX += mouse.x - lastX
                                wallpaperRect.dragDY += mouse.y - lastY
                                lastX = mouse.x
                                lastY = mouse.y
                            }
                            onReleased: {
                                if (!wallpaperRect.panning) return
                                Config.options.sidebar.bannerFocusX = wallpaperRect.focusX
                                Config.options.sidebar.bannerFocusY = wallpaperRect.focusY
                                wallpaperRect.dragDX = 0
                                wallpaperRect.dragDY = 0
                                wallpaperRect.panning = false
                            }
                            onCanceled: {
                                wallpaperRect.dragDX = 0
                                wallpaperRect.dragDY = 0
                                wallpaperRect.panning = false
                            }
                            onClicked: (event) => {
                                if (event.button === Qt.LeftButton) {
                                    fileChooser.running = true
                                    GlobalStates.sidebarRightOpen = false
                                } else if (event.button === Qt.RightButton) {
                                    Config.options.sidebar.bannerImage = ""
                                    Config.options.sidebar.bannerFocusX = 0.5
                                    Config.options.sidebar.bannerFocusY = 0.5
                                }
                            }
                        }
                    }

                    Column {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            leftMargin: sysRect.inset + 8
                            bottomMargin: 8
                        }
                        spacing: 1

                        UserAvatar {
                            width: 48
                            height: 48
                        }

                        StyledText {
                            text: (Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName) + "@" + SystemInfo.hostname
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            text: Translation.tr("Up • %1").arg(DateTime.uptime)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.6
                        }
                    }

                    ButtonGroup {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 4
                        }
                        color: "transparent"
                        padding: 4

                        QuickToggleButton {
                            toggled: root.editMode
                                        buttonIcon: "edit"
                            onClicked: root.editMode = !root.editMode
                            StyledToolTip {
                                text: Translation.tr("Edit sidebar")
                            }
                        }
                        QuickToggleButton {
                            toggled: false
                            buttonIcon: "restart_alt"
                            onClicked: {
                                Quickshell.execDetached(["hyprctl", "reload"])
                                Quickshell.reload(true);
                            }
                            StyledToolTip {
                                text: Translation.tr("Reload Hyprland & Quickshell")
                            }
                        }
                        QuickToggleButton {
                            toggled: GlobalStates.settingsOpen
                            buttonIcon: "settings"
                            onClicked: {
                                GlobalStates.sidebarRightOpen = false;
                                GlobalStates.settingsOpen = !GlobalStates.settingsOpen
                            }
                            StyledToolTip {
                                text: Translation.tr("Settings")
                            }
                        }
                        QuickToggleButton {
                            toggled: false
                            buttonIcon: "mode_off_on"
                            onClicked: GlobalStates.sessionOpen = true
                            StyledToolTip {
                                text: Translation.tr("Session")
                            }
                        }
                    }
                }
            }
        }

            LoaderedQuickPanelImplementation {
                styleName: "classic"
                sourceComponent: ClassicQuickPanel {
                    editMode: root.editMode
                }
    Component {
        id: normalComponent
        SystemButtonRow {}
    }

    Component {
        id: quickTogglesSection
        Item {
            implicitHeight: (classicLoader.item?.implicitHeight ?? 0) + (androidLoader.item?.implicitHeight ?? 0)

            Loader {
                id: classicLoader
                anchors.left: parent.left
                anchors.right: parent.right
                active: Config.options.sidebar.quickToggles.style === "classic"
                sourceComponent: ClassicQuickPanel {}
            }

            Loader {
                id: androidLoader
                anchors.left: parent.left
                anchors.right: parent.right
                active: Config.options.sidebar.quickToggles.style === "android"
                sourceComponent: AndroidQuickPanel {
                    editMode: root.editMode && root.editTab === "toggles"
                }
            }

            Connections {
                target: classicLoader.item
                function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true; }
                function onOpenAudioInputDialog() { root.showAudioInputDialog = true; }
                function onOpenBluetoothDialog() { root.showBluetoothDialog = true; }
                function onOpenNightLightDialog() { root.showNightLightDialog = true; }
                function onOpenWifiDialog() { root.showWifiDialog = true; }
                function onOpenVpnDialog() { root.showVpnDialog = true; }
            }

            Connections {
                target: androidLoader.item
                function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true; }
                function onOpenAudioInputDialog() { root.showAudioInputDialog = true; }
                function onOpenBluetoothDialog() { root.showBluetoothDialog = true; }
                function onOpenNightLightDialog() { root.showNightLightDialog = true; }
                function onOpenWifiDialog() { root.showWifiDialog = true; }
                function onOpenVpnDialog() { root.showVpnDialog = true; }
            }
        }
    }

    Component {
        id: slidersSection
        Loader {
            active: root.sectionActive("sliders")
            sourceComponent: QuickSliders {}
        }
    }

    Component {
        id: mediaSection
        Loader {
            active: root.sectionActive("media") && GlobalStates.sidebarRightOpen
            sourceComponent: Item {
                implicitHeight: 160 - Appearance.sizes.elevationMargin * 2

                Player {
                    anchors.fill: parent
                    anchors.margins: -Appearance.sizes.elevationMargin
                    player: root.activePlayer
                    allowLyrics: false
                    visualizerPoints: GlobalStates.visualizerPoints
                    radius: Appearance.rounding.normal
                }
            }
        }
    }

    Component {
        id: notificationsSection
        CenterWidgetGroup {}
    }

    Component {
        id: bottomSection
        Loader {
            active: root.sectionActive("bottom")
            sourceComponent: BottomWidgetGroup {}
        }
    }

    Toolbar {
        id: editToolbar
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.editMode ? 22 : -height - 30
        opacity: root.editMode ? 1 : 0

        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        ToolbarTabBar {
            id: editTabBar
            tabButtonList: root.editTabs
            currentIndex: Math.max(0, root.editTabs.findIndex(tab => tab.id === root.editTab))
            onCurrentIndexChanged: root.editTab = root.editTabs[Math.max(0, currentIndex)]?.id ?? "layout"
        }

        IconToolbarButton {
            text: "check"
            onClicked: root.editMode = false
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog {
            isSink: true
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog {
            isSink: false
        }
    }

    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            const adapter = Bluetooth.defaultAdapter;
            if (!adapter) return;
            if (!shown) {
                adapter.discovering = false;
            } else {
                adapter.enabled = true;
                adapter.discovering = true;
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return;
            Network.enableWifi();
            Network.rescanWifi();
        }
    }

    ToggleDialog {
        shownPropertyString: "showVpnDialog"
        dialog: VpnDialog {}
        onShownChanged: {
            if (!shown) return;
            Vpn.update();
        }
        onShownChanged: if (shown) Vpn.refresh()
    }

    ToggleDialog {
        shownPropertyString: "showIconPickerDialog"
        dialog: IconPickerDialog {}
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent

        onShownChanged: if (shown) toggleDialogLoader.active = true;
        active: shown
        onActiveChanged: {
            if (active) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                toggleDialogLoader.item.show = false
                root[toggleDialogLoader.shownPropertyString] = false;
            }
            function onVisibleChanged() {
                if (toggleDialogLoader.item && !toggleDialogLoader.item.visible && !root[toggleDialogLoader.shownPropertyString])
                    toggleDialogLoader.active = false;
            }
        }
    }

    component LoaderedQuickPanelImplementation: Loader {
        id: quickPanelImplLoader
        required property string styleName
        Layout.alignment: item?.Layout.alignment ?? Qt.AlignHCenter
        Layout.fillWidth: item?.Layout.fillWidth ?? false
        visible: active
        active: Config.options.sidebar.quickToggles.style === styleName
        Connections {
            target: quickPanelImplLoader.item
            function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true; }
            function onOpenAudioInputDialog() { root.showAudioInputDialog = true; }
            function onOpenBluetoothDialog() { root.showBluetoothDialog = true; }
            function onOpenNightLightDialog() { root.showNightLightDialog = true; }
            function onOpenWifiDialog() { root.showWifiDialog = true; }
            function onOpenVpnDialog() { root.showVpnDialog = true; }
        }
    }

    component SystemButtonRow: Item {
        implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)

        Rectangle {
            id: uptimeContainer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.normal
            implicitWidth: uptimeRow.implicitWidth + 24
            implicitHeight: uptimeRow.implicitHeight + 8

            Row {
                id: uptimeRow
                anchors.centerIn: parent
                spacing: 8
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25

                    CustomIcon {
                        id: distroIcon
                        anchors.fill: parent
                        source: Config.options.custom.distroIcon || SystemInfo.distroIcon
                        customFolder: Config.options.custom.iconsPath
                        colorize: Config.options.custom.colorizeIcon
                        color: Appearance.colors.colOnLayer0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showIconPickerDialog = true
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                    text: Translation.tr("Up • %1").arg(DateTime.uptime)
                    textFormat: Text.MarkdownText
                }
            }
        }

        ButtonGroup {
            id: systemButtonsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: Appearance.colors.colLayer1
            padding: 4

            QuickToggleButton {
                toggled: root.editMode
                buttonIcon: "edit"
                onClicked: root.editMode = !root.editMode
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (root.editMode ? (Config.options.sidebar.quickToggles.style === "android" ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : Translation.tr("\nClick to add\nClick × to remove")) : "")
                    text: Translation.tr("Edit sidebar")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "restart_alt"
                onClicked: {
                    if (WM.compositor === "niri") {
                        Quickshell.execDetached(["niri", "msg", "action", "reload-config"]);
                    } else {
                        Quickshell.execDetached(["hyprctl", "reload"]);
                    }
                    Quickshell.reload(true);
                }
                StyledToolTip {
                    text: WM.compositor === "niri"
                        ? Translation.tr("Reload Niri & Quickshell")
                        : Translation.tr("Reload Hyprland & Quickshell")
                }
            }
            QuickToggleButton {
                toggled: GlobalStates.settingsOpen
                buttonIcon: "settings"
                onClicked: {
                    GlobalStates.sidebarRightOpen = false;
                    GlobalStates.settingsOpen = !GlobalStates.settingsOpen
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "mode_off_on"
                onClicked: GlobalStates.sessionOpen = true
                StyledToolTip {
                    text: Translation.tr("Session")
                }
            }
        }
    }
}
