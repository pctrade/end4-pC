import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    radius: Appearance.rounding.small
    property color bgColor: Appearance.colors.colSurfaceContainerHigh
    property color fgColor: Appearance.colors.colOnSurfaceVariant
    color: root.bgColor
    implicitWidth: columnLayout.implicitWidth + 14 * 2
    implicitHeight: columnLayout.implicitHeight + 10 * 2
    Layout.fillWidth: true
    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: Appearance.spacing.normal
        }
        spacing: -4

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                id: title
                Layout.alignment: Qt.AlignLeft
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.fgColor
            }

            Item { Layout.fillWidth: true }

            MaterialSymbol {
                id: symbol
                Layout.alignment: Qt.AlignRight
                fill: 0
                iconSize: Appearance.font.pixelSize.normal
                color: root.fgColor
            }
        }

        StyledText {
            id: value
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.fgColor
            opacity: 0.6
        }
    }
}