import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : batteryProgress.valueBarWidth + 10
    implicitHeight: vertical ? batteryProgress.valueBarWidth + 20 : Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        value: percentage
        rotation: root.vertical ? -90 : 0
        highlightColor: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer

        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            // Horizontal
            RowLayout {
                visible: !root.vertical
                anchors.centerIn: parent
                spacing: 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 2
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Appearance.font.pixelSize.smaller
                    visible:  isCharging && percentage < 1
                }
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 2
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }

            // Vertical
            ColumnLayout {
                visible: root.vertical
                anchors.centerIn: parent
                rotation: 90
                spacing: -4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    fill: 1
                    text: "bolt"
                    Layout.topMargin: 4
                    iconSize: Appearance.font.pixelSize.smaller
                    visible: isCharging && percentage < 1
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: (isCharging && percentage < 1) ? 8 : 4  
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}