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

Scope {
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false
    property bool barState: false
    property bool ready: false

    Component.onCompleted: {
        DockStyle.position = Config.options.dock.position
        barSettleTimer.start()
    }

    Timer {
        id: barSettleTimer
        interval: 300
        onTriggered: {
            root.barState = GlobalStates.barOpen
            DockStyle.position = Config.options.dock.position
            root.ready = true
        }
    }

    Connections {
        target: Config.options.dock
        function onPositionChanged() {
            root.ready = false
            barSettleTimer.restart()
        }
    }

    Connections {
        target: GlobalStates
        function onBarOpenChanged() { barSettleTimer.restart() }
    }

    Variants {
        model: !root.ready ? [] : Quickshell.screens.map(screen => ({
            screen: screen,
            position: DockStyle.position,
            layout: `${DockStyle.position}|${Config.options.dock.style}|${Config.options.dock.height}|${root.barState}`
        }))

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData.screen
            visible: !GlobalStates.screenLocked

            readonly property bool macos: DockStyle.magnifying
            readonly property bool hug: Config.options.dock.style === "hug"
            readonly property string position: modelData.position
            readonly property bool glassHug: hug && Config.options.dock.showBackground && Config.options.background.widgets.glass.enable
            readonly property real hugFlare: glassHug ? Appearance.rounding.screenRounding : 0
            readonly property bool vertical: position !== "bottom"
            readonly property real gap: Appearance.sizes.hyprlandGapsOut
            readonly property real shadowMargin: Appearance.sizes.elevationMargin
            readonly property color backgroundColor: (hug && Config.options.dock.followFrameColor && Config.options.bar.showFrame)
                ? Appearance.getColorFromName(Config.options.bar.frameColor)
                : Appearance.getColorFromName(Config.options.dock.backgroundColor)
            readonly property real borderWidth: (Config.options.dock.showBackground && Config.options.dock.showBorder && !hug) ? Config.options.dock.borderWidth : 0

            property var monitor: WM.monitorFor(modelData.screen)
            property bool fullscreenOnThisMonitor: WM.fullscreenOnMonitor(monitor?.name)

            property bool reveal: {
                if (dockContextMenu.isOpen)
                    return true
                if (fullscreenOnThisMonitor)
                    return Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse
                return root.pinned
                    || (Config.options?.dock.hoverToReveal && (dockMouseArea.containsMouse || GlobalStates.isFrameHovered(dockRoot.screen?.name, dockRoot.position)))
                    || activeApps.requestDockShow
                    || dragSlots.requestDockShow
                    || (!ToplevelManager.activeToplevel?.activated)
            }

            exclusiveZone: (root.pinned && !fullscreenOnThisMonitor)
                ? DockStyle.zone
                : 0

            anchors {
                top: dockRoot.vertical
                bottom: true
                left: dockRoot.position !== "right"
                right: dockRoot.position !== "left"
            }
            margins {
                bottom: dockRoot.hug && dockRoot.position === "bottom" ? -dockRoot.gap : 0
                left: dockRoot.hug && dockRoot.position === "left" ? -dockRoot.gap : 0
                right: dockRoot.hug && dockRoot.position === "right" ? -dockRoot.gap : 0
            }
            implicitWidth: dockRoot.vertical ? DockStyle.thickness : dockBackground.implicitWidth
            implicitHeight: dockRoot.vertical ? dockBackground.implicitHeight : DockStyle.thickness + DockStyle.headroom
            WlrLayershell.namespace: "quickshell:dock"

            Binding {
                target: GlassLayers
                property: "dockZone"
                value: Math.max(0, dockRoot.exclusiveZone)
                restoreMode: Binding.RestoreBinding
            }
            Binding {
                target: GlassLayers
                property: "dockEdge"
                value: dockRoot.position
                restoreMode: Binding.RestoreBinding
            }
            color: "transparent"

            mask: Region {
                item: dockMouseArea
                Region { item: riseArea }
            }

            readonly property bool magnifyHover: DockStyle.magnifying && (dockMouseArea.containsMouse || riseArea.containsMouse)
            property real magnifyAmp: dockRoot.magnifyHover ? 1 : 0

            Behavior on magnifyAmp {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            onMagnifyAmpChanged: {
                if (DockMagnify.window === dockRoot) DockMagnify.amplitude = dockRoot.magnifyAmp;
            }

            function updatePointer(item, mouseX) {
                if (!DockStyle.magnifying) return;
                DockMagnify.window = dockRoot;
                DockMagnify.amplitude = dockRoot.magnifyAmp;
                DockMagnify.pointer = item.mapToItem(null, mouseX, 0).x;
            }

            MouseArea {
                id: riseArea
                enabled: DockStyle.magnifying
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                x: dockMouseArea.x
                width: dockMouseArea.width
                height: DockStyle.headroom * dockRoot.magnifyAmp
                anchors.bottom: dockMouseArea.top
                onPositionChanged: mouse => dockRoot.updatePointer(riseArea, mouse.x)
                onEntered: dockRoot.updatePointer(riseArea, mouseX)
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true
                onPositionChanged: mouse => dockRoot.updatePointer(dockMouseArea, mouse.x)
                onEntered: dockRoot.updatePointer(dockMouseArea, mouseX)
                width: dockRoot.vertical ? parent.width : implicitWidth
                height: dockRoot.vertical ? implicitHeight : (dockRoot.macos ? DockStyle.thickness : parent.height)
                implicitWidth: dockHoverRegion.implicitWidth + dockRoot.shadowMargin * 2
                implicitHeight: dockHoverRegion.implicitHeight + dockRoot.shadowMargin * 2

                readonly property real hiddenOffset: Config.options?.dock.hoverToReveal
                    ? (DockStyle.thickness - Config.options.dock.hoverRegionHeight - (dockRoot.hug ? dockRoot.gap : 0))
                    : (DockStyle.thickness + 1)
                property real offset: dockRoot.reveal ? 0 : hiddenOffset

                Behavior on offset {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                anchors {
                    top: dockRoot.vertical || dockRoot.macos ? undefined : parent.top
                    topMargin: dockMouseArea.offset
                    bottom: dockRoot.macos ? parent.bottom : undefined
                    bottomMargin: dockRoot.macos ? -dockMouseArea.offset : 0
                    horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                    verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                    left: dockRoot.position === "left" ? parent.left : undefined
                    leftMargin: -dockMouseArea.offset
                    right: dockRoot.position === "right" ? parent.right : undefined
                    rightMargin: -dockMouseArea.offset
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth
                    implicitHeight: dockBackground.implicitHeight

                    Item {
                        id: dockBackground
                        anchors {
                            top: dockRoot.vertical ? undefined : parent.top
                            bottom: dockRoot.vertical ? undefined : parent.bottom
                            left: dockRoot.vertical ? parent.left : undefined
                            right: dockRoot.vertical ? parent.right : undefined
                            horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                            verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                        }
                        implicitWidth: dockRow.implicitWidth + DockStyle.backgroundPadding * 2
                        implicitHeight: dockRow.implicitHeight + DockStyle.backgroundPadding * 2

                        StyledRectangularShadow {
                            target: dockVisualBackground
                            visible: false
                        }

                        Rectangle {
                            id: dockVisualBackground
                            WindowGlass {
                                anchors.fill: parent
                                anchors.leftMargin: dockRoot.vertical ? 0 : -dockRoot.hugFlare
                                anchors.rightMargin: dockRoot.vertical ? 0 : -dockRoot.hugFlare
                                anchors.topMargin: dockRoot.vertical ? -dockRoot.hugFlare : 0
                                anchors.bottomMargin: dockRoot.vertical ? -dockRoot.hugFlare : 0
                                flareLeft: dockRoot.hugFlare
                                flareRight: dockRoot.hugFlare
                                edge: dockRoot.position === "left" ? 2 : dockRoot.position === "right" ? 3 : 1
                                glassEnabled: (parent?.color.a ?? 0) > 0
                                cardRadius: parent?.radius ?? 0
                                tint: parent?.color ?? 'transparent'
                            }
                            anchors.fill: parent
                            anchors.topMargin: dockRoot.position === "bottom" ? dockRoot.shadowMargin : 0
                            anchors.bottomMargin: dockRoot.position === "bottom" ? dockRoot.gap : 0
                            anchors.leftMargin: dockRoot.macos ? -DockMagnify.totalExtra / 2 : (dockRoot.position === "left" ? dockRoot.gap : dockRoot.position === "right" ? dockRoot.shadowMargin : 0)
                            anchors.rightMargin: dockRoot.macos ? -DockMagnify.totalExtra / 2 : (dockRoot.position === "right" ? dockRoot.gap : dockRoot.position === "left" ? dockRoot.shadowMargin : 0)
                            color: Config.options.dock.showBackground ? dockRoot.backgroundColor : "transparent"
                            border.width: dockRoot.borderWidth
                            border.color: Appearance.getColorFromName(Config.options.dock.borderColor)
                            radius: Config.options.dock.radius
                            topLeftRadius: dockRoot.hug && dockRoot.position === "left" ? 0 : radius
                            bottomLeftRadius: dockRoot.hug && (dockRoot.position === "left" || dockRoot.position === "bottom") ? 0 : radius
                            topRightRadius: dockRoot.hug && dockRoot.position === "right" ? 0 : radius
                            bottomRightRadius: dockRoot.hug && (dockRoot.position === "right" || dockRoot.position === "bottom") ? 0 : radius
                        }

                        RoundCorner {
                            glass: true
                            visible: dockRoot.hug && Config.options.dock.showBackground && !dockRoot.glassHug
                            anchors.right: dockRoot.vertical ? (dockRoot.position === "right" ? dockVisualBackground.right : undefined) : dockVisualBackground.left
                            anchors.bottom: dockRoot.vertical ? dockVisualBackground.top : dockVisualBackground.bottom
                            anchors.left: dockRoot.position === "left" ? dockVisualBackground.left : undefined
                            implicitSize: Appearance.rounding.screenRounding
                            color: dockRoot.backgroundColor
                            corner: dockRoot.position === "left" ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
                        }

                        RoundCorner {
                            glass: true
                            visible: dockRoot.hug && Config.options.dock.showBackground && !dockRoot.glassHug
                            anchors.left: dockRoot.vertical ? (dockRoot.position === "left" ? dockVisualBackground.left : undefined) : dockVisualBackground.right
                            anchors.bottom: dockRoot.vertical ? undefined : dockVisualBackground.bottom
                            anchors.top: dockRoot.vertical ? dockVisualBackground.bottom : undefined
                            anchors.right: dockRoot.position === "right" ? dockVisualBackground.right : undefined
                            implicitSize: Appearance.rounding.screenRounding
                            color: dockRoot.backgroundColor
                            corner: dockRoot.position === "left" ? RoundCorner.CornerEnum.TopLeft
                                : dockRoot.position === "right" ? RoundCorner.CornerEnum.TopRight
                                : RoundCorner.CornerEnum.BottomLeft
                        }

                        DockContextMenu {
                            id: dockContextMenu
                            screen: dockRoot.screen
                        }

                        GridLayout {
                            id: dockRow
                            anchors.top: dockRoot.vertical ? undefined : parent.top
                            anchors.bottom: dockRoot.vertical ? undefined : parent.bottom
                            anchors.left: dockRoot.vertical ? parent.left : undefined
                            anchors.right: dockRoot.vertical ? parent.right : undefined
                            anchors.horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                            anchors.verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                            columns: dockRoot.vertical ? 1 : -1
                            rowSpacing: DockStyle.spacing
                            columnSpacing: DockStyle.spacing
                            property bool hasPinnedApps: (Config.options?.dock.pinnedApps?.length ?? 0) > 0

                            DockPinButton {
                                pinned: root.pinned
                                onToggled: root.pinned = !root.pinned
                            }

                            DockSeparator {
                                visible: Config.options.dock.showPinButton
                                    && (dockRow.hasPinnedApps
                                        || !(Config.options.dock.showMedia && activeApps.media.hasTrack))
                            }

                            DragApps {
                                id: dragSlots
                                visible: dockRow.hasPinnedApps
                                Layout.topMargin: DockStyle.mTop(DockStyle.pinnedInnerMargin, 0)
                                Layout.leftMargin: DockStyle.mLeft(DockStyle.pinnedInnerMargin, 0)
                                contextMenu: dockContextMenu
                                pinnedApps: Config.options?.dock.pinnedApps ?? []
                            }

                            DockSeparator {
                                visible: dockRow.hasPinnedApps
                                    && (activeApps.activeUnpinned.length > 0
                                        || (Config.options.dock.showMedia && MprisController.activePlayer !== null))
                            }

                            DockActiveApps {
                                id: activeApps
                                contextMenu: dockContextMenu
                                appListRoot: dragSlots
                            }

                            DockSeparator {
                                visible: Config.options.dock.showAppsButton
                            }

                            DockAppsButton {
                                onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                            }
                        }
                    }
                }
            }
        }
    }
}
