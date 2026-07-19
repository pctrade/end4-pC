import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property color cardBgColor: Appearance.colors.colLayer1 
    property color labelColor: Appearance.colors.colOnSurfaceVariant
    property color valueColor: Appearance.colors.colOnSurface
    property color iconContainerColor: Appearance.colors.colSecondaryContainer
    property color iconColor: Appearance.colors.colOnSecondaryContainer
    property var iconShape: MaterialShape.Shape.Clover4Leaf

    property var clickAction: null
    property bool pointingHandCursor: true

    implicitWidth: 260
    implicitHeight: 80
    radius: Appearance.rounding.large 
    color: root.cardBgColor
    border.width: 0

    RowLayout {
        id: cardRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16 

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            wrappedShape: root.iconShape
            text: root.icon
            iconSize: Appearance.font.pixelSize.large
            colSymbol: root.iconColor
            color: root.iconContainerColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4 

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.labelColor
                elide: Text.ElideRight
                opacity: 0.6
            }

            StyledText {
                Layout.fillWidth: true
                text: root.value
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: root.valueColor
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickAction !== null
        cursorShape: root.clickAction !== null ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.clickAction) root.clickAction();
        }
    }
}