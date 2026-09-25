import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The icon for what was copied (IslandEvents.clipKind): the color itself for a color, the brand for a known
// link or a language (YouTube, GitHub, Python…), otherwise a Material Symbol for the kind (email, phone, map…).
// Everything sits on the same round tile, so switching kinds doesn't jump.
Item {
    id: clipIcon
    property var kind: ({ kind: "text", icon: "content_paste" })
    property real size: 28
    // `tinted` paints the plain symbols in the secondary container colours (the pill); off for a quiet list row
    property bool tinted: true

    readonly property bool isSwatch: clipIcon.kind?.swatch !== undefined
    readonly property bool hasBrand: (clipIcon.kind?.brand ?? "") !== ""
    implicitWidth: clipIcon.size
    implicitHeight: clipIcon.size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: clipIcon.isSwatch ? clipIcon.kind.swatch
            : clipIcon.hasBrand ? ColorUtils.transparentize(clipIcon.kind.color || Appearance.colors.colOnLayer0, 0.84)
            : clipIcon.tinted ? Appearance.colors.colSecondaryContainer : "transparent"
        border.width: clipIcon.isSwatch ? 2 : 0
        border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.75)

        Behavior on color {
            ColorAnimation { duration: IslandMotion.short }
        }
    }

    DiBrandIcon {
        anchors.centerIn: parent
        visible: clipIcon.hasBrand && !clipIcon.isSwatch
        source: clipIcon.hasBrand ? Quickshell.shellPath(`assets/island/apps/${clipIcon.kind.brand}.svg`) : ""
        size: Math.round(clipIcon.size * 0.52)
        color: clipIcon.kind?.color || Appearance.colors.colOnLayer0
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: !clipIcon.hasBrand && !clipIcon.isSwatch
        text: clipIcon.kind?.icon ?? "content_paste"
        iconSize: Math.round(clipIcon.size * 0.55)
        fill: 1
        color: clipIcon.tinted ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
        opacity: clipIcon.tinted ? 1 : 0.6
    }
}
