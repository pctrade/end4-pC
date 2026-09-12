import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    property bool vertical: false
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool hovered: containsMouse
    readonly property var screen: root.QsWindow?.window?.screen
    readonly property int screenWidth: screen?.width ?? 1920
    readonly property bool veryConstrained: !root.vertical
        && screenWidth <= Appearance.sizes.barHellaShortenScreenWidthThreshold
    readonly property var connectedDevice: BluetoothStatus.primaryConnectedDevice
    readonly property var batteryDevice: BluetoothStatus.primaryBatteryDevice
    readonly property bool hasBattery: !!batteryDevice
    readonly property real batteryPercentage: hasBattery
        ? Math.max(0, Math.min(1, Number(batteryDevice.battery)))
        : 0
    readonly property bool isLow: hasBattery
        && batteryPercentage <= Config.options.battery.low / 100
    readonly property string deviceName: connectedDevice?.name ?? ""
    readonly property string stateIcon: BluetoothStatus.connected
        ? Icons.getBluetoothDeviceMaterialSymbol(connectedDevice?.icon || "")
        : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
    readonly property string percentageText: `${Math.round(batteryPercentage * 100)}%`

    visible: BluetoothStatus.available
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    implicitWidth: vertical
        ? Appearance.sizes.verticalBarWidth
        : Math.max(contentLoader.item?.implicitWidth ?? 0, Appearance.font.pixelSize.larger) + 8
    implicitHeight: vertical
        ? Math.max(contentLoader.item?.implicitHeight ?? 0, Appearance.font.pixelSize.larger)
        : Appearance.sizes.barHeight

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            GlobalStates.requestBluetoothDialog();
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? columnContent : rowContent
    }

    Component {
        id: rowContent

        RowLayout {
            spacing: 4

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.stateIcon
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasBattery && !root.veryConstrained
                font.pixelSize: Appearance.font.pixelSize.small
                font.features: { "tnum": 1 }
                color: root.isLow
                    ? Appearance.colors.colError
                    : root.isMaterial
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnLayer1
                text: root.percentageText
            }
        }
    }

    Component {
        id: columnContent

        ColumnLayout {
            spacing: -2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.stateIcon
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 2
                Layout.bottomMargin: 4
                visible: true
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: root.isLow
                    ? Appearance.colors.colError
                    : root.isMaterial
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnLayer1
                text: root.percentageText
            }
        }
    }

    BluetoothPopup {
        id: bluetoothPopup
        hoverTarget: root
    }
}
