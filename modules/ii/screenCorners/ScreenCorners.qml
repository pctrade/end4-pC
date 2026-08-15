import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: screenCorners
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    function isCornerOpen(corner) {
        switch (corner) {
            case RoundCorner.CornerEnum.TopLeft: return GlobalStates.sidebarLeftOpen;
            case RoundCorner.CornerEnum.TopRight: return GlobalStates.sidebarRightOpen;
            case RoundCorner.CornerEnum.BottomLeft: {
                let act = Config.options.sidebar.cornerOpen.bottomLeftAction;
                return act && act !== "none" ? !!GlobalStates[act] : false;
            }
            case RoundCorner.CornerEnum.BottomRight: {
                let act = Config.options.sidebar.cornerOpen.bottomRightAction;
                return act && act !== "none" ? !!GlobalStates[act] : false;
            }
            default: return false;
        }
    }

    function openCorner(corner) {
        switch (corner) {
            case RoundCorner.CornerEnum.TopLeft:
                if (!GlobalStates.sidebarLeftOpen) GlobalStates.sidebarLeftOpen = true;
                break;
            case RoundCorner.CornerEnum.TopRight:
                if (!GlobalStates.sidebarRightOpen) GlobalStates.sidebarRightOpen = true;
                break;
            case RoundCorner.CornerEnum.BottomLeft:
                if (Config.options.sidebar.cornerOpen.bottomLeftAction && Config.options.sidebar.cornerOpen.bottomLeftAction !== "none")
                    GlobalStates[Config.options.sidebar.cornerOpen.bottomLeftAction] = true;
                break;
            case RoundCorner.CornerEnum.BottomRight:
                if (Config.options.sidebar.cornerOpen.bottomRightAction && Config.options.sidebar.cornerOpen.bottomRightAction !== "none")
                    GlobalStates[Config.options.sidebar.cornerOpen.bottomRightAction] = true;
                break;
        }
    }

    function toggleCorner(corner) {
        switch (corner) {
            case RoundCorner.CornerEnum.TopLeft:
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
                break;
            case RoundCorner.CornerEnum.TopRight:
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                break;
            case RoundCorner.CornerEnum.BottomLeft:
                GlobalStates.toggleState(Config.options.sidebar.cornerOpen.bottomLeftAction);
                break;
            case RoundCorner.CornerEnum.BottomRight:
                GlobalStates.toggleState(Config.options.sidebar.cornerOpen.bottomRightAction);
                break;
        }
    }

    property var actionForCorner: ({
        [RoundCorner.CornerEnum.TopLeft]: () => screenCorners.toggleCorner(RoundCorner.CornerEnum.TopLeft),
        [RoundCorner.CornerEnum.BottomLeft]: () => screenCorners.toggleCorner(RoundCorner.CornerEnum.BottomLeft),
        [RoundCorner.CornerEnum.TopRight]: () => screenCorners.toggleCorner(RoundCorner.CornerEnum.TopRight),
        [RoundCorner.CornerEnum.BottomRight]: () => screenCorners.toggleCorner(RoundCorner.CornerEnum.BottomRight)
    })

    component CornerPanelWindow: PanelWindow {
        id: cornerPanelWindow
        property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
        property bool fullscreen
        readonly property bool showFakeRounding: (Config.options.appearance.fakeScreenRounding === 1 || (Config.options.appearance.fakeScreenRounding === 2 && !fullscreen))
        readonly property bool showCornerOpen: Config.options.sidebar.cornerOpen.enable && !fullscreen

        visible: showFakeRounding || showCornerOpen
        property var corner
        readonly property bool isCurrentCornerOpen: screenCorners.isCornerOpen(cornerPanelWindow.corner)

        onIsCurrentCornerOpenChanged: {
            if (!isCurrentCornerOpen && sidebarCornerOpenInteractionLoader.item && typeof sidebarCornerOpenInteractionLoader.item.triggerCooldown === "function") {
                sidebarCornerOpenInteractionLoader.item.triggerCooldown();
            }
        }

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: sidebarCornerOpenInteractionLoader.active
                ? sidebarCornerOpenInteractionLoader 
                : (cornerPanelWindow.showFakeRounding ? cornerWidget : null)
        }
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        anchors {
            top: cornerWidget.isTopLeft || cornerWidget.isTopRight
            left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
            bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
            right: cornerWidget.isTopRight || cornerWidget.isBottomRight
        }
        margins {
            right: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.right) * -1
            bottom: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.bottom) * -1
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            drawCorner: cornerPanelWindow.showFakeRounding
            rightVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.right) * 1
            bottomVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.bottom) * 1

            implicitSize: Appearance.rounding.screenRounding
            implicitHeight: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitHeight)
            implicitWidth: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitWidth)

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: {
                    if (!Config.options.sidebar.cornerOpen.enable) return false;
                    if (cornerPanelWindow.fullscreen) return false;
                    return true;
                }
                anchors {
                    top: (cornerWidget.isTopLeft || cornerWidget.isTopRight) ? parent.top : undefined
                    bottom: (cornerWidget.isBottomLeft || cornerWidget.isBottomRight) ? parent.bottom : undefined
                    left: (cornerWidget.isLeft) ? parent.left : undefined
                    right: (cornerWidget.isTopRight || cornerWidget.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    implicitHeight: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    hoverEnabled: true
                    property bool armed: true
                    property bool inCooldown: false

                    Timer {
                        id: cooldownTimer
                        interval: 400
                        onTriggered: mouseArea.inCooldown = false
                    }

                    function triggerCooldown() {
                        mouseArea.inCooldown = true;
                        mouseArea.armed = false;
                        cooldownTimer.restart();
                    }

                    function checkHotspot() {
                        if (!Config.options.sidebar.cornerOpen.clicklessCornerEnd) {
                            return Config.options.sidebar.cornerOpen.clickless;
                        }
                        const verticalOffset = Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset;
                        const correctX = (cornerWidget.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerWidget.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerWidget.isTop && mouseArea.mouseY >= verticalOffset) || (cornerWidget.isBottom && mouseArea.mouseY <= mouseArea.height - verticalOffset);
                        return correctX && correctY;
                    }

                    onExited: {
                        if (!mouseArea.inCooldown) {
                            mouseArea.armed = true;
                        }
                    }

                    onPositionChanged: {
                        if (mouseArea.inCooldown) return;
                        if (screenCorners.isCornerOpen(cornerPanelWindow.corner)) {
                            mouseArea.armed = false;
                            return;
                        }
                        if (checkHotspot()) {
                            if (mouseArea.armed) {
                                mouseArea.armed = false;
                                screenCorners.openCorner(cornerPanelWindow.corner);
                            }
                        } else {
                            mouseArea.armed = true;
                        }
                    }

                    onEntered: {
                        if (mouseArea.inCooldown) return;
                        if (screenCorners.isCornerOpen(cornerPanelWindow.corner)) {
                            mouseArea.armed = false;
                            return;
                        }
                        if (Config.options.sidebar.cornerOpen.clickless && !Config.options.sidebar.cornerOpen.clicklessCornerEnd) {
                            if (mouseArea.armed) {
                                mouseArea.armed = false;
                                screenCorners.openCorner(cornerPanelWindow.corner);
                            }
                        }
                    }

                    onPressed: {
                        if (screenCorners.isCornerOpen(cornerPanelWindow.corner)) {
                            mouseArea.triggerCooldown();
                            screenCorners.toggleCorner(cornerPanelWindow.corner);
                        } else {
                            if (checkHotspot() || !Config.options.sidebar.cornerOpen.clickless) {
                                mouseArea.triggerCooldown();
                                screenCorners.openCorner(cornerPanelWindow.corner);
                            }
                        }
                    }
                    onScrollDown: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            Brightness.decreaseBrightness()
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume -= step;
                        }
                    }
                    onScrollUp: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            Brightness.increaseBrightness()
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
                        }
                    }
                    onMovedAway: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            GlobalStates.osdBrightnessOpen = false;
                        else
                            GlobalStates.osdVolumeOpen = false;
                    }

                    Loader {
                        active: Config.options.sidebar.cornerOpen.visualize
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData
            property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

            // Hide when fullscreen
            property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
            property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
            property bool fullscreen: activeWorkspaceWithFullscreen != undefined
            // A special workspace open on top of the fullscreen window should bring corners back,
            // same reasoning as the bar's layer fix: fullscreen only buries them when nothing else is above it.
            property var thisMonitorData: HyprlandData.monitors.find(m => m.name === monitor.name)
            property bool specialOpen: (thisMonitorData?.specialWorkspace?.name ?? "") !== ""

            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.TopLeft
                fullscreen: monitorScope.fullscreen && !monitorScope.specialOpen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.TopRight
                fullscreen: monitorScope.fullscreen && !monitorScope.specialOpen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.BottomLeft
                fullscreen: monitorScope.fullscreen && !monitorScope.specialOpen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.BottomRight
                fullscreen: monitorScope.fullscreen && !monitorScope.specialOpen
            }
        }
    }
}