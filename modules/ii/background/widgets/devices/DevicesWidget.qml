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

    function getBatteryIcon(val) {
        if (val === undefined || val === null) return "";
        if (val >= 90) return "battery_full";
        if (val >= 70) return "battery_5_bar";
        if (val >= 50) return "battery_4_bar";
        if (val >= 30) return "battery_3_bar";
        if (val >= 15) return "battery_1_bar";
        return "battery_alert";
    }

    function getDeviceColor(connected, battery, charging) {
        if (!connected) {
            return "#7f8c8d"; // Grey color for disconnected
        }
        if (charging) {
            return "#39d353"; // Green when charging
        }
        if (battery !== null) {
            return battery < 30 ? "#f44336" : "#39d353"; // Red below 30%, otherwise Green
        }
        return "#39d353"; // Green for connected non-battery devices
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
        interval: 350 // Wait 350ms for kernel/dbus interfaces to register state changes
        repeat: false
        onTriggered: {
            root.refreshDevices();
            triggerProc.running = true;
        }
    }

    Timer {
        id: refreshTimer
        interval: 30000 // Periodic backup refresh every 30 seconds
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
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: root.sizeMode === "1x4" ? 12 : 16
            }
            spacing: root.sizeMode === "1x4" ? 6 : 12

            // Header Section
            RowLayout {
                id: headerSection
                Layout.fillWidth: true
                spacing: 10
                visible: root.sizeMode === "2x2"
                Layout.preferredHeight: root.sizeMode === "2x2" ? -1 : 0

                MaterialShapeWrappedMaterialSymbol {
                    wrappedShape: MaterialShape.Shape.Cookie4Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: "devices"
                    iconSize: 20
                    fill: 1
                    padding: 6
                    implicitWidth: 32
                    implicitHeight: 32
                }

                ColumnLayout {
                    spacing: -2
                    Layout.fillWidth: true

                    StyledText {
                        text: "Devices"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.loading ? "Updating..." : "Connected accessories"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // Grid Section
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
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.4
                    visible: !root.loading && root.devicesList.length === 0
                }

                Grid {
                    id: grid
                    anchors.centerIn: parent
                    columns: root.sizeMode === "1x4" ? 4 : 2
                    rows: root.sizeMode === "1x4" ? 1 : 2
                    rowSpacing: root.sizeMode === "1x4" ? 0 : 12
                    columnSpacing: root.sizeMode === "1x4" ? 22 : 16
                    visible: !root.loading && root.devicesList.length > 0

                    Repeater {
                        model: root.devicesList.slice(0, 4)
                        delegate: Item {
                            required property var modelData
                            width: root.sizeMode === "1x4" ? 82 : 108
                            height: root.sizeMode === "1x4" ? 92 : 84

                            // Circular progress battery/status ring
                            CircularProgress {
                                id: progress
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                implicitSize: 56
                                lineWidth: 5
                                value: modelData.connected ? (modelData.battery !== null ? modelData.battery / 100 : 1.0) : 1.0
                                gapAngle: 0
                                colPrimary: root.getDeviceColor(modelData.connected, modelData.battery, modelData.charging)
                                colSecondary: ColorUtils.mix(Appearance.colors.colOnPrimaryContainer, Appearance.colors.colPrimaryContainer, 0.08)
                            }

                             // Charging bolt at the top of the ring (dark outline)
                             MaterialSymbol {
                                 text: "bolt"
                                 iconSize: 17
                                 color: Appearance.colors.colPrimaryContainer
                                 anchors.horizontalCenter: progress.horizontalCenter
                                 anchors.horizontalCenterOffset: 1
                                 anchors.verticalCenter: progress.top
                                 visible: modelData.charging === true
                                 z: 4
                             }

                             // Charging bolt at the top of the ring (white foreground)
                             MaterialSymbol {
                                 text: "bolt"
                                 iconSize: 13
                                 color: "#ffffff"
                                 anchors.horizontalCenter: progress.horizontalCenter
                                 anchors.horizontalCenterOffset: 1
                                 anchors.verticalCenter: progress.top
                                 visible: modelData.charging === true
                                 z: 5
                             }

                            // Center content
                            Column {
                                anchors.centerIn: progress
                                spacing: -2

                                MaterialSymbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.getDeviceIcon(modelData.type)
                                    iconSize: 20
                                    color: modelData.connected ? Appearance.colors.colOnPrimaryContainer : "#7f8c8d"
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.battery !== null ? modelData.battery + "%" : ""
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: modelData.connected ? root.getDeviceColor(true, modelData.battery) : "#7f8c8d"
                                    visible: root.sizeMode === "2x2" && modelData.battery !== null
                                }
                            }

                            // Device Label / Percentage Text below circle
                            StyledText {
                                anchors.horizontalCenter: progress.horizontalCenter
                                anchors.top: progress.bottom
                                anchors.topMargin: root.sizeMode === "1x4" ? 8 : 4
                                text: root.sizeMode === "1x4" ? 
                                      (modelData.battery !== null ? modelData.battery + "%" : (modelData.connected ? "On" : "Off")) : 
                                      modelData.name
                                font.pixelSize: root.sizeMode === "1x4" ? 15 : 10
                                font.weight: root.sizeMode === "1x4" ? Font.DemiBold : Font.Normal
                                color: modelData.connected ? Appearance.colors.colOnPrimaryContainer : "#7f8c8d"
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
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
                    
                    // Toggle threshold mid-point (between 276 and 400 is 338)
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
