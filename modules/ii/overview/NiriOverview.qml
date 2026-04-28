pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    property var panelWindow

    property var monitorData: HyprlandData.monitors.find(m => m.name === Hyprland.focusedMonitor?.name)

    property int activeWorkspaceId: {
        var id = monitorData?.activeWorkspace?.id ?? 1
        return Math.max(1, Math.min(100, id))
    }

    readonly property int maxWorkspaces: Config.options.bar.workspaces.shown ?? 10
    readonly property real wsHeight: (screen?.height ?? 1080) * 0.18
    readonly property real wsPadding: 10
    readonly property real scale: Config.options.overview.scale
    readonly property real screenCenterX: (screen?.width ?? 1920) / 2
    readonly property real cellWidth: (screen?.width ?? 1920) * 0.15

    property var windows: HyprlandData.windowList

    property int dragFromWs: -1
    property int dragFromPos: -1
    property int dragToWs: -1
    property bool isDragging: false
    property real ghostX: 0
    property real ghostY: 0
    property string dragWinIndex: ""

    implicitWidth: screen?.width ?? 1920
    implicitHeight: screen?.height ?? 1080

    onActiveWorkspaceIdChanged: scrollTimer.restart()

    Timer {
        id: scrollTimer
        interval: 50
        repeat: false
        onTriggered: {
            var targetY = (root.activeWorkspaceId - 1) * (root.wsHeight + root.wsPadding)
            targetY = Math.max(0, targetY - flickable.height / 2 + root.wsHeight / 2)
            var finalY = Math.min(targetY, Math.max(0, flickable.contentHeight - flickable.height))
            scrollAnim.to = finalY
            scrollAnim.restart()
        }
    }
    Timer {
        id: autoScrollTimer
        interval: 16
        repeat: true
        running: root.isDragging

        onTriggered: {
            var edge = root.height * 0.2
            var speed = 18

            if (root.ghostY < edge) {
                var step = speed * (1 - root.ghostY / edge)
                flickable.contentY = Math.max(0, flickable.contentY - step)
            } else if (root.ghostY > root.height - edge) {
                var step = speed * ((root.ghostY - (root.height - edge)) / edge)
                flickable.contentY = Math.min(
                    flickable.contentHeight - flickable.height,
                    flickable.contentY + step
                )
            }
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) scrollTimer.restart()
        }
    }

    function getWindowsSortedByX(wsId) {
        if (!windows) return []
        var wins = windows.filter(w => w.workspace?.id === wsId)
        wins.sort((a, b) => a.at[0] - b.at[0])
        return wins
    }

    function getMonitorDataForWindow(win) {
        if (!win) return null
        return HyprlandData.monitors.find(m => m.id === win.monitor) ?? null
    }

    function getToplevelForWindow(win) {
        if (!win) return null
        return ToplevelManager.toplevels.values.find(
            t => `0x${t.HyprlandToplevel?.address}` === win.address
        ) ?? null
    }

    function findTargetPos(ghostLocalX, items, activeIdx) {
        var minDist = Infinity
        var bestPos = items.length
        for (var i = 0; i < items.length; i++) {
            var offset = i - activeIdx
            var cellCenterX = root.screenCenterX + offset * (root.cellWidth + root.wsPadding)
            var dx = Math.abs(ghostLocalX - cellCenterX)
            if (dx < minDist) {
                minDist = dx
                bestPos = i
            }
        }
        return bestPos
    }

    function doMove(fromWs, fromPos, toWs, toPos, fromWsWindows, toWsWindows) {
        if (fromWs === -1 || fromPos === -1 || dragWinIndex === "") return

        var addr = dragWinIndex

        if (fromWs === toWs) {
            if (toPos !== fromPos && toPos < toWsWindows.length) {
                var targetAddr = toWsWindows[toPos].address
                Hyprland.dispatch(`focuswindow address:${targetAddr}`)
                Hyprland.dispatch(`swapwindow address:${addr}`)
            }
        } else {
            Hyprland.dispatch(`movetoworkspacesilent ${toWs}, address:${addr}`)
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: flickable
        property: "contentY"
        duration: Appearance.animation.elementMove.duration
        easing.type: Appearance.animation.elementMove.type
    }

    Item {
        id: dragGhost
        parent: root
        visible: root.isDragging
        width: root.cellWidth
        height: root.wsHeight
        x: root.ghostX - width / 2
        y: root.ghostY - height / 2
        z: 9999

        Drag.active: root.isDragging
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.keys: ["winDrag"]

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.transparentize(Appearance.colors.colSecondary, 0.6)
            radius: Appearance.rounding.normal
            border.width: 2
            border.color: Appearance.colors.colSecondary
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        interactive: !root.isDragging
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

        Column {
            id: column
            width: parent.width
            spacing: root.wsPadding
            topPadding: root.wsPadding
            bottomPadding: root.wsHeight

            Repeater {
                model: root.maxWorkspaces 
                delegate: Item {
                    id: rowItem
                    required property int index
                    property int wsId: index + 1
                    property bool isActiveWs: wsId === root.activeWorkspaceId
                    property bool isDragTarget: wsId === root.dragToWs
                    property var wsWindows: root.getWindowsSortedByX(wsId)
                    property int activeWinIdx: {
                        if (wsWindows.length === 0) return 0
                        var minId = Infinity, minIdx = 0
                        for (var i = 0; i < wsWindows.length; i++) {
                            if (wsWindows[i].focusHistoryID < minId) {
                                minId = wsWindows[i].focusHistoryID
                                minIdx = i
                            }
                        }
                        return minIdx
                    }
                    property var activeWin: {
                        if (wsWindows.length === 0) return null
                        var tiled = wsWindows.find((w, i) => i === activeWinIdx && !w.floating)
                        if (tiled) return tiled
                        var anyTiled = wsWindows.find(w => !w.floating)
                        if (anyTiled) return anyTiled
                        return wsWindows[activeWinIdx]
                    }
                    property real winW: activeWin ? activeWin.size[0] * root.scale : root.cellWidth
                    property real winH: activeWin ? activeWin.size[1] * root.scale : root.wsHeight

                    width: parent.width
                    height: root.wsHeight

                    DropArea {
                        anchors.fill: parent
                        keys: ["winDrag"]

                        onEntered: drag => {
                            root.dragToWs = rowItem.wsId
                        }
                        onExited: {
                            if (root.dragToWs === rowItem.wsId)
                                root.dragToWs = -1
                        }
                        onDropped: drop => {
                            var fromWs = root.dragFromWs
                            var fromPos = root.dragFromPos
                            var toWs = rowItem.wsId

                            var ghostLocal = mapFromItem(root, root.ghostX, root.ghostY)
                            var toPos = root.findTargetPos(
                                ghostLocal.x,
                                rowItem.wsWindows,
                                rowItem.activeWinIdx
                            )

                            root.doMove(fromWs, fromPos, toWs, toPos,
                                        root.getWindowsSortedByX(fromWs),
                                        rowItem.wsWindows)

                            root.dragFromWs = -1
                            root.dragFromPos = -1
                            root.dragToWs = -1
                            root.dragWinIndex = ""
                        }
                    }

                    Rectangle {
                        visible: rowItem.isActiveWs
                        x: root.screenCenterX - rowItem.winW / 2
                        y: (root.wsHeight - rowItem.winH) / 2
                        width: rowItem.winW
                        height: rowItem.winH
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 2
                        border.color: Appearance.colors.colSecondary
                        z: 10
                        Behavior on x { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on height { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                    }

                    Rectangle {
                        visible: rowItem.isDragTarget && root.isDragging
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: ColorUtils.transparentize(Appearance.colors.colSecondary, 0.88)
                        border.width: 2
                        border.color: Appearance.colors.colSecondary
                        z: 0
                    }

                    Rectangle {
                        visible: rowItem.wsWindows.length === 0
                        anchors.centerIn: parent
                        width: root.cellWidth
                        height: root.wsHeight
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSurfaceContainerLow
                        z: 1

                        StyledText {
                            anchors.centerIn: parent
                            text: rowItem.wsId
                            font {
                                pixelSize: root.wsHeight * 0.55
                                weight: Font.DemiBold
                                family: Appearance.font.family.expressive
                            }
                            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.isDragging
                            onClicked: {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`workspace ${rowItem.wsId}`)
                            }
                        }
                    }

                    Repeater {
                        model: rowItem.wsWindows.length
                        delegate: Item {
                            id: winContainer
                            required property int index

                            property var win: rowItem.wsWindows[index]
                            property bool isActiveWin: index === rowItem.activeWinIdx && rowItem.isActiveWs
                            property int offset: index - rowItem.activeWinIdx
                            property bool isBeingDragged: root.isDragging &&
                                root.dragFromWs === rowItem.wsId &&
                                root.dragFromPos === index

                            x: root.screenCenterX - rowItem.winW / 2
                               + offset * (rowItem.winW + root.wsPadding)
                            y: (root.wsHeight - rowItem.winH) / 2
                            width: rowItem.winW
                            height: rowItem.winH
                            z: 1

                            opacity: isBeingDragged ? 0.15 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on x {
                                enabled: !isBeingDragged
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }

                            OverviewWindow {
                                id: ovWin
                                anchors.fill: parent

                                toplevel: root.getToplevelForWindow(winContainer.win)
                                windowData: winContainer.win
                                monitorData: root.getMonitorDataForWindow(winContainer.win)
                                widgetMonitor: root.getMonitorDataForWindow(winContainer.win)
                                scale: root.scale
                                xOffset: 0
                                yOffset: 0
                                opacity: winContainer.isActiveWin ? 1.0 : 0.75

                                topLeftRadius: Appearance.rounding.normal
                                topRightRadius: Appearance.rounding.normal
                                bottomLeftRadius: Appearance.rounding.normal
                                bottomRightRadius: Appearance.rounding.normal

                                Behavior on opacity {
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 10
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                property real pressX: 0
                                property real pressY: 0
                                property bool dragStarted: false
                                property real dragStartTime: 0

                                onEntered: ovWin.hovered = true
                                onExited: { if (!dragStarted) ovWin.hovered = false }

                                onPressed: mouse => {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    dragStarted = false
                                    dragStartTime = Date.now()
                                    ovWin.pressed = true

                                    root.dragFromWs = rowItem.wsId
                                    root.dragFromPos = winContainer.index
                                    root.dragWinIndex = winContainer.win?.address ?? ""

                                    var gp = mapToItem(root, mouse.x, mouse.y)
                                    root.ghostX = gp.x
                                    root.ghostY = gp.y
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed) return
                                    var gp = mapToItem(root, mouse.x, mouse.y)
                                    root.ghostX = gp.x
                                    root.ghostY = gp.y

                                    var dx = Math.abs(mouse.x - pressX)
                                    var dy = Math.abs(mouse.y - pressY)
                                    var elapsed = Date.now() - dragStartTime

                                    if (!dragStarted && (dx > 12 || dy > 12 ||
                                        (elapsed > 200 && (dx > 6 || dy > 6)))) {
                                        dragStarted = true
                                        root.isDragging = true
                                    }
                                }

                                onReleased: mouse => {
                                    ovWin.pressed = false
                                    ovWin.hovered = containsMouse

                                    if (root.isDragging) {
                                        dragGhost.Drag.drop()
                                    }

                                    root.isDragging = false
                                    dragStarted = false
                                    root.dragFromWs = -1
                                    root.dragFromPos = -1
                                    root.dragToWs = -1
                                    root.dragWinIndex = ""
                                }

                                onClicked: event => {
                                    if (dragStarted) return
                                    if (!winContainer.win) return
                                    if (event.button === Qt.LeftButton) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`focuswindow address:${winContainer.win.address}`)
                                        event.accepted = true
                                    } else if (event.button === Qt.MiddleButton) {
                                        Hyprland.dispatch(`closewindow address:${winContainer.win.address}`)
                                        event.accepted = true
                                    }
                                }

                                StyledToolTip {
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: parent.containsMouse && !root.isDragging
                                    text: `${winContainer.win?.title ?? ""}\n[${winContainer.win?.class ?? ""}]`
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
