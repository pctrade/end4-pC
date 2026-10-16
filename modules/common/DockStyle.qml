pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property string position: Config.options.dock.position ?? "bottom"
    readonly property bool vertical: position !== "bottom"

    function mTop(inner, outer, alongStart) {
        return vertical ? (alongStart ?? 0) : inner;
    }

    function mBottom(inner, outer, alongEnd) {
        return vertical ? (alongEnd ?? 0) : outer;
    }

    function mLeft(inner, outer, alongStart) {
        return vertical ? (position === "left" ? outer : inner) : (alongStart ?? 0);
    }

    function mRight(inner, outer, alongEnd) {
        return vertical ? (position === "left" ? inner : outer) : (alongEnd ?? 0);
    }

    readonly property real padding: 5
    readonly property real spacing: 3
    readonly property real backgroundPadding: 5
    readonly property real buttonSize: iconSize + 13
    readonly property real buttonSpacing: 1
    readonly property real defaultIconSize: 33
    readonly property real iconSize: Config.options.dock.iconSize
    readonly property real iconSpacing: Config.options.dock.iconSpacing
    readonly property real buttonBase: iconSize + 17
    readonly property real iconInset: padding + 8
    readonly property real appsButtonInnerInset: padding + 10
    readonly property real appsButtonOuterInset: padding + 7
    readonly property real pinButtonSize: 35
    readonly property real pinnedInnerMargin: 2
    readonly property real mediaInnerMargin: 12
    readonly property real mediaOuterMargin: 8
    readonly property real pinInnerMargin: 3
    readonly property real buttonInnerMargin: Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut
    readonly property bool hug: Config.options.dock.style === "hug"
    readonly property bool magnifying: position === "bottom" && Config.options.dock.magnify
    readonly property real magnification: Math.max(1, Math.min(2.2, Config.options.dock.magnification ?? 1.2))
    readonly property real headroom: magnifying ? Math.ceil((magnification - 1) * (iconSize + 14)) + 6 : 0
    readonly property real thickness: (Config.options.dock.height ?? 70) + (iconSize - defaultIconSize) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut
    readonly property real activeSpacing: -4
    readonly property real mediaLength: 240
    readonly property real dotWidth: 10
    readonly property real dotHeight: 4
    readonly property real dotSpacing: 3
    readonly property real dotsGap: 2
    readonly property real dotsSideGap: 5
    readonly property real windowGap: Appearance.sizes.hyprlandGapsOut
    readonly property real separatorInnerMargin: Appearance.sizes.elevationMargin + padding + Appearance.rounding.normal - 4
    readonly property real separatorOuterMargin: Appearance.sizes.hyprlandGapsOut + padding + Appearance.rounding.normal
    readonly property real separatorInset: Appearance.sizes.elevationMargin + padding + Appearance.rounding.normal
    readonly property real zone: thickness - Appearance.sizes.elevationMargin - (hug ? Appearance.sizes.hyprlandGapsOut : 0) + windowGap
}
