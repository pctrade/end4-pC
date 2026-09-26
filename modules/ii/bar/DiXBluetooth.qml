import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xb
    required property Item di
    spacing: 8
    implicitWidth: 340
    readonly property real wantedWidth: 340

    readonly property var devices: [...BluetoothStatus.connectedDevices, ...BluetoothStatus.pairedButNotConnectedDevices].slice(0, 6)

    StyledText {
        text: Translation.tr("Bluetooth devices")
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
    }

    StyledText {
        Layout.fillWidth: true
        visible: xb.devices.length === 0
        text: Translation.tr("No paired devices yet · pair one in the Bluetooth settings")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
        wrapMode: Text.Wrap
    }

    Repeater {
        model: xb.devices
        delegate: Rectangle {
            id: deviceRow
            required property var modelData
            readonly property bool connected: deviceRow.modelData.connected
            readonly property bool busy: deviceRow.modelData.state === BluetoothDeviceState.Connecting
                || deviceRow.modelData.state === BluetoothDeviceState.Disconnecting
            readonly property real battery: deviceRow.modelData.batteryAvailable ? Number(deviceRow.modelData.battery) : -1
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 14
            color: deviceRow.connected ? Appearance.colors.colPrimaryContainer
                : (rowMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)

            Behavior on color {
                ColorAnimation { duration: IslandMotion.short }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 12
                }
                spacing: 10

                Loader {
                    active: IslandEvents.hasCaseArt(deviceRow.modelData.name) && IslandEvents.caseClosedArt !== ""
                    visible: active
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    sourceComponent: DiEarbudsCase {
                        open: deviceRow.connected
                        busy: deviceRow.busy
                        animateEntrance: false
                    }
                }

                MaterialShapeWrappedMaterialSymbol {
                    visible: !(IslandEvents.hasCaseArt(deviceRow.modelData.name) && IslandEvents.caseClosedArt !== "")
                    wrappedShape: deviceRow.busy ? MaterialShape.Shape.Cookie12Sided
                        : deviceRow.connected ? MaterialShape.Shape.Circle : MaterialShape.Shape.Cookie4Sided
                    color: deviceRow.connected ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                    colSymbol: deviceRow.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    text: IslandEvents.bluetoothSymbol(deviceRow.modelData.icon)
                    iconSize: 16
                    fill: 1
                    padding: 6

                    RotationAnimation on rotation {
                        running: deviceRow.busy
                        from: 0
                        to: 360
                        duration: 2400
                        loops: Animation.Infinite
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -3
                    StyledText {
                        Layout.fillWidth: true
                        text: IslandEvents.shortName(deviceRow.modelData.name || deviceRow.modelData.deviceName)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: deviceRow.connected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: deviceRow.busy ? Translation.tr("Connecting…")
                            : deviceRow.connected ? Translation.tr("Connected") : Translation.tr("Tap to connect")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: deviceRow.connected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }

                Item {
                    visible: deviceRow.connected && deviceRow.battery >= 0
                    implicitWidth: 30
                    implicitHeight: 30

                    CircularProgress {
                        anchors.fill: parent
                        implicitSize: 30
                        lineWidth: 3
                        value: Math.max(0, deviceRow.battery)
                        colPrimary: deviceRow.battery <= 0.2 ? Appearance.colors.colError : Appearance.colors.colOnPrimaryContainer
                        colSecondary: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.8)
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: Math.round(deviceRow.battery * 100)
                        font.pixelSize: 9
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (deviceRow.connected) deviceRow.modelData.disconnect()
                    else deviceRow.modelData.connect()
                }
            }
        }
    }
}
