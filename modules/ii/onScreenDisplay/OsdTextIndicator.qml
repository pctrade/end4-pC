import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string icon
    required property string name
    required property string value

    implicitWidth: Appearance.sizes.osdWidth + 4 * Appearance.sizes.elevationMargin
    implicitHeight: indicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: indicator
    }
    Rectangle {
        id: indicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer0
        implicitWidth: contentRow.implicitWidth + 30
        implicitHeight: contentRow.implicitHeight + 18

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.icon
                iconSize: 25
                color: Appearance.colors.colOnLayer0
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Appearance.sizes.osdWidth - 50
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.name
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.value
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
            }
        }
    }
}
