import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property int iconShape: MaterialShape.Shape.Circle
    property color iconColor: Appearance.colors.colPrimary

    implicitWidth: 100
    implicitHeight: cardCol.implicitHeight + 24
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    ColumnLayout {
        id: cardCol
        anchors { fill: parent; margins: 12 }
        spacing: 4

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignRight
            shape: root.iconShape
            text: root.icon
            iconSize: Appearance.font.pixelSize.large
            implicitSize: 32
            color: Qt.alpha(root.iconColor, 0.2)
            colSymbol: root.iconColor
        }

        Item { Layout.fillHeight: true }

        StyledText {
            Layout.fillWidth: true
            text: root.value
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight
        }

        StyledText {
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }
}
