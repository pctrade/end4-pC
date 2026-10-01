import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.modules.common.functions

// Bar utility button: cookie shape at rest, filled pill on hover.
Item {
    id: root
    signal clicked(event: var)
    property alias iconText: symbol.text
    property bool isActive: false
    property bool forceHovered: false

    implicitWidth: vertical ? 26 : (hovered ? 54 : 26)
    implicitHeight: vertical ? (hovered ? 54 : 26) : 26

    property bool hovered: mouseArea.containsMouse || forceHovered

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    scale: mouseArea.pressed ? 0.9 : 1
    Behavior on scale {
        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    MaterialShape {
        anchors.centerIn: parent
        implicitSize: 26
        shape: MaterialShape.Shape.Cookie7Sided
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)
        opacity: root.hovered ? 0 : 1
        rotation: root.hovered ? 60 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    MaterialSymbol {
        id: symbol
        anchors.centerIn: parent
        iconSize: Appearance.font.pixelSize.large
        fill: root.hovered ? 1 : 0
        color: root.hovered ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (e) => root.clicked(e)
    }
}
