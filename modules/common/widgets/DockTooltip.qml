pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

// Name tooltip for a dock button. It opens on the side of the dock that faces
// away from the screen edge: above a bottom dock, right of a left dock, and
// left of a right dock. Input passes through it, so it never steals hover.
Item {
    id: root
    property Item target: parent
    property string text: ""
    property bool show: false
    property int delay: 250
    // Space between the button's top edge and the tooltip (bottom dock).
    property real gap: 4
    // Space between the dock background and the tooltip (left and right docks).
    property real sideGap: 8

    readonly property bool wanted: (Config.options.dock.showTooltips ?? true) && root.show && root.text.length > 0
    property bool shown: false

    onWantedChanged: {
        if (root.wanted) {
            showTimer.restart();
        } else {
            showTimer.stop();
            root.shown = false;
        }
    }

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.shown = root.wanted
    }

    Loader {
        active: root.shown && root.target !== null && root.QsWindow.window !== null
        sourceComponent: PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            mask: Region { item: null }

            // Re-evaluated when the target moves or scales (magnification),
            // because mapToItem() alone is not tracked by the binding engine.
            readonly property point point: {
                const t = root.target;
                void (t.x + t.y + t.width + t.height + t.scale + (t.magnifyValue?.shift ?? 0));
                if (DockStyle.position === "left")
                    return t.mapToItem(null, t.width, t.height / 2);
                if (DockStyle.position === "right")
                    return t.mapToItem(null, 0, t.height / 2);
                return t.mapToItem(null, t.width / 2, 0);
            }

            // Side docks: the dock background ends one elevation margin inside the
            // window's inner edge. Using it keeps left and right symmetric, because
            // the buttons sit off-centre inside the background.
            readonly property real sideEdge: DockStyle.position === "left"
                ? (root.QsWindow.window?.width ?? 0) - Appearance.sizes.elevationMargin + root.sideGap
                : Appearance.sizes.elevationMargin - root.sideGap

            anchor {
                window: root.QsWindow.window
                adjustment: PopupAdjustment.Slide
                rect.x: DockStyle.vertical ? popup.sideEdge : popup.point.x
                rect.y: DockStyle.vertical ? popup.point.y : popup.point.y - root.gap
                rect.width: 1
                rect.height: 1
                edges: DockStyle.position === "left" ? Edges.Right
                    : DockStyle.position === "right" ? Edges.Left
                    : Edges.Top
                gravity: DockStyle.position === "left" ? Edges.Right
                    : DockStyle.position === "right" ? Edges.Left
                    : Edges.Top
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            StyledToolTipContent {
                id: content
                anchors.centerIn: parent
                text: root.text
                shown: false
                Component.onCompleted: shown = true
            }
        }
    }
}
