import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property var today: new Date()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (rowLoader.item?.implicitWidth ?? 0) + 12
    implicitHeight: vertical ? (colLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

    // Vertical
    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
            spacing: 0
            Repeater {
                model: DateTime.time.split(/[: ]/)
                delegate: StyledText {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: modelData.match(/am|pm/i) ?
                        Appearance.font.pixelSize.smaller :
                        Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: modelData.padStart(2, "0")
                }
            }
        }
    }

    // Horizontal
    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: RowLayout {
            spacing: 4
            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: DateTime.longDate
            }
            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: "•"
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                text: DateTime.time
                font.letterSpacing: -0.4
                font.features: { "tnum": 1 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        ClockWidgetPopup {
            hoverTarget: mouseArea
            today: root.today
        }
    }
}