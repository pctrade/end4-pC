import QtQuick
import qs.modules.common

Item {
    id: root

    property color swatchColor: "white"
    property bool selected: false
    property color ringColor: Appearance.colors.colOnLayer0

    signal clicked()

    implicitWidth: 40
    implicitHeight: 40

    Rectangle {
        anchors.centerIn: parent
        width: root.selected ? parent.width : parent.width - 8
        height: width
        radius: root.selected ? Appearance.rounding.normal : width / 2
        color: "transparent"
        border.width: root.selected ? 2 : 0
        border.color: root.ringColor

        Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 8
        height: width
        radius: root.selected ? Appearance.rounding.normal - 4 : width / 2
        color: root.swatchColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
