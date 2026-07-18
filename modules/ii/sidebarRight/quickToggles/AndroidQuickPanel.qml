import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

import qs.modules.ii.sidebarRight.quickToggles.androidStyle

AbstractQuickPanel {
    id: root
    property bool editMode: false
    Layout.fillWidth: true

    implicitHeight: (editMode ? contentItem.implicitHeight : usedRows.implicitHeight) + root.padding * 2
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    property real spacing: Appearance.spacing.small
    property real padding: Appearance.spacing.small
    readonly property real baseCellWidth: {
        const availableWidth = root.width - (root.padding * 2) - (root.spacing * (root.columns))
        return availableWidth / root.columns
    }
    readonly property real baseCellHeight: 56

    readonly property list<string> availableToggleTypes: ["network", "bluetooth", "idleInhibitor", "easyEffects", "nightLight", "darkMode", "cloudflareWarp", "gameMode", "screenSnip", "colorPicker", "onScreenKeyboard", "mic", "audio", "notifications", "powerProfile","musicRecognition", "antiFlashbang"]
    readonly property int columns: Config.options.sidebar.quickToggles.android.columns
    readonly property list<var> toggles: Config.ready ? Config.options.sidebar.quickToggles.android.toggles : []
    readonly property list<var> toggleRows: toggleRowsForList(toggles)
    readonly property list<var> unusedToggles: {
        const types = availableToggleTypes.filter(type => !toggles.some(toggle => (toggle && toggle.type === type)))
        return types.map(type => { return { type: type, size: 1 } })
    }
    readonly property list<var> unusedToggleRows: toggleRowsForList(unusedToggles)

    property alias dropIndicator: dropIndicator

    function toggleRowsForList(togglesList) {
        var rows = [];
        var row = [];
        var totalSize = 0;
        for (var i = 0; i < togglesList.length; i++) {
            if (!togglesList[i]) continue;
            if (totalSize + togglesList[i].size > columns) {
                rows.push(row);
                row = [];
                totalSize = 0;
            }
            row.push(togglesList[i]);
            totalSize += togglesList[i].size;
        }
        if (row.length > 0) rows.push(row);
        return rows;
    }

    Column {
        id: contentItem
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: Appearance.spacing.normal

        Column {
            id: usedRows
            spacing: root.spacing

            Repeater {
                id: usedRowsRepeater
                model: ScriptModel {
                    values: Array(root.toggleRows.length)
                }
                delegate: ButtonGroup {
                    id: toggleRow
                    required property int index
                    property var modelData: root.toggleRows[index]
                    property int startingIndex: {
                        const rows = root.toggleRows;
                        let sum = 0;
                        for (let i = 0; i < index; i++) sum += rows[i].length;
                        return sum;
                    }
                    spacing: root.spacing

                    Repeater {
                        model: ScriptModel {
                            values: toggleRow?.modelData ?? []
                            objectProp: "type"
                        }
                        delegate: AndroidToggleDelegateChooser {
                            startingIndex: toggleRow.startingIndex
                            editMode: root.editMode
                            gridRef: usedRows
                            dropIndicatorRef: dropIndicator
                            isUnused: false
                            baseCellWidth: root.baseCellWidth
                            baseCellHeight: root.baseCellHeight
                            spacing: root.spacing
                            onOpenAudioOutputDialog: root.openAudioOutputDialog()
                            onOpenAudioInputDialog: root.openAudioInputDialog()
                            onOpenBluetoothDialog: root.openBluetoothDialog()
                            onOpenNightLightDialog: root.openNightLightDialog()
                            onOpenWifiDialog: root.openWifiDialog()
                        }
                    }
                }
            }

            Rectangle {
                id: dropIndicator
                visible: false
                z: 99
                width: 3
                radius: Appearance.rounding.unsharpen
                color: Appearance.colors.colPrimary

                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -4
                    width: 8; height: 8; radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -4
                    width: 8; height: 8; radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary
                }
            }
        }

        FadeLoader {
            shown: root.editMode
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: root.baseCellHeight / 2
                rightMargin: root.baseCellHeight / 2
            }
            sourceComponent: Rectangle {
                implicitHeight: 1
                color: Appearance.colors.colOutlineVariant
            }
        }

        FadeLoader {
            shown: root.editMode
            sourceComponent: Column {
                id: unusedRows
                spacing: root.spacing

                Repeater {
                    model: ScriptModel {
                        values: Array(root.unusedToggleRows.length)
                    }
                    delegate: ButtonGroup {
                        id: unusedToggleRow
                        required property int index
                        property var modelData: root.unusedToggleRows[index]
                        spacing: root.spacing

                        Repeater {
                            model: ScriptModel {
                                values: unusedToggleRow?.modelData ?? []
                                objectProp: "type"
                            }
                            delegate: AndroidToggleDelegateChooser {
                                startingIndex: -1
                                editMode: root.editMode
                                isUnused: true
                                baseCellWidth: root.baseCellWidth
                                baseCellHeight: root.baseCellHeight
                                spacing: root.spacing
                            }
                        }
                    }
                }
            }
        }

        ConfigSpinBox {
            visible: root.editMode
            width: parent.width 
            enabled: Config.options.sidebar.quickToggles.style === "android"
            icon: "add_column_left"
            text: Translation.tr("Columns")
            value: Config.options.sidebar.quickToggles.android.columns
            from: 1
            to: 8
            stepSize: 1
            onValueChanged: {
                Config.options.sidebar.quickToggles.android.columns = value;
            }
        }
    }
}