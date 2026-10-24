import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A rounded card of the daily clock's bento variant, frosted like the other widgets when glass is on
Item {
    id: root
    // The desktop widget: its wallpaper is what the glass blurs
    property Item widget: null
    property color color: Appearance.colors.colSurfaceContainer
    default property alias content: background.data

    readonly property real radius: Appearance.rounding.large
    readonly property bool glass: root.widget !== null && Config.options.background.widgets.glass.enable
    readonly property bool blurred: root.widget !== null && Config.options.background.widgets.blurWidgets && !root.glass

    Layout.fillWidth: true

    StyledRectangularShadow {
        target: background
        visible: Config.options.background.widgets.shadow
    }

    FrostedGlass {
        anchors.fill: parent
        visible: root.glass
        blurSource: root.widget?.wallpaperItem ?? null
        cardRadius: root.radius
        tint: root.color
        trackX: (root.widget?.x ?? 0) + root.x
        trackY: (root.widget?.y ?? 0) + root.y
    }

    FastBlurred {
        anchors.fill: parent
        visible: root.blurred
        blurSource: root.widget?.wallpaperItem ?? null
        cardRadius: root.radius
        tint: root.color
        tintOpacity: 0.55
        trackX: (root.widget?.x ?? 0) + root.x
        trackY: (root.widget?.y ?? 0) + root.y
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        color: root.glass || root.blurred ? "transparent" : root.color
    }
}
