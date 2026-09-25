import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A fullscreen window buries the bar, and with it every notification. This leaves a hairline at the very top
// carrying the colour of what is happening; pushing the pointer against it opens a strip with the last events,
// so a video or a game no longer means flying blind.
Scope {
    id: peek
    required property Item di

    readonly property var screenData: HyprlandData.monitors.find(m => m.name === peek.di.QsWindow.window?.screen?.name)
    readonly property bool fullscreenHere: HyprlandData.workspaceById[peek.screenData?.activeWorkspace?.id]?.hasfullscreen ?? false

    LazyLoader {
        active: peek.fullscreenHere && !Config.options.bar.bottom && !peek.di.vertical
            && (Config.options.bar.dynamicIsland.fullscreenPeek ?? true)

        component: PanelWindow {
            id: strip

            readonly property var latest: IslandEvents.eventLog[0] ?? null
            readonly property bool fresh: strip.latest !== null && Date.now() - strip.latest.time < 12000
            readonly property color tone: strip.latest?.kind === "error" ? Appearance.colors.colError
                : strip.latest?.kind === "notification" ? Appearance.colors.colPrimary
                : IslandEvents.colorSuccess

            screen: peek.di.QsWindow.window?.screen ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:islandPeek"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 44
            mask: Region { item: hover.hovered || strip.fresh ? panel : hairline }

            // The hairline: always there, coloured by the last event, breathing while it is fresh
            Rectangle {
                id: hairline
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: hover.hovered ? 0 : (strip.fresh ? 220 : 120)
                height: 3
                radius: 1.5
                color: strip.tone
                opacity: hover.hovered ? 0 : (strip.fresh ? 0.95 : 0.35)

                Behavior on width {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 240 }
                }

                SequentialAnimation on opacity {
                    running: strip.fresh && !hover.hovered
                    loops: 3
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            // Pushed against the edge: the last events, without leaving the fullscreen window
            Rectangle {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                y: hover.hovered ? 4 : -40
                implicitWidth: Math.min(520, panelRow.implicitWidth + 28)
                implicitHeight: 34
                radius: 17
                color: Appearance.colors.colLayer0
                opacity: hover.hovered ? 1 : 0

                Behavior on y {
                    NumberAnimation { duration: 280; easing.type: Easing.OutBack }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                RowLayout {
                    id: panelRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: strip.latest?.icon ?? "bedtime"
                        iconSize: 16
                        fill: 1
                        color: strip.tone
                    }
                    StyledText {
                        text: strip.latest?.title ?? Translation.tr("Nothing new")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                    StyledText {
                        visible: (strip.latest?.subtitle ?? "") !== ""
                        text: strip.latest?.subtitle ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.maximumWidth: 180
                    }
                    StyledText {
                        visible: IslandEvents.eventLog.length > 1
                        text: `+${IslandEvents.eventLog.length - 1}`
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }
                }
            }

            HoverHandler {
                id: hover
            }
        }
    }
}
