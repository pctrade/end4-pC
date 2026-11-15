pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

// Name tooltip for a dock button (its parent). It opens on the side of the dock
// that faces away from the screen edge: above a bottom dock, right of a left
// dock, and left of a right dock. Input passes through it, so it never steals hover.
Item {
    id: root
    property string text: ""
    property bool show: false

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
        interval: 250
        onTriggered: root.shown = root.wanted
    }

    Loader {
        active: root.shown && root.QsWindow.window !== null
        sourceComponent: PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            mask: Region { item: null }

            // Taken once when the tooltip opens, like the preview popup's
            // cachedCenter, so magnification does not reposition it every frame.
            readonly property point center: {
                const t = root.parent;
                return t.mapToItem(null, t.width / 2, t.height / 2);
            }

            // Same distance from the dock as the window preview card in DragApps.qml.
            anchor {
                window: root.QsWindow.window
                adjustment: PopupAdjustment.Slide
                rect.x: DockStyle.vertical ? DockStyle.popupSideEdge(root.QsWindow.window?.width ?? 0) : popup.center.x
                rect.y: DockStyle.vertical ? popup.center.y : DockStyle.popupBottomEdge
                rect.width: 1
                rect.height: 1
                edges: DockStyle.popupAwayEdge
                gravity: DockStyle.popupAwayEdge
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Rectangle {
                id: content
                anchors.centerIn: parent
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
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

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
