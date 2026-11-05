pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: bar

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            return screens.filter(screen => {
                const config = Config.barForScreen(screen.name);
                const listed = !list || list.length === 0 || list.includes(screen.name);
                return listed && config.enabled !== false && !config.vertical;
            });
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked && !GlobalStates.startupLockPending
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData
                readonly property var barConfig: Config.barForScreen(screen?.name)

                Timer {
                    id: showBarTimer
                    interval: (barRoot.barConfig.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!barRoot.barConfig.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }

                property bool showCorners: !barRoot.barConfig.autoHide.enable || mustShow

                Timer {
                    id: cornerRevealTimer
                    interval: 65
                    onTriggered: barRoot.showCorners = true
                }

                onMustShowChanged: {
                    if (!barRoot.barConfig.autoHide.enable) return;
                    if (mustShow) {
                        cornerRevealTimer.restart()
                    } else {
                        cornerRevealTimer.stop()
                        barRoot.showCorners = false
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || (barRoot.barConfig.autoHide.enable && GlobalStates.isFrameHovered(barRoot.screen?.name, barRoot.barConfig.bottom ? "bottom" : "top"))
                property var thisMonitorData: HyprlandData.monitors.find(m => m.name === barRoot.screen?.name)
                property bool monitorHasFullscreen: HyprlandData.workspaceById[thisMonitorData?.activeWorkspace?.id]?.hasfullscreen ?? false
                property bool monitorHasSpecialOpen: (thisMonitorData?.specialWorkspace?.name ?? "") !== ""
                exclusionMode: ExclusionMode.Ignore
                property int normalExclusiveZone: (barRoot.barConfig.autoHide.enable && (!mustShow || !barRoot.barConfig.autoHide.pushWindows))
                    ? 0
                    : Appearance.sizes.baseBarHeight
                        + (barRoot.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                        + (barRoot.barConfig.cornerStyle === 2 ? -6 : 0)

                exclusiveZone: (barContent.centerOnly && barRoot.barConfig.centerOnlyReserveFrame)
                    ? barRoot.barConfig.frameThickness
                    : (barRoot.barConfig.cornerStyle === 4 || barRoot.barConfig.cornerStyle === 5 || barRoot.barConfig.cornerStyle === 6) ? normalExclusiveZone + 4 : normalExclusiveZone
                WlrLayershell.namespace: "quickshell:bar"
                // Overlay layer only while special workspace sits on top of a fullscreen window on this monitor,
                // else Top layer so fullscreen apps cover the bar as normal (Hyprland buries Top layer under fullscreen+special).
                WlrLayershell.layer: (monitorHasFullscreen && monitorHasSpecialOpen) ? WlrLayer.Overlay : WlrLayer.Top
                implicitHeight: Appearance.sizes.barHeight + Appearance.rounding.screenRounding
                // When Overlay-layer, bar shares a layer with the screen-corner click zones (ScreenCorners.qml)
                // and same-layer overlap is resolved by stacking, not layer priority - bar was winning and
                // swallowing the tiny corner-open hit rects. Carve them out of the bar's own mask so clicks
                // reach the corners underneath. Only relevant on the edge the bar and corners share.
                property bool cutOutCornerOpenZones: (monitorHasFullscreen && monitorHasSpecialOpen) && (barRoot.barConfig.bottom === Config.options.sidebar.cornerOpen.bottom)
                property int cornerOpenCutWidth: cutOutCornerOpenZones ? Config.options.sidebar.cornerOpen.cornerRegionWidth : 0
                property int cornerOpenCutHeight: cutOutCornerOpenZones ? Config.options.sidebar.cornerOpen.cornerRegionHeight : 0
                mask: Region {
                    item: hoverMaskRegion
                    Region {
                        intersection: Intersection.Subtract
                        x: 0
                        y: barRoot.barConfig.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.cornerOpenCutWidth
                        height: barRoot.cornerOpenCutHeight
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: barRoot.width - barRoot.cornerOpenCutWidth
                        y: barRoot.barConfig.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.cornerOpenCutWidth
                        height: barRoot.cornerOpenCutHeight
                    }
                }
                color: "transparent"

                // Positioning
                anchors {
                    top: !barRoot.barConfig.bottom
                    bottom: barRoot.barConfig.bottom
                    left: true
                    right: true
                }

                margins {
                    top: barRoot.barConfig.cornerStyle === 3 ? 5 : 0
                    right: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                    bottom: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1 || barRoot.barConfig.cornerStyle === 3 ? 5 : 0
                }

                // Include in focus grab
                Component.onCompleted: {
                    GlobalFocusGrab.addPersistent(barRoot);
                }
                Component.onDestruction: {
                    GlobalFocusGrab.removePersistent(barRoot);
                }

                MouseArea  {
                    id: hoverRegion
                    Binding {
                        target: GlassLayers
                        property: "barZone"
                        value: Math.max(0, barRoot.exclusiveZone)
                        restoreMode: Binding.RestoreBinding
                    }
                    Binding {
                        target: GlassLayers
                        property: "barEdge"
                        value: barRoot.barConfig.bottom ? "bottom" : "top"
                        restoreMode: Binding.RestoreBinding
                    }

                    hoverEnabled: true
                    anchors {
                        fill: parent
                        rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * 1
                        bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * 1
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -barRoot.barConfig.autoHide.hoverRegionWidth
                            bottomMargin: -barRoot.barConfig.autoHide.hoverRegionWidth
                        }
                    }

                    BarContent {
                        id: barContent
                        barConfig: barRoot.barConfig
                        
                        implicitHeight: Appearance.sizes.barHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: (barRoot.barConfig.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
                            rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                        }
                        Behavior on anchors.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: (barRoot.barConfig.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            }
                        }
                    }
                    
                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: Appearance.rounding.screenRounding
                        active: !barContent.glassTabs && !barContent.glassHug && ((barRoot.barConfig.showBackground && barRoot.barConfig.cornerStyle === 0 && !barContent.centerOnly)
                             || (barRoot.barConfig.cornerStyle === 4 || barRoot.barConfig.cornerStyle === 6))

                        states: State {
                            name: "bottom"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            implicitHeight: Appearance.rounding.screenRounding

                            readonly property color decoratorColor: (barRoot.barConfig.cornerStyle === 4 || barRoot.barConfig.cornerStyle === 6 || barRoot.barConfig.showBackground)
                                ? (barRoot.barConfig.followFrameColor && barRoot.barConfig.frameColor
                                    ? Appearance.getColorFromName(barRoot.barConfig.frameColor)
                                    : Appearance.colors.colUiBackground)
                                : "transparent"

                            RoundCorner {
                                id: leftCorner
                                glass: true
                                visible: barRoot.barConfig.cornerStyle === 0 || barContent.effectiveLeftLayout.length > 0
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: parent.decoratorColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barConfig.bottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            RoundCorner {
                                id: rightCorner
                                glass: true
                                visible: barRoot.barConfig.cornerStyle === 0 || barContent.effectiveRightLayout.length > 0
                                anchors {
                                    right: parent.right
                                    top: !barRoot.barConfig.bottom ? parent.top : undefined
                                    bottom: barRoot.barConfig.bottom ? parent.bottom : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: parent.decoratorColor

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barConfig.bottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    CompositorGlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"

        onPressed: {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }
    }

    CompositorGlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"

        onPressed: {
            GlobalStates.barOpen = true;
        }
    }

    CompositorGlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"

        onPressed: {
            GlobalStates.barOpen = false;
        }
    }
}
