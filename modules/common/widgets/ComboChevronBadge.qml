import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool open: false
    property color colClosed: Appearance.colors.colSecondaryContainer
    property color colOpen: Appearance.colors.colPrimary
    property color colIconClosed: Appearance.colors.colOnSecondaryContainer
    property color colIconOpen: Appearance.colors.colOnPrimary

    width: open ? height : height * 1.2
    color: open ? colOpen : colClosed
    topLeftRadius: open ? height / 2 : Appearance.rounding.unsharpenmore
    bottomLeftRadius: topLeftRadius
    topRightRadius: height / 2
    bottomRightRadius: height / 2

    Behavior on width {
        NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
    Behavior on topLeftRadius {
        NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "keyboard_arrow_down"
        iconSize: Appearance.font.pixelSize.larger
        color: root.open ? root.colIconOpen : root.colIconClosed
        rotation: root.open ? 180 : 0
        Behavior on rotation {
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }
}
