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

            // Same distance from the dock as the window preview card in DragApps.qml,
            // so the label does not jump when moving between running and closed apps.
            readonly property real sideEdge: DockStyle.position === "left"
                ? DockStyle.zone + Appearance.sizes.hyprlandGapsOut
                : (root.QsWindow.window?.width ?? 0) - DockStyle.zone - Appearance.sizes.hyprlandGapsOut

            anchor {
                window: root.QsWindow.window
                adjustment: PopupAdjustment.Slide
                rect.x: DockStyle.vertical ? popup.sideEdge : popup.point.x
                rect.y: DockStyle.vertical ? popup.point.y : 0
                rect.width: 1
                rect.height: 1
                edges: DockStyle.position === "left" ? Edges.Right
                    : DockStyle.position === "right" ? Edges.Left
                    : Edges.Top
                gravity: DockStyle.position === "left" ? Edges.Right
                    : DockStyle.position === "right" ? Edges.Left
                    : Edges.Top
            }

            // Bottom dock: the card ends one elevation margin above the dock window,
            // like the preview card. The extra space is transparent and click-through.
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight + (DockStyle.vertical ? 0 : Appearance.sizes.elevationMargin)

            Rectangle {
                id: content
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: label.implicitWidth + 24
                implicitHeight: label.implicitHeight + 12
                radius: Appearance.rounding.small
                color: DockStyle.popupColor
                border.width: 1
                border.color: DockStyle.popupBorderColor

                opacity: 0
                scale: 0.92
                transformOrigin: DockStyle.position === "left" ? Item.Left
                    : DockStyle.position === "right" ? Item.Right
                    : Item.Bottom
                Component.onCompleted: { opacity = 1; scale = 1; }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    font.hintingPreference: Font.PreferNoHinting
                    color: DockStyle.popupTextColor
                }
            }
        }
    }
}
