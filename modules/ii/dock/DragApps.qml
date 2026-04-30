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
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root

    property real btnSize: 46
    property real btnSpacing: 2
    property real buttonPadding: 5
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30
    property Item lastHoveredButton: null
    property bool buttonHovered: false
    property bool requestDockShow: previewPopup.show
    signal orderChanged(var newOrder)
    property var  _workOrder: pinnedApps.slice()
    property int  activeDragVisualIndex: -1
    property bool _dragging: false

    onPinnedAppsChanged: {
        if (!_dragging) {
            _workOrder = pinnedApps.slice()
        }
    }

    implicitWidth:  _workOrder.length * btnSize + Math.max(0, _workOrder.length - 1) * btnSpacing
    implicitHeight: parent?.height ?? btnSize

    function popupCenterXForButton(button) {
        if (!button || !root.QsWindow) return 0
        return root.QsWindow.mapFromItem(button, button.width / 2, 0).x
    }

    function swapSlots(fromPos, toPos) {
        if (fromPos === toPos) return
        if (fromPos < 0 || fromPos >= _workOrder.length) return
        if (toPos   < 0 || toPos   >= _workOrder.length) return
        let arr = _workOrder.slice()
        let tmp = arr[fromPos]
        arr[fromPos] = arr[toPos]
        arr[toPos]   = tmp
        _workOrder = arr
    }

    function commitOrder() {
        const newOrder = _workOrder.slice()
        Config.options.dock.pinnedApps = newOrder
        orderChanged(newOrder)
    }

    Repeater {
        id: slotRepeater
        model: root._workOrder.length

        delegate: Item {
            id: slotItem
            required property int index

            property string appId:     root._workOrder[index] ?? ""
            property var    appEntry:  TaskbarApps.apps.find(a => a.appId === appId) ?? null
            property var    deskEntry: appEntry ? DesktopEntries.heuristicLookup(appId) : null
            property bool   appActive: appEntry?.toplevels?.find(t => t.activated) !== undefined
            property int    _lastFocused: -1

            width:  root.btnSize
            height: root.implicitHeight
            x:      index * (root.btnSize + root.btnSpacing)

            opacity: (root.activeDragVisualIndex === index) ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 110 } }

            Item {
                visible: dragHandler.active
                z: 1000
                width:  root.btnSize
                height: root.btnSize
                anchors.verticalCenter: parent.verticalCenter

                x: {
                    if (!dragHandler.active) return 0
                    var lp = slotItem.mapFromItem(null,
                        dragHandler.centroid.scenePosition.x,
                        dragHandler.centroid.scenePosition.y)
                    return lp.x - width / 2
                }

                IconImage {
                    id: ghostIcon
                    anchors.centerIn: parent
                    source: Quickshell.iconPath(
                        AppSearch.guessIcon(root._workOrder[root.activeDragVisualIndex] ?? ""),
                        "image-missing")
                    implicitSize: root.btnSize * 0.65
                    opacity: 0.85

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowVerticalOffset: 4
                        shadowBlur: 0.65
                        shadowColor: "#80000000"
                    }
                }
            }

            DockButton {
                id: dockBtn
                anchors.fill: parent

                property var appToplevel: slotItem.appEntry

                topInset:    Appearance.sizes.hyprlandGapsOut + root.buttonPadding
                bottomInset: Appearance.sizes.hyprlandGapsOut + root.buttonPadding

                implicitWidth: implicitHeight - topInset - bottomInset

                hoverEnabled: true
                onHoveredChanged: {
                    if (hovered) {
                        root.lastHoveredButton = dockBtn
                        root.buttonHovered = true
                    } else {
                        root.buttonHovered = false
                    }
                }

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
                        id: appIcon
                        anchors.centerIn: parent
                        source: Quickshell.iconPath(
                            AppSearch.guessIcon(slotItem.appId),
                            "image-missing")
                        implicitSize: 33
                    }

                    Loader {
                        active: Config.options.dock.monochromeIcons
                        anchors.fill: appIcon
                        sourceComponent: Item {
                            Desaturate {
                                id: desaturatedIcon
                                visible: false
                                anchors.fill: parent
                                source: appIcon
                                desaturation: 0.8
                            }
                            ColorOverlay {
                                anchors.fill: desaturatedIcon
                                source: desaturatedIcon
                                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                            }
                        }
                    }

                    RowLayout {
                        spacing: 3
                        anchors {
                            top: appIcon.bottom
                            topMargin: 2
                            horizontalCenter: parent.horizontalCenter
                        }
                        Repeater {
                            model: Math.min(slotItem.appEntry?.toplevels?.length ?? 0, 3)
                            delegate: Rectangle {
                                required property int index
                                radius:         Appearance.rounding.full
                                implicitWidth:  (slotItem.appEntry?.toplevels?.length ?? 0) <= 3
                                                ? 10 : 4
                                implicitHeight: 4
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
                        root.buttonHovered = false
                        return
                    }
                    root.activeDragVisualIndex = -1
                    root._dragging = false
                    root.commitOrder()
                }

                onCentroidChanged: {
                    if (!active) return
                    const currentVisualIdx = root.activeDragVisualIndex
                    if (currentVisualIdx < 0) return

                    const dragX = dragHandler.centroid.scenePosition.x
                    let minDist    = Infinity
                    let nearestIdx = currentVisualIdx

                    for (let i = 0; i < slotRepeater.count; i++) {
                        if (i === currentVisualIdx) continue
                        const child = slotRepeater.itemAt(i)
                        if (!child) continue
                        const cc   = child.mapToItem(null, child.width / 2, child.height / 2)
                        const dist = Math.abs(dragX - cc.x)
                        if (dist < minDist) { minDist = dist; nearestIdx = i }
                    }

                    if (nearestIdx !== currentVisualIdx) {
                        const neighbor = slotRepeater.itemAt(nearestIdx)
                        if (!neighbor) return
                        const nc = neighbor.mapToItem(null, neighbor.width / 2, neighbor.height / 2)
                        const shouldSwap = (nearestIdx > currentVisualIdx)
                            ? (dragX >= nc.x)
                            : (dragX <= nc.x)

                        if (shouldSwap) {
                            root.swapSlots(currentVisualIdx, nearestIdx)
                            root.activeDragVisualIndex = nearestIdx
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: previewPopup
        property var appTopLevel: root.lastHoveredButton?.appToplevel ?? null

        property bool shouldShow: (popupMouseArea.containsMouse || root.buttonHovered)
                                  && !root._dragging
                                  && appTopLevel
                                  && appTopLevel.toplevels
                                  && appTopLevel.toplevels.length > 0

        property bool show: false
        property real cachedCenterX: 0

        Connections {
            target: root
            function onLastHoveredButtonChanged() {
                if (root.lastHoveredButton && root.QsWindow)
                    previewPopup.cachedCenterX = root.popupCenterXForButton(root.lastHoveredButton)
            }
            function onButtonHoveredChanged() {
                if (root.buttonHovered && root.lastHoveredButton && root.QsWindow)
                    previewPopup.cachedCenterX = root.popupCenterXForButton(root.lastHoveredButton)
                updateTimer.restart()
            }
        }

        onShouldShowChanged: {
            updateTimer.restart()
        }

        Timer {
            id: updateTimer
            interval: 100
            onTriggered: {
                previewPopup.show = previewPopup.shouldShow
            }
        }

        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.None
            gravity: Edges.Top | Edges.Right
            edges: Edges.Top | Edges.Left
        }

        visible: popupBackground.opacity > 0
        color: "transparent"
        implicitWidth: root.QsWindow.window?.width ?? 1
        implicitHeight: popupMouseArea.implicitHeight
                        + root.windowControlsHeight
                        + Appearance.sizes.elevationMargin * 2

        MouseArea {
            id: popupMouseArea
            anchors.bottom: parent.bottom
            implicitWidth:  popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: root.maxWindowPreviewHeight
                            + root.windowControlsHeight
                            + Appearance.sizes.elevationMargin * 2
            hoverEnabled: true
            x: previewPopup.cachedCenterX - width / 2

            StyledRectangularShadow {
                target: popupBackground
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            Rectangle {
                id: popupBackground
                property real padding: 5
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                clip: true
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.elevationMargin
                anchors.horizontalCenter: parent.horizontalCenter
                implicitHeight: previewRowLayout.implicitHeight + padding * 2
                implicitWidth:  previewRowLayout.implicitWidth  + padding * 2
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                RowLayout {
                    id: previewRowLayout
                    anchors.centerIn: parent

                    Repeater {
                        model: ScriptModel {
                            values: previewPopup.appTopLevel?.toplevels ?? []
                        }

                        RippleButton {
                            id: windowButton
                            Layout.fillHeight: true
                            required property var modelData
                            padding: 0

                            middleClickAction: () => { windowButton.modelData?.close() }
                            onClicked: { windowButton.modelData?.activate() }

                            contentItem: ColumnLayout {
                                implicitWidth:  screencopyView.implicitWidth
                                implicitHeight: screencopyView.implicitHeight

                                ButtonGroup {
                                    contentWidth: parent.width - anchors.margins * 2

                                    StyledText {
                                        Layout.margins: 5
                                        Layout.fillWidth: true
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: windowButton.modelData?.title
                                        elide: Text.ElideRight
                                        color: Appearance.m3colors.m3onSurface
                                    }

                                    GroupButton {
                                        id: closeButton
                                        colBackground: ColorUtils.transparentize(
                                            Appearance.colors.colSurfaceContainer)
                                        baseWidth:    root.windowControlsHeight
                                        baseHeight:   root.windowControlsHeight
                                        buttonRadius: Appearance.rounding.full
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "close"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                        onClicked: { windowButton.modelData?.close() }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    implicitHeight: screencopyView.height
                                    implicitWidth:  screencopyView.width

                                    ScreencopyView {
                                        id: screencopyView
                                        anchors.centerIn: parent
                                        captureSource: windowButton.modelData
                                        live: true
                                        paintCursor: true
                                        constraintSize: Qt.size(
                                            root.maxWindowPreviewWidth,
                                            root.maxWindowPreviewHeight)
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width:  screencopyView.width
                                                height: screencopyView.height
                                                radius: Appearance.rounding.small
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
    }
}
