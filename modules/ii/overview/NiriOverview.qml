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

    readonly property real monitorW: screen?.width ?? 1920
    readonly property real monitorH: screen?.height ?? 1080
    readonly property real screenCenterX: monitorW / 2

    property var windows: HyprlandData.windowList

    property int dragFromWs: -1
    property int dragFromPos: -1
    property int dragToWs: -1
    property bool isDragging: false
    property real ghostX: 0
    property real ghostY: 0
    property string dragWinIndex: ""

    implicitWidth: monitorW
    implicitHeight: monitorH

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

    function getWindowsBBox(wins) {
        if (!wins || wins.length === 0)
            return { x: 0, y: 0, w: root.monitorW, h: root.monitorH }

        var refMon = HyprlandData.monitors.find(m => m.id === wins[0].monitor)
        var refW = refMon ? refMon.width / (refMon.scale ?? 1.0) : root.monitorW
        var refH = refMon ? refMon.height / (refMon.scale ?? 1.0) : root.monitorH

        var minX = Infinity, minY = Infinity
        var maxX = -Infinity, maxY = -Infinity

        for (var i = 0; i < wins.length; i++) {
            var w = wins[i]
            var mon = HyprlandData.monitors.find(m => m.id === w.monitor)
            var monD = getMonitorDataForWindow(w)
            var wx = w.at[0] - (mon?.x ?? 0) - (monD?.reserved[0] ?? 0)
            var wy = w.at[1] - (mon?.y ?? 0) - (monD?.reserved[1] ?? 0)
            minX = Math.min(minX, wx)
            minY = Math.min(minY, wy)
            maxX = Math.max(maxX, wx + w.size[0])
            maxY = Math.max(maxY, wy + w.size[1])
        }

        return {
            x: Math.min(minX, 0),
            y: Math.min(minY, 0),
            w: Math.max(maxX, refW),
            h: Math.max(maxY, refH)
        }
    }

    function getFitScale(wins) {
        if (!wins || wins.length === 0) return 1.0
        var bbox = getWindowsBBox(wins)
        var availW = bbox.w * root.scale * 0.92
        var availH = root.wsHeight * 0.96
        var contentW = bbox.w * root.scale
        var contentH = bbox.h * root.scale
        return Math.min(availW / contentW, availH / contentH, 1.0)
    }

    function getWinXInRow(win, monData, fitScale, bbox) {
        if (!win || !monData) return 0
        var mon = HyprlandData.monitors.find(m => m.id === win.monitor)
        var rawX = win.at[0] - (mon?.x ?? 0) - (monData.reserved[0] ?? 0)
        var relX = (rawX - bbox.x) * root.scale * fitScale
        var totalW = bbox.w * root.scale * fitScale
        var centerX = root.implicitWidth / 2
        return centerX - totalW / 2 + relX
    }

    function getWinYInRow(win, monData, fitScale, bbox) {
        if (!win || !monData) return 0
        var mon = HyprlandData.monitors.find(m => m.id === win.monitor)
        var rawY = win.at[1] - (mon?.y ?? 0) - (monData.reserved[1] ?? 0)
        var relY = (rawY - bbox.y) * root.scale * fitScale
        var totalH = bbox.h * root.scale * fitScale
        return (root.wsHeight - totalH) / 2 + relY
    }

    function getWinW(win, fitScale) {
        if (!win) return 80 * root.scale * fitScale
        return win.size[0] * root.scale * fitScale
    }

    function getWinH(win, fitScale) {
        if (!win) return 60 * root.scale * fitScale
        return win.size[1] * root.scale * fitScale
    }

    function findTargetPos(ghostLocalX, ghostLocalY, items, fitScale, bbox) {
        var minDist = Infinity
        var bestPos = items.length
        for (var i = 0; i < items.length; i++) {
            var monD = getMonitorDataForWindow(items[i])
            var cx = getWinXInRow(items[i], monD, fitScale, bbox) + getWinW(items[i], fitScale) / 2
            var cy = getWinYInRow(items[i], monD, fitScale, bbox) + getWinH(items[i], fitScale) / 2
            var dx = ghostLocalX - cx
            var dy = ghostLocalY - cy
            var dist = Math.sqrt(dx*dx + dy*dy)
            if (dist < minDist) {
                minDist = dist
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
        width: 120
        height: 80
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
                    property var wsBBox: root.getWindowsBBox(wsWindows)
                    property real wsFitScale: root.getFitScale(wsWindows)

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
                    property var activeWin: wsWindows.length > 0 ? wsWindows[activeWinIdx] : null
                    property var activeMonData: root.getMonitorDataForWindow(activeWin)

                    width: parent.width
                    height: root.wsHeight

                    DropArea {
                        anchors.fill: parent
                        keys: ["winDrag"]
                        onEntered: drag => { root.dragToWs = rowItem.wsId }
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
                                ghostLocal.x, ghostLocal.y,
                                rowItem.wsWindows,
                                rowItem.wsFitScale,
                                rowItem.wsBBox
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

                    // Empty Workspace 
                    Rectangle {
                        visible: rowItem.wsWindows.length === 0
                        anchors.centerIn: parent
                        width: root.monitorW * 0.15
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

                    // Active Window
                    Rectangle {
                        visible: rowItem.isActiveWs && rowItem.activeWin !== null
                        x: root.getWinXInRow(rowItem.activeWin, rowItem.activeMonData, rowItem.wsFitScale, rowItem.wsBBox)
                        y: root.getWinYInRow(rowItem.activeWin, rowItem.activeMonData, rowItem.wsFitScale, rowItem.wsBBox)
                        width: root.getWinW(rowItem.activeWin, rowItem.wsFitScale)
                        height: root.getWinH(rowItem.activeWin, rowItem.wsFitScale)
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 2
                        border.color: Appearance.colors.colSecondary
                        z: 10
                        Behavior on x { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on y { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on height { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                    }

                    // Highlight drop target
                    Rectangle {
                        visible: rowItem.isDragTarget && root.isDragging
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: ColorUtils.transparentize(Appearance.colors.colSecondary, 0.88)
                        border.width: 2
                        border.color: Appearance.colors.colSecondary
                        z: 0
                    }

                    Repeater {
                        model: rowItem.wsWindows.length
                        delegate: Item {
                            id: winContainer
                            required property int index

                            property var win: rowItem.wsWindows[index]
                            property var winMonData: root.getMonitorDataForWindow(win)
                            property bool isActiveWin: index === rowItem.activeWinIdx && rowItem.isActiveWs
                            property bool isBeingDragged: root.isDragging &&
                                root.dragFromWs === rowItem.wsId &&
                                root.dragFromPos === index

                            x: root.getWinXInRow(win, winMonData, rowItem.wsFitScale, rowItem.wsBBox)
                            y: root.getWinYInRow(win, winMonData, rowItem.wsFitScale, rowItem.wsBBox)
                            width: root.getWinW(win, rowItem.wsFitScale)
                            height: root.getWinH(win, rowItem.wsFitScale)
                            z: 1

                            opacity: isBeingDragged ? 0.15 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on x {
                                enabled: !isBeingDragged
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on y {
                                enabled: !isBeingDragged
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on width {
                                enabled: !isBeingDragged
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on height {
                                enabled: !isBeingDragged
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }

                            OverviewWindow {
                                id: ovWin
                                anchors.fill: parent

                                toplevel: root.getToplevelForWindow(winContainer.win)
                                windowData: winContainer.win
                                monitorData: winContainer.winMonData
                                widgetMonitor: winContainer.winMonData
                                scale: root.scale * rowItem.wsFitScale
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
