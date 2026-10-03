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
    property bool editMode: false
    property bool showIconPickerDialog: false
    property string draggingType: ""
    property int hoverPos: -1
    property point dragPosition

    readonly property bool animatedEntrance: WM.compositor !== "hyprland"
    readonly property bool sidebarOpen: GlobalStates.sidebarRightOpen

    // ponytail: 3 panels + calendar expand → limit quick rows to 2
    readonly property int activePanelCount: {
        let c = 1
        const sl = Config.options.sidebar.quickSliders
        if (sl && sl.enable && (sl.showMic || sl.showVolume || sl.showBrightness)) c++
        if (Config.options.sidebar.mediaPlayer && (root.activePlayer !== null || root.editMode)) c++
        return c
    }
    readonly property bool threePanelsActive: root.activePanelCount >= 3
    readonly property bool calendarExpanded: Config.options.sidebar.bottomGroup && !Persistent.states.sidebar.bottomGroup.collapsed
    readonly property bool shouldLimitRows: root.threePanelsActive && root.calendarExpanded && !root.editMode

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players
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
        target: GlobalStates
        function onRequestBluetoothDialog() {
            if (!BluetoothStatus.available) return;
            root.showBluetoothDialog = true;
            GlobalStates.sidebarRightOpen = true;
        }

        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
                root.editMode = false;
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
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.8) 
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 5

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            // Banner
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: false
                sourceComponent: Config.options.sidebar.banner ? bannerComponent : normalComponent

                Component {
                    id: bannerComponent
                    Item {
                        implicitHeight: 180
                        implicitWidth: parent?.width ?? 0

                        Rectangle {
                            id: sysRect
                            anchors.fill: parent
                            radius: Config.options.hyprland.decoration.rounding - 2
                            color: Appearance.colors.colLayer1

                            Rectangle {
                                id: wallpaperRect
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    topMargin: 2
                                    leftMargin: 2
                                    rightMargin: 2
                                }
                                height: 120
                                radius: sysRect.radius
                                color: "transparent"

                                StyledImage {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: Config.options.sidebar.bannerImage !== "" 
                                        ? Config.options.sidebar.bannerImage 
                                        : Config.options.background.wallpaperPath
                                    cache: false
                                    antialiasing: true
                                    sourceSize.width: wallpaperRect.width * 2
                                    sourceSize.height: wallpaperRect.height * 2
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: wallpaperRect.width
                                            height: wallpaperRect.height
                                            radius: wallpaperRect.radius
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (event) => {
                                        if (event.button === Qt.LeftButton) {
                                            fileChooser.running = true
                                            GlobalStates.sidebarRightOpen = false
                                        } else if (event.button === Qt.RightButton) {
                                            Config.options.sidebar.bannerImage = ""
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors {
                                    left: parent.left
                                    bottom: parent.bottom
                                    leftMargin: 13
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
                                    visible: Config.options.sidebar.quickToggles.style === "android"
                                    buttonIcon: "edit"
                                    onClicked: root.editMode = !root.editMode
                                    StyledToolTip {
                                        text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
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

                Component {
                    id: normalComponent
                    SystemButtonRow {}
                }
            }

            // ponytail: 3 reorderable panels — hold one, the others make room live
            Item {
                id: panelArea
                Layout.fillWidth: true
                implicitHeight: panelArea.totalHeight

                readonly property int gap: root.editMode ? 8 : sidebarPadding
                readonly property var baseOrder: {
                    const o = Config.options.sidebar.panelOrder
                    return (o && o.length === 3) ? o.map(String) : ["quickToggles", "sliders", "media"]
                }
                // urutan tampil selama drag: panel yang dipegang ditempatkan di posisi hover
                readonly property var displayOrder: {
                    const b = panelArea.baseOrder
                    const d = root.draggingType
                    if (d === "" || root.hoverPos < 0 || b.indexOf(d) === root.hoverPos) return b
                    const a = [...b]
                    a.splice(a.indexOf(d), 1)
                    a.splice(root.hoverPos, 0, d)
                    return a
                }
                readonly property real totalHeight: {
                    let h = 0
                    let n = 0
                    for (const t of panelArea.displayOrder) {
                        const hs = panelArea.hostOf(t)
                        if (!hs || !hs.visible) continue
                        h += hs.stackHeight + (n > 0 ? panelArea.gap : 0)
                        n++
                    }
                    return h
                }

                function panelSource(type) {
                    if (type === "quickToggles") return quickTogglesPanel
                    if (type === "sliders") return slidersPanel
                    if (type === "media") return mediaPanel
                    return null
                }
                function panelVisible(type) {
                    if (type === "quickToggles") return true
                    if (type === "sliders") {
                        const c = Config.options.sidebar.quickSliders
                        return c.enable && (c.showMic || c.showVolume || c.showBrightness)
                    }
                    if (type === "media") return Config.options.sidebar.mediaPlayer && (root.activePlayer !== null || root.editMode)
                    return false
                }
                function hostOf(type) {
                    if (type === "quickToggles") return qtPanel
                    if (type === "sliders") return slPanel
                    return mdPanel
                }
                function yFor(type) {
                    let y = 0
                    for (const t of panelArea.displayOrder) {
                        if (t === type) break
                        const hs = panelArea.hostOf(t)
                        if (!hs || !hs.visible) continue
                        y += hs.stackHeight + panelArea.gap
                    }
                    return y
                }
                // indeks jatuh dari kursor: berapa panel lain yang tengahnya sudah di atas kursor
                function hoverAt(scenePos) {
                    const local = panelArea.mapFromItem(null, scenePos.x, scenePos.y)
                    const seq = panelArea.displayOrder.filter(t => t !== root.draggingType)
                    let above = 0
                    for (const t of seq) {
                        const hs = panelArea.hostOf(t)
                        if (!hs || !hs.visible) continue
                        if (hs.y + hs.height / 2 <= local.y) above++
                    }
                    // sisip tepat setelah `above` panel terlihat (panel tersembunyi dihitung nol tinggi)
                    let seen = 0
                    for (let i = 0; i < seq.length; i++) {
                        const hs = panelArea.hostOf(seq[i])
                        if (!hs || !hs.visible) continue
                        if (seen === above) return i
                        seen++
                    }
                    return seq.length
                }

                PanelHost { id: qtPanel; panelType: "quickToggles" }
                PanelHost { id: slPanel; panelType: "sliders" }
                PanelHost { id: mdPanel; panelType: "media" }
            }

            CenterWidgetGroup {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumHeight: 47 // ponytail: bottom bar (ring/count/clean) height, not shrink through
            }

            BottomWidgetGroup {
                visible: Config.options.sidebar.bottomGroup
                id: bottomWidgetGroup
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                Layout.fillWidth: true
            }
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
        shownPropertyString: "showIconPickerDialog"
        dialog: IconPickerDialog {}
    }

    // Drag ghost — panel yang dipegang terangkat di atas panel lain
    Item {
        id: dragGhost
        visible: root.draggingType !== ""
        z: 999
        width: sidebarWidth + 30
        height: dragGhostContent.implicitHeight + 16
        x: root.dragPosition.x - width / 2
        y: root.dragPosition.y - 40

        // ponytail: no Behavior on x/y — ghost harus nempel 1:1 di kursor,
        // animasi di sini yang bikin "fling" dari posisi lama ke kursor
        Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 8
            radius: 24
            color: Qt.rgba(0, 0, 0, 0.35)
            samples: 33
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }

        ColumnLayout {
            id: dragGhostContent
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0
            Loader {
                id: dragGhostLoader
                Layout.fillWidth: true
                active: root.draggingType !== ""
                property string panelType: root.draggingType
                sourceComponent: panelArea.panelSource(panelType)
            }
        }
    }

    // ponytail: satu item stabil per panel — urutan datang dari panelArea.displayOrder
    component PanelHost: Item {
        id: host
        property string panelType: ""
        readonly property bool bleed: panelType === "media"
        readonly property real stackHeight: height - (bleed ? 20 : 0)

        x: bleed ? -10 : 0
        width: panelArea.width + (bleed ? 20 : 0)
        y: panelArea.yFor(panelType) + (bleed ? -10 : 0)
        height: hostColumn.implicitHeight
        visible: panelArea.panelVisible(panelType)
        opacity: root.draggingType === panelType ? 0
            : (root.editMode && !panelArea.panelVisible(panelType) ? 0.4 : 1)

        Behavior on y {
            enabled: root.draggingType !== ""
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(host)
        }

        ColumnLayout {
            id: hostColumn
            width: parent.width
            spacing: 0
            ReorderDragHandle { panelType: host.panelType }
            Loader {
                Layout.fillWidth: true
                active: panelArea.panelVisible(host.panelType)
                asynchronous: true
                sourceComponent: panelArea.panelSource(host.panelType)
            }
        }
    }

    // ponytail: reorder drag handle for panel slots
    component ReorderDragHandle: Rectangle {
        id: reorderHandle
        visible: root.editMode && !(reorderHandle.panelType === "media" && !Config.options.sidebar.mediaPlayer)
        Layout.fillWidth: true
        implicitHeight: 28
        radius: Appearance.rounding.small
        color: reorderDragHandler.active ? Appearance.colors.colLayer1Active : Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        property string panelType: ""
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8
            MaterialSymbol { text: "drag_indicator"; iconSize: 18; color: Appearance.colors.colSubtext }
            StyledText {
                Layout.fillWidth: true
                text: reorderHandle.panelType === "quickToggles" ? Translation.tr("Quick toggles")
                    : reorderHandle.panelType === "sliders" ? Translation.tr("Sliders")
                    : reorderHandle.panelType === "media" ? Translation.tr("Media")
                    : reorderHandle.panelType
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
            MaterialSymbol { text: "drag_indicator"; iconSize: 18; color: Appearance.colors.colSubtext }
        }

        DragHandler {
            id: reorderDragHandler
            target: null
            onActiveChanged: {
                if (active) {
                    // seed dulu: centroid cuma dihitung ulang pada gerakan pertama,
                    // kalau tidak ghost muncul dari posisi drag sebelumnya (atau 0,0)
                    const sc = centroid.scenePosition
                    const lp = root.mapFromItem(null, sc.x, sc.y)
                    root.dragPosition = Qt.point(lp.x, lp.y)
                    root.draggingType = reorderHandle.panelType
                    root.hoverPos = panelArea.baseOrder.indexOf(reorderHandle.panelType)
                } else {
                    // preview sudah sesuai: tulis jadi urutan baru
                    const cur = Config.options.sidebar.panelOrder
                    const next = panelArea.displayOrder
                    if (cur && cur.length === 3 && next.some((t, i) => String(cur[i]) !== t))
                        Config.options.sidebar.panelOrder = next
                    root.draggingType = ""
                    root.hoverPos = -1
                }
            }
            onCentroidChanged: {
                if (!active) return
                const sc = centroid.scenePosition
                const localPos = root.mapFromItem(null, sc.x, sc.y)
                root.dragPosition = Qt.point(localPos.x, localPos.y)
                root.hoverPos = panelArea.hoverAt(sc)
            }
        }
        HoverHandler { cursorShape: reorderDragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
    }

    Component {
        id: quickTogglesPanel
        ColumnLayout {
            spacing: 0
            Loader {
                Layout.fillWidth: true
                active: Config.options.sidebar.quickToggles.style === "classic"
                visible: active
                sourceComponent: ClassicQuickPanel {}
            }
            Loader {
                Layout.fillWidth: true
                active: Config.options.sidebar.quickToggles.style === "android"
                visible: active
                sourceComponent: AndroidQuickPanel { editMode: root.editMode; limitRows: root.shouldLimitRows }
            }
        }
    }
    Component {
        id: slidersPanel
        QuickSliders {}
    }
    Component {
        id: mediaPanel
        Item {
            implicitHeight: root.activePlayer !== null ? 160 : 80
            Loader {
                anchors.fill: parent
                active: root.activePlayer !== null
                sourceComponent: Player {
                    player: root.activePlayer
                    visualizerPoints: GlobalStates.visualizerPoints
                    implicitHeight: 160
                    radius: Appearance.rounding.normal
                }
            }
            ColumnLayout {
                anchors.fill: parent
                visible: root.activePlayer === null
                spacing: 8
                Item { Layout.fillHeight: true }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "music_note"
                    iconSize: 32
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No media playing")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                Item { Layout.fillHeight: true }
            }
        }
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
                visible: Config.options.sidebar.quickToggles.style === "android"
                buttonIcon: "edit"
                onClicked: root.editMode = !root.editMode
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
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
