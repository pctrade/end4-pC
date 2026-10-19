import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            return screens.filter(screen => {
                const config = Config.barForScreen(screen.name);
                const listed = !list || list.length === 0 || list.includes(screen.name);
                return listed && config.enabled !== false && config.vertical;
            });
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow {
                id: barRoot
                screen: barLoader.modelData
                readonly property var barConfig: Config.barForScreen(screen?.name)

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                
                Timer {
                    id: showBarTimer
                    interval: (barRoot.barConfig.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: { barRoot.superShow = true }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!barRoot.barConfig.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else { showBarTimer.stop(); barRoot.superShow = false; }
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || (barRoot.barConfig.autoHide.enable && GlobalStates.isFrameHovered(barRoot.screen?.name, barRoot.barConfig.bottom ? "right" : "left"))
                exclusionMode: ExclusionMode.Ignore
                property int normalExclusiveZone: (barRoot.barConfig.autoHide.enable && (!mustShow || !barRoot.barConfig.autoHide.pushWindows))
                    ? 0
                    : Appearance.sizes.baseVerticalBarWidth
                        + (barRoot.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                        + (barRoot.barConfig.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)

                exclusiveZone: (barContent.centerOnly && barRoot.barConfig.centerOnlyReserveFrame)
                    ? barRoot.barConfig.frameThickness
                    : normalExclusiveZone
                WlrLayershell.namespace: "quickshell:verticalBar"
                implicitWidth: Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding
                mask: Region { item: hoverMaskRegion }
                color: "transparent"

                anchors {
                    left: !barRoot.barConfig.bottom
                    right: barRoot.barConfig.bottom
                    top: true
                    bottom: true
                }

                Component.onCompleted: { GlobalFocusGrab.addPersistent(barRoot); }
                Component.onDestruction: { GlobalFocusGrab.removePersistent(barRoot); }

                MouseArea {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors.fill: parent

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            leftMargin: -barRoot.barConfig.autoHide.hoverRegionWidth
                            rightMargin: -barRoot.barConfig.autoHide.hoverRegionWidth
                        }
                    }

                    RoundCorner {
                        id: topPillCorner
                        visible: barContent.centerOnly && barRoot.barConfig.showBackground && barRoot.barConfig.cornerStyle === 0
                        y: barContent.centerPillY - implicitSize
                        implicitSize: Appearance.rounding.screenRounding
                        color: barRoot.barConfig.followFrameColor
                            ? Appearance.getColorFromName(barRoot.barConfig.frameColor)
                            : Appearance.colors.colUiBackground
                        corner: RoundCorner.CornerEnum.BottomLeft

                        states: State {
                            name: "right"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: topPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: topPillCorner
                                corner: RoundCorner.CornerEnum.BottomRight
                            }
                        }
                        AnchorChanges {
                            target: topPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    RoundCorner {
                        id: bottomPillCorner
                        visible: barContent.centerOnly && barRoot.barConfig.showBackground && barRoot.barConfig.cornerStyle === 0
                        y: barContent.centerPillY + barContent.centerPillHeight
                        implicitSize: Appearance.rounding.screenRounding
                        color: barRoot.barConfig.followFrameColor
                            ? Appearance.getColorFromName(barRoot.barConfig.frameColor)
                            : Appearance.colors.colUiBackground
                        corner: RoundCorner.CornerEnum.TopLeft

                        states: State {
                            name: "right"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: bottomPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: bottomPillCorner
                                corner: RoundCorner.CornerEnum.TopRight
                            }
                        }
                        AnchorChanges {
                            target: bottomPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    VerticalBarContent {
                        id: barContent
                        barConfig: barRoot.barConfig

                        implicitWidth: Appearance.sizes.verticalBarWidth
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: undefined
                            leftMargin: (barRoot.barConfig.autoHide.enable && !mustShow)
                                ? -Appearance.sizes.verticalBarWidth 
                                : (barRoot.barConfig.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                        }
                        Behavior on anchors.leftMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "right"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: parent.right
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.rightMargin: (barRoot.barConfig.autoHide.enable && !mustShow)
                                    ? -Appearance.sizes.barHeight
                                    : (barRoot.barConfig.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                            }
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: barContent.right
                            right: undefined
                        }
                        width: Appearance.rounding.screenRounding
                        active: (barRoot.barConfig.showBackground && barRoot.barConfig.cornerStyle === 0 && !barContent.centerOnly)
                             || (barRoot.barConfig.cornerStyle === 4 || barRoot.barConfig.cornerStyle === 6)

                        states: State {
                            name: "right"
                            when: barRoot.barConfig.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: barContent.left
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
                                id: topCorner
                                visible: barRoot.barConfig.cornerStyle === 0 || barContent.effectiveLeftLayout.length > 0
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                implicitSize: Appearance.rounding.screenRounding
                                width: implicitSize
                                height: implicitSize
                                color: parent.decoratorColor
                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barConfig.bottom
                                    PropertyChanges { topCorner.corner: RoundCorner.CornerEnum.TopRight }
                                }
                            }
                            RoundCorner {
                                id: bottomCorner
                                visible: barRoot.barConfig.cornerStyle === 0 || barContent.effectiveRightLayout.length > 0
                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                width: implicitSize
                                height: implicitSize
                                color: parent.decoratorColor
                                corner: RoundCorner.CornerEnum.BottomLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barConfig.bottom
                                    PropertyChanges { bottomCorner.corner: RoundCorner.CornerEnum.BottomRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
