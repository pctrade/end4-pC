import QtQuick
import qs.modules.common

Item {
    id: root

    required property Item anchorItem
    property bool hoverActive: false
    property bool locked: false
    property string icon: "rotate_right"
    property real handleSize: 22
    property int quarterTurns: 0
    property string corner: "bottomRight"
    readonly property bool engaged: area.containsMouse || area.pressed

    signal clicked()

    width: root.handleSize
    height: root.handleSize
    anchors {
        horizontalCenter: root.anchorItem.right
        verticalCenter: root.corner === "topRight" ? root.anchorItem.top : root.anchorItem.bottom
        horizontalCenterOffset: -2
        verticalCenterOffset: root.corner === "topRight" ? 2 : -2
    }
    opacity: (root.hoverActive || root.engaged) ? 1 : 0
    visible: opacity > 0 && !root.locked
    scale: root.engaged ? 1.18 : 1

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }
    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#ffffff"
        border.width: 2
        border.color: "#101010"
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.icon
        iconSize: 13
        color: "#101010"
        rotation: root.quarterTurns * 90

        Behavior on rotation {
            SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.5 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.quarterTurns += 1
            root.clicked()
        }
    }
}
