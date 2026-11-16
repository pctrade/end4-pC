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
    // App buttons: hide while the right-click menu is open, and when hovering
    // opens the window preview instead (its header names the app).
    property var app: null
    property var contextMenu: null

    readonly property bool wanted: (Config.options.dock.showTooltips ?? true)
        && root.show && root.text.length > 0
        && !(root.contextMenu?.isOpen ?? false)
        && !(root.app && DockStyle.previewsFor(root.app))

    // Shows as soon as an icon is hovered (no delay), with a short fade in and out.
    readonly property int fadeInDuration: 100
    readonly property int fadeOutDuration: 150
    property bool fadingOut: false
    onWantedChanged: {
        root.fadingOut = !root.wanted;
        if (root.fadingOut)
            fadeOutTimer.restart();
    }
    Timer {
        id: fadeOutTimer
        interval: root.fadeOutDuration
        onTriggered: root.fadingOut = false
    }

    Loader {
        active: (root.wanted || root.fadingOut) && root.QsWindow.window !== null
        sourceComponent: PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            mask: Region { item: null }

            // Taken once when the tooltip opens, like the preview popup's
            // cachedCenter, so magnification does not reposition it every frame.
            property point center: Qt.point(0, 0)
            Component.onCompleted: {
                const t = root.parent;
                center = t.mapToItem(null, t.width / 2, t.height / 2);
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
                Component.onCompleted: fadeIn.start()
                NumberAnimation on opacity {
                    id: fadeIn
                    running: false
                    to: 1
                    duration: root.fadeInDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation on opacity {
                    id: fadeOut
                    running: false
                    to: 0
                    duration: root.fadeOutDuration
                    easing.type: Easing.OutCubic
                }
                Connections {
                    target: root
                    function onWantedChanged() {
                        if (root.wanted) {
                            fadeOut.stop();
                            fadeIn.restart();
                        } else {
                            fadeIn.stop();
                            fadeOut.restart();
                        }
                    }
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
