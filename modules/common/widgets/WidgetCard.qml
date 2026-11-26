import QtQuick
import qs.modules.common

Rectangle {
    id: root
    required property var widget
    property bool blurred: Config.options.background.widgets.blurWidgets
    property bool shadowed: Config.options.background.widgets.shadow
    property color tint: Appearance.colors.colLayer1
    property real tintOpacity: 0.55
    property bool glass: true

    radius: Appearance.rounding?.verylarge ?? 30
    color: glass && Config.options.background.widgets.glass.enable ? "transparent" : Appearance.colors.colPrimaryContainer

    StyledRectangularShadow {
        target: root
        z: -2
        visible: root.shadowed
    }

    FrostedGlass {
        anchors.fill: parent
        blurSource: root.widget.wallpaperItem
        cardRadius: root.radius
        tint: Appearance.colors.colPrimaryContainer
        trackX: root.widget.x + root.x
        trackY: root.widget.y + root.y
        visible: root.glass && Config.options.background.widgets.glass.enable
    }

    FastBlurred {
        anchors.fill: parent
        anchors.margins: root.blurred ? -1 : 0
        blurSource: root.widget.wallpaperItem
        cardRadius: root.radius + (root.blurred ? 1 : 0)
        tint: root.tint
        tintOpacity: root.tintOpacity
        trackX: root.widget.x + root.x
        trackY: root.widget.y + root.y
        visible: root.blurred && !(root.glass && Config.options.background.widgets.glass.enable)
    }
}
