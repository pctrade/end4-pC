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

    implicitWidth: 276
    implicitHeight: 252

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

    function getDeviceColor(connected, battery) {
        if (!connected) {
            return "#7f8c8d"; // Grey color for disconnected
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

    Timer {
        id: refreshTimer
        interval: 8000 // Refresh every 8 seconds
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
                margins: 16
            }
            spacing: 12

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

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
                    columns: 2
                    rows: 2
                    rowSpacing: 12
                    columnSpacing: 16
                    visible: !root.loading && root.devicesList.length > 0

                    Repeater {
                        model: root.devicesList.slice(0, 4)
                        delegate: Item {
                            required property var modelData
                            width: 108
                            height: 84

                            // Circular progress battery/status ring
                            CircularProgress {
                                id: progress
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                implicitSize: 56
                                lineWidth: 5
                                value: modelData.connected ? (modelData.battery !== null ? modelData.battery / 100 : 1.0) : 1.0
                                gapAngle: 0
                                colPrimary: root.getDeviceColor(modelData.connected, modelData.battery)
                                colSecondary: ColorUtils.mix(Appearance.colors.colOnPrimaryContainer, Appearance.colors.colPrimaryContainer, 0.08)
                            }

                            // Charging bolt at the top of the ring
                            MaterialSymbol {
                                text: "bolt"
                                iconSize: 13
                                color: "#39d353"
                                anchors.horizontalCenter: progress.horizontalCenter
                                anchors.bottom: progress.top
                                anchors.bottomMargin: -6
                                visible: modelData.charging === true
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
                                    visible: modelData.battery !== null
                                }
                            }

                            // Device Label
                            StyledText {
                                anchors.horizontalCenter: progress.horizontalCenter
                                anchors.top: progress.bottom
                                anchors.topMargin: 4
                                text: modelData.name
                                font.pixelSize: 10
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
    }
}
