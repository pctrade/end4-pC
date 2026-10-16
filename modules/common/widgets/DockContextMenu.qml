import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    // Screen the dock lives on, used to pick the workspace group to offer.
    property var screen

    property string appId: ""
    property alias isOpen: menuLoader.active
    // Button geometry in dock-window coordinates, captured on open. Anchoring to
    // the button item itself would close the menu whenever the dock rebuilds its
    // app list (any window opening/closing destroys the unpinned buttons).
    property rect anchorRect

    // Looked up live so the menu follows windows opening/closing while open.
    // TaskbarApps keys entries by lowercased appId.
    readonly property var appToplevel: root.appId !== ""
        ? (TaskbarApps.apps.find(a => a.appId === root.appId.toLowerCase()) ?? null)
        : null
    readonly property var toplevels: appToplevel?.toplevels ?? []
    readonly property bool hasWindows: toplevels.length > 0

    property var desktopEntry: null
    readonly property bool hasDesktopActions: (desktopEntry?.actions.length ?? 0) > 0

    Connections {
        target: DesktopEntries
        enabled: root.isOpen
        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(root.appId);
        }
    }

    function open(button, appId) {
        // The menu relies on HyprlandFocusGrab to close and on Hyprland window
        // addresses to move windows; elsewhere keep right-click as toggle pin.
        if (WM.compositor !== "hyprland") {
            TaskbarApps.togglePin(appId);
            return;
        }
        menuLoader.active = false;
        const topLeft = root.QsWindow.mapFromItem(button, 0, 0);
        root.anchorRect = Qt.rect(topLeft.x, topLeft.y, button.width, button.height);
        root.appId = appId;
        root.desktopEntry = DesktopEntries.heuristicLookup(appId);
        menuLoader.active = true;
    }

    function close() {
        menuLoader.active = false;
        // Drop the live lookups so closed menus don't track TaskbarApps.
        root.appId = "";
        root.desktopEntry = null;
    }

    function moveToWorkspace(ws) {
        for (const toplevel of root.toplevels) {
            const address = toplevel.HyprlandToplevel?.address;
            if (address)
                WM.moveWindowToWorkspace(`0x${address}`, ws);
        }
    }

    Loader {
        id: menuLoader
        active: false
        sourceComponent: PopupWindow {
            id: contextPopup
            visible: true

            // Open away from the screen edge the dock is attached to.
            readonly property int side: DockStyle.position === "left" ? Edges.Right
                : DockStyle.position === "right" ? Edges.Left
                : Edges.Top

            readonly property int workspacesShown: Math.max(1, Config.options?.bar.workspaces.shown ?? 10)
            readonly property int workspaceGroup: {
                const activeId = WM.activeWorkspaceForMonitor(root.screen?.name)?.id ?? 1;
                return Math.floor((Math.max(activeId, 1) - 1) / workspacesShown);
            }

            anchor {
                window: root.QsWindow.window
                rect: root.anchorRect
                gravity: contextPopup.side
                edges: contextPopup.side
                adjustment: DockStyle.vertical ? PopupAdjustment.SlideY : PopupAdjustment.SlideX
            }

            HyprlandFocusGrab {
                active: true
                windows: [contextPopup]
                onCleared: root.close()
            }

            color: "transparent"
            // Clicks on the transparent shadow margin should count as outside.
            mask: Region {
                item: menuInputArea
            }
            implicitWidth: menuBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: menuBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

            Item {
                id: menuInputArea
                anchors.fill: menuBackground
            }

            StyledRectangularShadow {
                target: menuBackground
            }

            Rectangle {
                id: menuBackground
                property real padding: 4

                anchors.centerIn: parent
                color: Config.options.appearance.uiBackground === "oled" ? "#000000" : Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                implicitWidth: menuColumn.implicitWidth + padding * 2
                implicitHeight: menuColumn.implicitHeight + padding * 2
                focus: true
                Keys.onEscapePressed: root.close()

                opacity: 0
                transform: Scale {
                    id: menuScale
                    origin.x: contextPopup.side === Edges.Right ? 0 : contextPopup.side === Edges.Left ? menuBackground.width : menuBackground.width / 2
                    origin.y: contextPopup.side === Edges.Top ? menuBackground.height : menuBackground.height / 2
                    xScale: DockStyle.vertical ? 0.01 : 0.8
                    yScale: DockStyle.vertical ? 0.8 : 0.01
                }

                Component.onCompleted: openAnim.start()

                ParallelAnimation {
                    id: openAnim
                    NumberAnimation {
                        target: menuScale
                        property: DockStyle.vertical ? "xScale" : "yScale"
                        to: 1
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                    }
                    NumberAnimation {
                        target: menuScale
                        property: DockStyle.vertical ? "yScale" : "xScale"
                        to: 1
                        duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                    NumberAnimation {
                        target: menuBackground
                        property: "opacity"
                        to: 1
                        duration: Appearance.animationCurves.expressiveEffectsDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                    }
                }

                ColumnLayout {
                    id: menuColumn
                    anchors {
                        fill: parent
                        margins: parent.padding
                    }
                    spacing: 0

                    // Desktop entry actions
                    Repeater {
                        model: root.desktopEntry?.actions ?? []
                        delegate: ContextMenuItem {
                            required property var modelData
                            iconSource: modelData.icon ? SystemAppearance.iconPath(modelData.icon, true) : ""
                            iconName: "chevron_right"
                            label: modelData.name
                            onClicked: {
                                modelData.execute();
                                root.close();
                            }
                        }
                    }

                    ContextMenuSeparator {
                        visible: root.hasDesktopActions
                    }

                    ContextMenuItem {
                        iconName: "open_in_new"
                        label: Translation.tr("Open new instance")
                        enabled: root.desktopEntry !== null
                        onClicked: {
                            root.desktopEntry?.execute();
                            root.close();
                        }
                    }

                    ContextMenuSeparator {}

                    ContextMenuItem {
                        visible: root.hasWindows
                        iconName: "move_item"
                        label: Translation.tr("Move to workspace")
                        enabled: false
                        pointingHandCursor: false
                    }

                    RowLayout {
                        visible: root.hasWindows
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.bottomMargin: 4
                        spacing: 2

                        Repeater {
                            model: contextPopup.workspacesShown
                            delegate: RippleButton {
                                id: wsButton
                                required property int index
                                readonly property int workspaceId: contextPopup.workspaceGroup * contextPopup.workspacesShown + index + 1
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.small
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: String(wsButton.workspaceId)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Appearance.m3colors.m3onSurface
                                }
                                onClicked: {
                                    root.moveToWorkspace(wsButton.workspaceId);
                                    root.close();
                                }
                            }
                        }
                    }

                    ContextMenuItem {
                        readonly property bool pinned: TaskbarApps.isPinned(root.appId)
                        iconName: pinned ? "keep_off" : "keep"
                        label: pinned ? Translation.tr("Unpin") : Translation.tr("Pin to dock")
                        enabled: root.appId !== ""
                        onClicked: {
                            TaskbarApps.togglePin(root.appId);
                            root.close();
                        }
                    }

                    ContextMenuSeparator {
                        visible: root.hasWindows
                    }

                    ContextMenuItem {
                        visible: root.hasWindows
                        iconName: "close"
                        label: root.toplevels.length > 1
                            ? Translation.tr("Close all windows") : Translation.tr("Close window")
                        onClicked: {
                            for (const toplevel of root.toplevels) {
                                toplevel.close();
                            }
                            root.close();
                        }
                    }
                }
            }
        }
    }

    component ContextMenuItem: RippleButton {
        id: menuItemRoot
        property string iconName
        // Themed icon; falls back to iconName (a Material Symbol) when empty.
        property string iconSource
        property string label
        readonly property color contentColor: enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
        Layout.fillWidth: true
        implicitHeight: 36
        implicitWidth: Math.max(itemRow.implicitWidth + itemRow.anchors.leftMargin + itemRow.anchors.rightMargin, 180)
        buttonRadius: Appearance.rounding.small

        contentItem: RowLayout {
            id: itemRow
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 14
            }
            spacing: 8

            IconImage {
                visible: menuItemRoot.iconSource !== ""
                source: menuItemRoot.iconSource
                implicitSize: Appearance.font.pixelSize.normal
                Layout.alignment: Qt.AlignVCenter
            }

            MaterialSymbol {
                text: menuItemRoot.iconName
                iconSize: Appearance.font.pixelSize.normal
                color: menuItemRoot.contentColor
                visible: menuItemRoot.iconSource === "" && menuItemRoot.iconName !== ""
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                Layout.fillWidth: true
                text: menuItemRoot.label
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: Appearance.font.pixelSize.small
                color: menuItemRoot.contentColor
                elide: Text.ElideRight
            }
        }
    }

    component ContextMenuSeparator: Item {
        Layout.fillWidth: true
        implicitHeight: 9

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 10
            }
            implicitHeight: 1
            color: ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.7)
        }
    }
}
