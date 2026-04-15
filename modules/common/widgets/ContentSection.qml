import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property var shape: MaterialShape.Shape.Clover4Leaf
    property string title
    property string icon: ""
    property var bgColor: Appearance.colors.colSecondaryContainer
    default property alias data: sectionContent.data

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        spacing: 6
        MaterialShapeWrappedMaterialSymbol {
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            wrappedShape: root.shape
            color: bgColor
        }
        StyledText {
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.Medium
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
    ColumnLayout {
        id: sectionContent
        Layout.fillWidth: true
        spacing: 4
    }
}