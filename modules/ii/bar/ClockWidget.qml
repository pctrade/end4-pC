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

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : rowLayout.implicitWidth + 12
    implicitHeight: vertical ? clockColumn.implicitHeight : Appearance.sizes.barHeight

    // Vertical
    ColumnLayout {
        id: clockColumn
        visible: root.vertical
        anchors.centerIn: parent
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

    // Horizontal
    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.centerIn: parent
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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }
}