import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// A thin, invisible strip at the very top of the screen, right above the island. A floating bar sits a few pixels
// below the edge, so a pointer pushed against the edge leaves the bar; this strip is what "insisting" upward touches.
// Only the part over the island takes input, so the rest of the top edge is untouched.
Scope {
    id: edge
    required property Item di

    LazyLoader {
        active: edge.di.visible && !edge.di.buried && !Config.options.bar.bottom && !edge.di.vertical

        component: PanelWindow {
            id: strip

            screen: edge.di.QsWindow.window?.screen ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:islandEdge"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 8
            mask: Region { item: zone }

            Item {
                id: zone
                readonly property Item surface: edge.di.surfaceItem
                readonly property real surfaceX: {
                    zone.surface.width
                    edge.di.implicitWidth
                    return edge.di.QsWindow.mapFromItem(zone.surface, 0, 0).x
                }
                x: zone.surfaceX
                width: zone.surface.width
                height: strip.height

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) edge.di.startInsist()
                        else edge.di.releaseInsist()
                    }
                }
            }
        }
    }
}
