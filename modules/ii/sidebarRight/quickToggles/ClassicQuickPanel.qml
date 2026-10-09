import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles as Models
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import qs.modules.ii.sidebarRight.quickToggles.classicStyle

AbstractQuickPanel {
    id: root
    property bool editMode: false
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight
    color: "transparent"

    property bool isDragging: false
    property string draggedType: ""
    property string draggedIcon: ""   // cached on drag start — avoids getModelForType() each frame
    property bool draggedIsUnused: false
    property point ghostPos: Qt.point(0, 0)
    property int dropTargetIndex: -1

    property var workingToggles: []

    function syncWorkingToggles(): void {
        if (!root.isDragging) {
            root.workingToggles = Array.from(root.toggles);
        }
    }

    Component.onCompleted: { syncWorkingToggles(); }
    onTogglesChanged: { syncWorkingToggles(); }

    readonly property int maxColumns: 9
    readonly property int activeColumns: Math.min(maxColumns, Math.max(1, root.workingToggles.length))

    readonly property list<string> availableToggleTypes: {
        const base = [
            "network", "vpn", "bluetooth", "idleInhibitor", "easyEffects", "nightLight",
            "darkMode", "cloudflareWarp", "gameMode", "screenSnip", "colorPicker",
            "onScreenKeyboard", "mic", "audio", "notifications", "powerProfile",
            "musicRecognition", "antiFlashbang"
        ];
        return WM.compositor === "hyprland" ? base : base.filter(t => t !== "gameMode");
    }

    readonly property list<string> defaultToggles: [
        "network",
        "vpn",
        "bluetooth",
        "nightLight",
        "gameMode",
        "idleInhibitor",
        "easyEffects",
        "cloudflareWarp"
    ]

    readonly property list<string> toggles: {
        if (!Config.ready) return defaultToggles;
        const conf = Config.options?.sidebar?.quickToggles?.classic?.toggles;
        if (!conf || conf.length === 0) return defaultToggles;
        return WM.compositor === "hyprland" ? conf : conf.filter(t => t !== "gameMode");
    }

    readonly property list<string> unusedToggles: {
        return availableToggleTypes.filter(t => !root.workingToggles.includes(t));
    }

    function addToggle(type: string): void {
        let current = Array.from(root.workingToggles);
        if (!current.includes(type)) {
            current.push(type);
            saveToggles(current);
        }
    }

    function removeToggle(type: string): void {
        let current = Array.from(root.workingToggles);
        const idx = current.indexOf(type);
        if (idx !== -1) {
            current.splice(idx, 1);
            saveToggles(current);
        }
    }

    function insertToggleAt(type: string, targetIndex: int): void {
        let current = Array.from(root.workingToggles);
        const existingIdx = current.indexOf(type);
        if (existingIdx !== -1) {
            current.splice(existingIdx, 1);
        }
        const insertIdx = Math.max(0, Math.min(current.length, targetIndex));
        current.splice(insertIdx, 0, type);
        saveToggles(current);
    }

    function saveToggles(newList: var): void {
        root.workingToggles = Array.from(newList);
        if (!Config.options.sidebar.quickToggles.classic) {
            Config.options.sidebar.quickToggles.classic = {};
        }
        Config.options.sidebar.quickToggles.classic.toggles = newList;
    }

    function getGridIndexAt(localX: real, localY: real, totalCount: int, columns: int): int {
        if (totalCount <= 0) return 0;
        const cellW = 46;
        const cellH = 46;
        let col = Math.floor(localX / cellW);
        let row = Math.floor(localY / cellH);
        col = Math.max(0, Math.min(columns - 1, col));
        row = Math.max(0, row);
        let idx = row * columns + col;
        return Math.max(0, Math.min(totalCount - 1, idx));
    }

    function handleDragStarted(bType: string, unused: bool, scenePos: point): void {
        root.isDragging = true;
        root.draggedType = bType;
        root.draggedIcon = root.getModelForType(bType)?.icon ?? "close";
        root.draggedIsUnused = unused;
        root.ghostPos = root.mapFromItem(null, scenePos.x, scenePos.y);
        root.dropTargetIndex = -1;
    }

    function handleDragMoved(scenePos: point): void {
        if (!root.isDragging) return;
        root.ghostPos = root.mapFromItem(null, scenePos.x, scenePos.y);

        // Only track WHERE the icon would drop — never mutate workingToggles here.
        // Mutating the model destroys all Repeater delegates, killing the DragHandler grab.
        const localActive = activeGrid.mapFromItem(null, scenePos.x, scenePos.y);
        const isInsideGrid = (localActive.x >= 0 && localActive.x <= activeGrid.width &&
                              localActive.y >= 0 && localActive.y <= activeGrid.height);

        if (isInsideGrid) {
            const count = root.draggedIsUnused
                ? root.workingToggles.length + 1
                : root.workingToggles.length;
            root.dropTargetIndex = getGridIndexAt(localActive.x, localActive.y, count, root.activeColumns);
        } else {
            root.dropTargetIndex = -1;
        }
    }

    function handleDragEnded(scenePos: point): void {
        if (!root.isDragging) return;

        if (root.dropTargetIndex >= 0) {
            if (root.draggedIsUnused) {
                // Insert from unused panel into active at target position
                root.insertToggleAt(root.draggedType, root.dropTargetIndex);
            } else {
                // Reorder within active toggles — one-shot at drag end
                let list = root.workingToggles.slice();
                const fromIdx = list.indexOf(root.draggedType);
                if (fromIdx !== -1 && fromIdx !== root.dropTargetIndex) {
                    list.splice(fromIdx, 1);
                    list.splice(root.dropTargetIndex, 0, root.draggedType);
                    saveToggles(list);
                }
            }
        } else if (!root.draggedIsUnused && root.editMode) {
            // Dropped outside active grid in edit mode: remove if dropped below active group
            const localGroup = activeGroup.mapFromItem(null, scenePos.x, scenePos.y);
            if (localGroup.y > activeGroup.height + 10) {
                root.removeToggle(root.draggedType);
            }
        }

        root.isDragging = false;
        root.draggedType = "";
        root.draggedIcon = "";
        root.draggedIsUnused = false;
        root.dropTargetIndex = -1;
    }

    function openMenuForType(type: string): void {
        switch (type) {
            case "network":
                root.openWifiDialog();
                break;
            case "vpn":
                root.openVpnDialog();
                break;
            case "bluetooth":
                root.openBluetoothDialog();
                break;
            case "nightLight":
                root.openNightLightDialog();
                break;
            case "audio":
                root.openAudioOutputDialog();
                break;
            case "mic":
                root.openAudioInputDialog();
                break;
        }
    }

    // Toggle models
    Models.NetworkToggle { id: networkModel }
    Models.VpnToggle { id: vpnModel }
    Models.BluetoothToggle { id: bluetoothModel }
    Models.NightLightToggle { id: nightLightModel }
    Models.GameModeToggle { id: gameModeModel }
    Models.IdleInhibitorToggle { id: idleInhibitorModel }
    Models.EasyEffectsToggle { id: easyEffectsModel }
    Models.CloudflareWarpToggle { id: cloudflareWarpModel }
    Models.DarkModeToggle { id: darkModeModel }
    Models.ScreenSnipToggle { id: screenSnipModel }
    Models.ColorPickerToggle { id: colorPickerModel }
    Models.OnScreenKeyboardToggle { id: onScreenKeyboardModel }
    Models.MicToggle { id: micModel }
    Models.AudioToggle { id: audioModel }
    Models.NotificationToggle { id: notificationsModel }
    Models.PowerProfilesToggle { id: powerProfileModel }
    Models.MusicRecognitionToggle { id: musicRecognitionModel }
    Models.AntiFlashbangToggle { id: antiFlashbangModel }

    function getModelForType(type: string): var {
        switch (type) {
            case "network": return networkModel;
            case "vpn": return vpnModel;
            case "bluetooth": return bluetoothModel;
            case "nightLight": return nightLightModel;
            case "gameMode": return gameModeModel;
            case "idleInhibitor": return idleInhibitorModel;
            case "easyEffects": return easyEffectsModel;
            case "cloudflareWarp": return cloudflareWarpModel;
            case "darkMode": return darkModeModel;
            case "screenSnip": return screenSnipModel;
            case "colorPicker": return colorPickerModel;
            case "onScreenKeyboard": return onScreenKeyboardModel;
            case "mic": return micModel;
            case "audio": return audioModel;
            case "notifications": return notificationsModel;
            case "powerProfile": return powerProfileModel;
            case "musicRecognition": return musicRecognitionModel;
            case "antiFlashbang": return antiFlashbangModel;
            default: return null;
        }
    }

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    Column {
        id: mainColumn
        spacing: 10
        anchors.horizontalCenter: parent.horizontalCenter

        // Active toggles container
        Rectangle {
            id: activeGroup
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: activeGrid.implicitWidth + 16
            implicitHeight: activeGrid.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Grid {
                id: activeGrid
                anchors.centerIn: parent
                columns: root.activeColumns
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    id: activeRepeater
                    model: root.workingToggles
                    ClassicQuickToggleButton {
                        id: activeBtn
                        required property string modelData
                        required property int index
                        buttonType: modelData
                        toggleModel: root.getModelForType(modelData)
                        editMode: root.editMode
                        isUnused: false
                        isDragPlaceholder: root.isDragging && root.draggedType === modelData && !root.draggedIsUnused
                        onRemoveRequested: root.removeToggle(modelData)
                        onOpenMenu: root.openMenuForType(modelData)
                        onDragStarted: (bType, unused, scenePos) => root.handleDragStarted(bType, unused, scenePos)
                        onDragMoved: (scenePos) => root.handleDragMoved(scenePos)
                        onDragEnded: (scenePos) => root.handleDragEnded(scenePos)
                    }
                }
            }

            // Drop indicator line — shows for any drag with a valid drop target
            Rectangle {
                visible: root.isDragging && root.dropTargetIndex >= 0
                z: 10
                width: 3
                height: 36
                radius: 2
                color: Appearance.colors.colPrimary
                parent: activeGrid
                x: {
                    const col = root.dropTargetIndex % Math.max(1, root.activeColumns);
                    return col * 46 - 4;
                }
                y: {
                    const row = Math.floor(root.dropTargetIndex / Math.max(1, root.activeColumns));
                    return row * 46 + 2;
                }
                Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }
        }

        // Edit mode: divider + available toggles
        FadeLoader {
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.editMode
            sourceComponent: Column {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: unusedGroup.implicitWidth
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("Available toggles (click to add)")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }

                Rectangle {
                    id: unusedGroup
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: unusedGrid.implicitWidth + 16
                    implicitHeight: unusedGrid.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    Grid {
                        id: unusedGrid
                        anchors.centerIn: parent
                        columns: Math.min(root.maxColumns, Math.max(1, root.unusedToggles.length))
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: root.unusedToggles
                            ClassicQuickToggleButton {
                                required property string modelData
                                buttonType: modelData
                                toggleModel: root.getModelForType(modelData)
                                editMode: root.editMode
                                isUnused: true
                                onAddRequested: root.addToggle(modelData)
                                onDragStarted: (bType, unused, scenePos) => root.handleDragStarted(bType, unused, scenePos)
                                onDragMoved: (scenePos) => root.handleDragMoved(scenePos)
                                onDragEnded: (scenePos) => root.handleDragEnded(scenePos)
                            }
                        }
                    }
                }
            }
        }
    }

    // Floating ghost icon that follows cursor while dragging
    Rectangle {
        visible: root.isDragging
        z: 999
        width: 40; height: 40
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer
        border.color: Appearance.colors.colPrimary
        border.width: 2
        opacity: 0.85
        x: root.ghostPos.x - 20
        y: root.ghostPos.y - 20
        scale: 1.18
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 22
            fill: 1
            color: Appearance.colors.colOnPrimaryContainer
            text: root.draggedIcon || (root.getModelForType(root.draggedType)?.icon ?? "close")
        }
    }
}
