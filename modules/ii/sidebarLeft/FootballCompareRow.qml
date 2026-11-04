import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property string label: ""
    property real homeValue: 0
    property real awayValue: 0
    property real maxValue: 100
    property string suffix: "%"
    property int decimals: 0
    property color homeColor: Appearance.colors.colPrimary
    property color awayColor: Appearance.colors.colTertiary

    function fmt(value) {
        return value.toFixed(root.decimals) + root.suffix
    }

    readonly property bool homeLeads: root.homeValue > root.awayValue
    readonly property bool awayLeads: root.awayValue > root.homeValue

    spacing: 4

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            text: root.fmt(root.homeValue)
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: root.homeLeads ? Font.Bold : Font.Normal
            color: root.homeLeads ? root.homeColor : Appearance.colors.colOnLayer2
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: root.fmt(root.awayValue)
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: root.awayLeads ? Font.Bold : Font.Normal
            color: root.awayLeads ? root.awayColor : Appearance.colors.colOnLayer2
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 8
            radius: 4
            color: Appearance.colors.colLayer3

            Rectangle {
                anchors.right: parent.right
                height: parent.height
                radius: 4
                width: parent.width * Math.min(1, root.homeValue / Math.max(0.0001, root.maxValue))
                color: root.homeColor
                opacity: root.homeLeads ? 1 : 0.55
                Behavior on width {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 8
            radius: 4
            color: Appearance.colors.colLayer3

            Rectangle {
                anchors.left: parent.left
                height: parent.height
                radius: 4
                width: parent.width * Math.min(1, root.awayValue / Math.max(0.0001, root.maxValue))
                color: root.awayColor
                opacity: root.awayLeads ? 1 : 0.55
                Behavior on width {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
