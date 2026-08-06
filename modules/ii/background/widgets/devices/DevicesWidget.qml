import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "devices"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    implicitWidth: sizeMode === "1x4" ? 400 : 276
    implicitHeight: sizeMode === "1x4" ? 120 : 252

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    property var devicesList: []
    property bool loading: true

    function refreshDevices() {
        if (devicesProc.running) {
            devicesProc.running = false;
        }
        devicesProc.running = true;
    }

    function getDeviceIcon(type) {
        switch (type) {
            case "mouse":     return "mouse";
            case "keyboard":  return "keyboard";
            case "touchpad":  return "trackpad";
            case "headphone": return "headphones";
            case "phone":     return "smartphone";
            case "tablet":    return "tablet";
            case "laptop":    return "laptop";
            default:          return "devices_other";
        }
    }

    function getDeviceSubtitle(dev) {
        if (!dev.connected) return "Disconnected";
        if (dev.charging) return "Charging • Main Station";
        if (dev.battery !== null) {
            if (dev.battery < 20) return "Battery Low";
            return "Connected • Active";
        }
        return "Connected • System";
    }

    function getDeviceColor(connected, battery, charging) {
        if (!connected) {
            return Appearance.colors.colSubtext;
        }
        if (charging) {
            return "#39d353"; // Green when charging
        }
        if (battery !== null) {
            return battery < 20 ? "#f44336" : Appearance.colors.colSecondaryContainer;
        }
        return Appearance.colors.colSecondaryContainer;
    }

    Process {
        id: devicesProc
        command: ["python3", Quickshell.shellPath("scripts/devices/get_devices.py")]
        running: true
        stdout: StdioCollector {
            id: devicesOutputCollector
            onStreamFinished: {
                const output = devicesOutputCollector.text.trim();
                if (output) {
                    try {
                        root.devicesList = JSON.parse(output);
                    } catch (e) {
                        console.log("[DevicesWidget] Error parsing JSON:", e);
                    }
                }
                root.loading = false;
            }
        }
    }

    // Instant update trigger using dbus-monitor/udevadm background listener
    Process {
        id: triggerProc
        command: ["python3", Quickshell.shellPath("scripts/devices/monitor_trigger.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                triggerProc.running = false;
                refreshDelayTimer.start();
            }
        }
    }

    Timer {
        id: refreshDelayTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.refreshDevices();
            triggerProc.running = true;
        }
    }

    Timer {
        id: refreshTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: refreshDevices()
    }

    Component.onCompleted: {
        refreshDevices();
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 24
        color: Appearance.colors.colLayer0

        StyledRectangularShadow {
            target: card
            z: -2
        }

        // Layout for 2x2 Mode (Android M3 Vertical Rows List style)
        ColumnLayout {
            visible: root.sizeMode === "2x2"
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "devices"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    text: "Devices"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 8
                    height: 3
                    radius: 1.5
                    color: "#39d353"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialLoadingIndicator {
                    anchors.centerIn: parent
                    visible: root.loading && root.devicesList.length === 0
                    loading: root.loading
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "No devices connected"
                    font.pixelSize: 12
                    color: Appearance.colors.colSubtext
                    visible: !root.loading && root.devicesList.length === 0
                }

                // Vertical Device Items List
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: !root.loading && root.devicesList.length > 0

                    Repeater {
                        model: root.devicesList.slice(0, 3)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12

                            // Battery Progress Ring with Center Icon
                            Item {
                                width: 42
                                height: 42

                                CircularProgress {
                                    id: progress
                                    anchors.centerIn: parent
                                    implicitSize: 42
                                    lineWidth: 4
                                    value: modelData.connected ? (modelData.battery !== null ? modelData.battery / 100 : 1.0) : 1.0
                                    gapAngle: 0
                                    colPrimary: root.getDeviceColor(modelData.connected, modelData.battery, modelData.charging)
                                    colSecondary: ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colLayer0, 0.12)
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelData.charging ? "bolt" : root.getDeviceIcon(modelData.type)
                                    iconSize: 16
                                    color: root.getDeviceColor(modelData.connected, modelData.battery, modelData.charging)
                                }
                            }

                            // Device Title & Subtitle
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: root.getDeviceSubtitle(modelData)
                                    font.pixelSize: 11
                                    color: Appearance.colors.colSubtext
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Battery Percentage Text
                            StyledText {
                                text: modelData.battery !== null ? modelData.battery + "%" : (modelData.connected ? "On" : "Off")
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: modelData.battery !== null && modelData.battery < 20 ? "#f44336" : Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }
            }
        }

        // Layout for 1x4 Horizontal Mode (Resized & Optimized)
        RowLayout {
            visible: root.sizeMode === "1x4"
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 12

            // Compact Header Icon on the left
            MaterialSymbol {
                text: "devices"
                iconSize: 22
                color: Appearance.colors.colOnLayer0
            }

            // Divider Line
            Rectangle {
                width: 1
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Appearance.colors.colLayer0Border
                opacity: 0.4
            }

            // Expanded Horizontal Devices Row
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Repeater {
                    model: root.devicesList.slice(0, 3)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        // Circular Progress Ring
                        Item {
                            width: 38
                            height: 38

                            CircularProgress {
                                anchors.centerIn: parent
                                implicitSize: 38
                                lineWidth: 3
                                value: modelData.connected ? (modelData.battery !== null ? modelData.battery / 100 : 1.0) : 1.0
                                gapAngle: 0
                                colPrimary: root.getDeviceColor(modelData.connected, modelData.battery, modelData.charging)
                                colSecondary: ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colLayer0, 0.12)
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.charging ? "bolt" : root.getDeviceIcon(modelData.type)
                                iconSize: 15
                                color: root.getDeviceColor(modelData.connected, modelData.battery, modelData.charging)
                            }
                        }

                        // Device Details (Name & Subtitle/Battery)
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            StyledText {
                                text: modelData.name
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData.battery !== null ? modelData.battery + "%" + (modelData.charging ? " • Charging" : "") : "Connected"
                                font.pixelSize: 11
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Resize Handle in bottom right corner
        Rectangle {
            id: resizeHandle
            width: 14; height: 14; radius: 3
            color: Appearance.colors.colOnPrimaryContainer
            anchors { right: card.right; bottom: card.bottom; margins: 4 }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.4 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true
                property real startWidth: 0
                property real startX: 0
                onPressed: (mouse) => {
                    startWidth = root.width
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalX = mapToItem(null, mouse.x, mouse.y).x
                    var dx = globalX - startX
                    var newW = startWidth + dx
                    
                    if (newW > 338) {
                        root.sizeMode = "1x4"
                    } else {
                        root.sizeMode = "2x2"
                    }
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
