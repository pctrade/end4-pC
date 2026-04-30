import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(modelData)
            property list<HyprlandWorkspace> monitorWorkspaces: Hyprland.workspaces.values.filter(
                ws => ws.monitor && ws.monitor.name === hyprMonitor.name
            )
            property bool fullscreenOnThisMonitor: monitorWorkspaces.some(
                ws => ws.active && ws.toplevels.values.some(w => w.wayland?.fullscreen)
            )

            property bool reveal: {
                if (fullscreenOnThisMonitor)
                    return Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse
                return root.pinned
                    || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse)
                    || activeAppsArea.requestDockShow
                    || dragSlots.requestDockShow
                    || (!ToplevelManager.activeToplevel?.activated)
            }

            exclusiveZone: (root.pinned && !fullscreenOnThisMonitor)
                ? implicitHeight - Appearance.sizes.hyprlandGapsOut
                  - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)
                : 0

            anchors { bottom: true; left: true; right: true }
            implicitWidth: dockBackground.implicitWidth
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            implicitHeight: (Config.options?.dock.height ?? 70)
                + Appearance.sizes.elevationMargin
                + Appearance.sizes.hyprlandGapsOut

            mask: Region { item: dockMouseArea }

            MouseArea {
                id: dockMouseArea
                height: parent.height
                anchors {
                    top: parent.top
                    topMargin: dockRoot.reveal
                        ? 0
                        : Config.options?.dock.hoverToReveal
                            ? (dockRoot.implicitHeight - Config.options.dock.hoverRegionHeight)
                            : (dockRoot.implicitHeight + 1)
                    horizontalCenter: parent.horizontalCenter
                }
                implicitWidth: dockHoverRegion.implicitWidth + Appearance.sizes.elevationMargin * 2
                hoverEnabled: true

                Behavior on anchors.topMargin {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth

                    Item {
                        id: dockBackground
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        implicitWidth: dockRow.implicitWidth + 5 * 2
                        height: parent.height
                            - Appearance.sizes.elevationMargin
                            - Appearance.sizes.hyprlandGapsOut

                        StyledRectangularShadow {
                            target: dockVisualBackground
                            visible: false
                        }

                        Rectangle {
                            id: dockVisualBackground
                            property real margin: Appearance.sizes.elevationMargin
                            anchors.fill: parent
                            anchors.topMargin:    Appearance.sizes.elevationMargin
                            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
                            color: Config.options.dock.showBackground
                                   ? Appearance.colors.colLayer0 : "transparent"
                            border.width: Config.options.dock.showBackground ? 1 : 0
                            border.color: Appearance.colors.colLayer0Border
                            radius: Appearance.rounding.large + 3
                        }

                        RowLayout {
                            id: dockRow
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            property real padding: 5

                            VerticalButtonGroup {
                                Layout.topMargin: 3
                                Layout.leftMargin:  root.pinned
                                    ? Appearance.sizes.hyprlandGapsOut + 4
                                    : Appearance.sizes.hyprlandGapsOut
                                Layout.rightMargin: root.pinned
                                    ? Appearance.sizes.hyprlandGapsOut + 4
                                    : Appearance.sizes.hyprlandGapsOut

                                GroupButton {
                                    baseWidth: 35; baseHeight: 35
                                    clickedWidth: baseWidth; clickedHeight: baseHeight + 20
                                    buttonRadius: Appearance.rounding.normal
                                    toggled: root.pinned
                                    onClicked: root.pinned = !root.pinned
                                    contentItem: MaterialSymbol {
                                        text: "keep"
                                        horizontalAlignment: Text.AlignHCenter
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: root.pinned
                                               ? Appearance.m3colors.m3onPrimary
                                               : Appearance.colors.colOnLayer0
                                    }
                                }
                            }

                            DockSeparator {}

                            DragApps {
                                id: dragSlots
                                Layout.fillHeight: true
                                Layout.topMargin: 0

                                pinnedApps:    Config.options?.dock.pinnedApps ?? []
                                buttonPadding: dockRow.padding
                                btnSize:       46
                                btnSpacing:    2
                            }

                            DockSeparator {
                                visible: activeAppsArea.hasActiveUnpinned
                            }

                            Item {
                                id: activeAppsArea
                                Layout.fillHeight: true
                                Layout.topMargin: 0

                                property bool requestDockShow: false

                                property var activeUnpinned: {
                                    return TaskbarApps.apps.filter(
                                        a => !a.pinned
                                          && a.appId !== "SEPARATOR"
                                          && a.toplevels.length > 0
                                    )
                                }
                                property bool hasActiveUnpinned: activeUnpinned.length > 0 || dockMedia.visible

                                implicitWidth:  activeRow.implicitWidth
                                implicitHeight: parent.height

                                Behavior on implicitWidth {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }

                                RowLayout {
                                    id: activeRow
                                    anchors.fill: parent
                                    spacing: -4

                                    DockMedia {
                                        id: dockMedia
                                        visible: Config.options.dock.showMedia
                                        Layout.fillHeight: true
                                        Layout.topMargin: 11
                                        Layout.bottomMargin: 6
                                        Layout.rightMargin: 0
                                        Layout.leftMargin: 0
                                        buttonPadding: dockRow.padding
                                    }

                                    Repeater {
                                        model: activeAppsArea.activeUnpinned
                                        delegate: DockAppButton {
                                            required property var modelData
                                            appToplevel: modelData
                                            Layout.topMargin: 0
                                            appListRoot: appListBridge
                                            topInset:    dockRow.padding
                                            bottomInset: dockRow.padding
                                        }
                                    }
                                }

                                QtObject {
                                    id: appListBridge
                                    property Item lastHoveredButton: null
                                    property bool buttonHovered: false
                                }
                            }

                            DockSeparator {
                                Layout.leftMargin: -3
                            }

                            DockButton {
                                Layout.fillHeight: true
                                Layout.topMargin: 0
                                Layout.leftMargin: Config.options.dock.showMedia ? -10 : -4
                                Layout.rightMargin: Config.options.dock.showMedia ? -3 : 0
                                onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                                topInset:    dockRow.padding
                                bottomInset: Appearance.sizes.hyprlandGapsOut + dockRow.padding
                                contentItem: MaterialSymbol {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: parent.width / 2
                                    text: "apps"
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
