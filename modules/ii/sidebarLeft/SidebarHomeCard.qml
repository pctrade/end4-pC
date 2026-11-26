import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

SidebarPop {
    id: root

    property string icon: "apps"
    property string title: ""
    property string subtitle: ""
    property var decoShape: MaterialShape.Shape.Cookie9Sided
    property color colContainer: Appearance.colors.colPrimaryContainer
    property color colOnContainer: Appearance.colors.colOnPrimaryContainer
    property color colAccent: Appearance.colors.colPrimary
    property color colOnAccent: Appearance.colors.colOnPrimary
    property bool live: false

    signal clicked()

    implicitHeight: 112

    ClippingRectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: mouse.containsMouse ? ColorUtils.mix(root.colContainer, root.colAccent, 0.88) : root.colContainer

        Behavior on color {
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MaterialShape {
            shape: root.decoShape
            implicitSize: 118
            color: root.colAccent
            opacity: 0.9
            anchors.right: parent.right
            anchors.rightMargin: -34
            anchors.top: parent.top
            anchors.topMargin: -34
        }

        MaterialSymbol {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 12
            text: root.icon
            fill: 1
            iconSize: 30
            color: root.colOnAccent
        }

        Rectangle {
            visible: root.live
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 14
            width: 10
            height: 10
            radius: 5
            color: root.colAccent
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 14
            }
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: root.colOnContainer
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colOnContainer
                opacity: 0.7
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
