import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

Item {
    id: root

    property real iconSize:      23
    property real btnSize:       28
    property real btnSpacing:    2
    property real buttonPadding: 4
    property bool vertical:    Config.options.bar.vertical
    property bool isMaterial:  Config.options.bar.cornerStyle === 3
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property var activeUnpinned: TaskbarApps.apps.filter(
        a => !a.pinned && a.appId !== "SEPARATOR" && a.toplevels.length > 0
    )
    property bool showSeparator: _workOrder.length > 0 && activeUnpinned.length > 0
    property var  _workOrder:            pinnedApps.slice()
    property int  activeDragVisualIndex: -1
    property bool _dragging:             false

    onPinnedAppsChanged: {
        if (!_dragging)
            _workOrder = pinnedApps.slice()
    }

    implicitWidth:  vertical
        ? (isMaterial ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth - 10)
        : pill.implicitWidth
    implicitHeight: vertical
        ? pill.implicitHeight
        : Appearance.sizes.barHeight

    function swapSlots(from, to) {
        if (from === to) return
        if (from < 0 || from >= _workOrder.length) return
        if (to   < 0 || to   >= _workOrder.length) return
        let arr = _workOrder.slice()
        let tmp = arr[from]; arr[from] = arr[to]; arr[to] = tmp
        _workOrder = arr
    }

    function commitOrder() {
        Config.options.dock.pinnedApps = _workOrder.slice()
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full

        implicitWidth: root.isMaterial && !root.vertical
            ? flow.implicitWidth + 10
            : root.vertical
                ? (root.isMaterial ? 32 : Appearance.sizes.verticalBarWidth - 10)
                : flow.implicitWidth + 4

        implicitHeight: root.isMaterial && root.vertical
            ? flow.implicitHeight + 10
            : root.isMaterial
                ? 32
                : root.vertical
                    ? flow.implicitHeight + 4
                    : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow:    root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: root.btnSpacing

            // ── 1. PINNED APPS ───────────────────────────────────────────
            Repeater {
                id: pinnedRepeater
                model: root._workOrder.length

                delegate: Item {
                    id: slotItem
                    required property int index

                    property string appId:        root._workOrder[index] ?? ""
                    property var    appEntry:     TaskbarApps.apps.find(a => a.appId === appId) ?? null
                    property var    deskEntry:    DesktopEntries.heuristicLookup(appId)
                    property bool   appActive:    appEntry?.toplevels?.find(t => t.activated) !== undefined
                    property int    _lastFocused: -1

                    Connections {
                        target: DesktopEntries
                        function onApplicationsChanged() {
                            slotItem.deskEntry = DesktopEntries.heuristicLookup(slotItem.appId)
                        }
                    }

                    width:  root.btnSize
                    height: root.btnSize

                    opacity: 1
                    Behavior on opacity { NumberAnimation { duration: 110 } }

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            const entry = slotItem.appEntry
                            if (!entry || entry.toplevels.length === 0) {
                                slotItem.deskEntry?.execute()
                                return
                            }
                            const next = (slotItem._lastFocused + 1) % entry.toplevels.length
                            slotItem._lastFocused = next
                            entry.toplevels[next].activate()
                        }
                        middleClickAction: () => { slotItem.deskEntry?.execute() }
                        altAction:         () => { TaskbarApps.togglePin(slotItem.appId) }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: pinnedIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(slotItem.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: pinnedIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat; visible: false
                                        anchors.fill: parent
                                        source: pinnedIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat; source: desat
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? pinnedIcon.right    : undefined
                                    top:    root.vertical ? undefined            : pinnedIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(slotItem.appEntry?.toplevels?.length ?? 0, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        radius: Appearance.rounding.full
                                        implicitWidth:  root.vertical
                                            ? 2
                                            : (slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2
                                        implicitHeight: root.vertical
                                            ? ((slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2)
                                            : 2
                                        color: slotItem.appActive
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            if (active) {
                                root._dragging = true
                                root.activeDragVisualIndex = index
                                return
                            }
                            root.activeDragVisualIndex = -1
                            root._dragging = false
                            root.commitOrder()
                        }

                        onCentroidChanged: {
                            if (!active) return
                            const currentIdx = root.activeDragVisualIndex
                            if (currentIdx < 0) return

                            const dragPos = root.vertical
                                ? dragHandler.centroid.scenePosition.y
                                : dragHandler.centroid.scenePosition.x

                            let minDist = Infinity, nearest = currentIdx

                            for (let i = 0; i < pinnedRepeater.count; i++) {
                                if (i === currentIdx) continue
                                const child = pinnedRepeater.itemAt(i)
                                if (!child) continue
                                const cc = child.mapToItem(null, child.width / 2, child.height / 2)
                                const ccPos = root.vertical ? cc.y : cc.x
                                const dist  = Math.abs(dragPos - ccPos)
                                if (dist < minDist) { minDist = dist; nearest = i }
                            }

                            if (nearest !== currentIdx) {
                                const nb = pinnedRepeater.itemAt(nearest)
                                if (!nb) return
                                const nc = nb.mapToItem(null, nb.width / 2, nb.height / 2)
                                const ncPos = root.vertical ? nc.y : nc.x
                                const shouldSwap = (nearest > currentIdx)
                                    ? (dragPos >= ncPos)
                                    : (dragPos <= ncPos)
                                if (shouldSwap) {
                                    root.swapSlots(currentIdx, nearest)
                                    root.activeDragVisualIndex = nearest
                                }
                            }
                        }
                    }
                }
            }

            // ── 2. SEPARATOR ─────────────────────────────────────────────
            Item {
                width:   root.vertical ? root.btnSize          : (root.showSeparator ? (1 + root.btnSpacing * 3) : 0)
                height:  root.vertical ? (root.showSeparator ? (1 + root.btnSpacing * 3) : 0) : root.btnSize
                visible: root.showSeparator

                Rectangle {
                    anchors.centerIn: parent
                    width:  root.vertical ? Math.round(root.btnSize * 0.6) : 1
                    height: root.vertical ? 1 : Math.round(root.btnSize * 0.6)
                    color:  root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }

            // ── 3. ACTIVE UNPINNED APPS ───────────────────────────────────
            Repeater {
                id: activeRepeater
                model: ScriptModel { values: root.activeUnpinned }

                delegate: Item {
                    id: activeSlot
                    required property var modelData

                    property bool appIsActive: modelData.toplevels.find(t => t.activated) !== undefined
                    property int  _lastFocused: -1

                    width:  root.btnSize
                    height: root.btnSize

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            if (activeSlot.modelData.toplevels.length === 0) return
                            const next = (activeSlot._lastFocused + 1) % activeSlot.modelData.toplevels.length
                            activeSlot._lastFocused = next
                            activeSlot.modelData.toplevels[next].activate()
                        }
                        middleClickAction: () => {
                            DesktopEntries.heuristicLookup(activeSlot.modelData.appId)?.execute()
                        }
                        altAction: () => {
                            TaskbarApps.togglePin(activeSlot.modelData.appId)
                        }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: activeIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(activeSlot.modelData.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: activeIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat2; visible: false
                                        anchors.fill: parent
                                        source: activeIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat2; source: desat2
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? activeIcon.right    : undefined
                                    top:    root.vertical ? undefined            : activeIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(activeSlot.modelData.toplevels.length, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        radius: Appearance.rounding.full
                                        implicitWidth:  root.vertical
                                            ? 2
                                            : activeSlot.modelData.toplevels.length <= 3 ? 4 : 2
                                        implicitHeight: root.vertical
                                            ? (activeSlot.modelData.toplevels.length <= 3 ? 4 : 2)
                                            : 2
                                        color: activeSlot.appIsActive
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
