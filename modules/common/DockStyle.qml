pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common.functions

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

    // True when hovering this app's button opens the window preview popup.
    function previewsFor(app) {
        return WM.compositor === "hyprland"
            && (Config.options.dock.showPreviews ?? true)
            && (app?.toplevels?.length ?? 0) > 0;
    }

    readonly property color backgroundColor: (hug && Config.options.dock.followFrameColor && Config.options.bar.showFrame)
        ? Appearance.getColorFromName(Config.options.bar.frameColor)
        : Appearance.getColorFromName(Config.options.dock.backgroundColor)

    // Shared look for the dock's popups (tooltips and window previews), so they
    // read as part of the dock. Popups get no compositor blur, so the colour is
    // made opaque, and a border keeps the edge visible over dark windows.
    // OLED keeps the black used by the dock's other popups (e.g. the context menu).
    readonly property color popupColor: Config.options.appearance.uiBackground === "oled"
        ? "#000000"
        : ColorUtils.applyAlpha(backgroundColor, 1)
    readonly property color popupBorderColor: Appearance.colors.colLayer0Border
    // Theme text colour when the popup is as light/dark as the theme, inverse otherwise.
    readonly property color popupTextColor: ColorUtils.isDark(popupColor) === Appearance.m3colors.darkmode
        ? Appearance.colors.colOnLayer0
        : Appearance.m3colors.m3inverseOnSurface
    readonly property color popupSubtextColor: ColorUtils.transparentize(popupTextColor, 0.35)

    // Edge of the dock popups that faces the dock, along the screen edge the dock
    // is on; popups open in this direction, away from that edge.
    readonly property int popupAwayEdge: position === "left" ? Edges.Right
        : position === "right" ? Edges.Left
        : Edges.Top
    // Space between the dock background and its popups (tooltip, preview card).
    readonly property real popupGap: 6
    // Where popups start, in dock-window coordinates. The dock background sits
    // one elevation margin inside the window's inner edge (room for its shadow).
    // Side docks: x of the popup's near edge.
    function popupSideEdge(windowWidth) {
        return position === "left"
            ? windowWidth - Appearance.sizes.elevationMargin + popupGap
            : Appearance.sizes.elevationMargin - popupGap;
    }
    // Bottom dock: y of the popup's bottom edge. With magnification the icons
    // grow into the space above the dock, so popups stay above the window.
    readonly property real popupBottomEdge: magnifying ? 0 : Appearance.sizes.elevationMargin - popupGap

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
