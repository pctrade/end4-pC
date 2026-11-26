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

Item {
    id: root

    property real btnSize: DockStyle.buttonSize
    property real btnSpacing: DockStyle.buttonSpacing + DockStyle.iconSpacing
    property real buttonPadding: DockStyle.padding
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30
    property Item lastHoveredButton: null
    property bool buttonHovered: false
    property bool requestDockShow: previewPopup.show
    property var contextMenu: null
    signal orderChanged(var newOrder)
    property var  _workOrder: pinnedApps.slice()
    property int  activeDragVisualIndex: -1
    property bool _dragging: false

    onPinnedAppsChanged: {
        if (!_dragging) {
            _workOrder = pinnedApps.slice()
        }
    }

    readonly property real trackLength: _workOrder.length * btnSize + Math.max(0, _workOrder.length - 1) * btnSpacing

    Layout.fillHeight: false
    Layout.fillWidth: false
    implicitWidth:  DockStyle.vertical ? (parent?.width ?? btnSize) : trackLength
    implicitHeight: DockStyle.vertical ? trackLength : (parent?.height ?? btnSize)

    function popupCenterForButton(button) {
        if (!button || !root.QsWindow) return 0
        const point = root.QsWindow.mapFromItem(button, button.width / 2, button.height / 2)
        return DockStyle.vertical ? point.y : point.x
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
            property var    deskEntry: DesktopEntries.heuristicLookup(appId)
            property bool   appActive: appEntry?.toplevels?.find(t => t.activated) !== undefined

            Connections {
                target: DesktopEntries
                function onApplicationsChanged() {
                    slotItem.deskEntry = DesktopEntries.heuristicLookup(slotItem.appId)
                }
            }

            width:  DockStyle.vertical ? root.implicitWidth : root.btnSize
            height: DockStyle.vertical ? root.btnSize : root.implicitHeight
            x:      DockStyle.vertical ? 0 : index * (root.btnSize + root.btnSpacing)
            y:      DockStyle.vertical ? index * (root.btnSize + root.btnSpacing) : 0

            Behavior on x {
                enabled: root.activeDragVisualIndex !== slotItem.index
                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
            }

            Behavior on y {
                enabled: root.activeDragVisualIndex !== slotItem.index
                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
            }

            opacity: (root.activeDragVisualIndex === index) ? 0.0 : 1.0
            scale:   (root.activeDragVisualIndex === index) ? 0.7 : 1.0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Item {
                visible: dragHandler.active
                z: 1000
                width:  root.btnSize
                height: root.btnSize
                anchors.verticalCenter: DockStyle.vertical ? undefined : parent.verticalCenter
                anchors.horizontalCenter: DockStyle.vertical ? parent.horizontalCenter : undefined

                readonly property point dragPoint: dragHandler.active
                    ? slotItem.mapFromItem(null, dragHandler.centroid.scenePosition.x, dragHandler.centroid.scenePosition.y)
                    : Qt.point(0, 0)
                x: DockStyle.vertical ? 0 : dragPoint.x - width / 2
                y: DockStyle.vertical ? dragPoint.y - height / 2 : 0

                scale: dragHandler.active ? 1.15 : 0.9
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }

                IconImage {
                    id: ghostIcon
                    anchors.centerIn: parent
                    source: SystemAppearance.iconPath(
                        AppSearch.guessIcon(root._workOrder[root.activeDragVisualIndex] ?? ""),
                        "image-missing")
                    implicitSize: root.btnSize * 0.65
                    opacity: 0.85

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowVerticalOffset: dragHandler.active ? 7 : 4
                        shadowBlur: dragHandler.active ? 0.85 : 0.65
                        shadowColor: "#80000000"

                        Behavior on shadowVerticalOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on shadowBlur { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }

            DockButton {
                id: dockBtn
                anchors.fill: parent

                property var appToplevel: slotItem.appEntry
                property var desktopEntry: slotItem.deskEntry
                magnifiable: true

                innerInset: DockStyle.iconInset
                outerInset: DockStyle.iconInset
                Layout.topMargin: 0
                Layout.leftMargin: 0

                hoverEnabled: true
                hoverOwner: root
                windows: slotItem.appEntry?.toplevels ?? []
                onClicked: {
                    if (!dockBtn.focusNextWindow())
                        slotItem.deskEntry?.execute()
                }
                middleClickAction: () => { slotItem.deskEntry?.execute() }
                altAction:         () => { root.contextMenu?.open(dockBtn, slotItem.appId) }

                DockTooltip {
                    text: slotItem.deskEntry?.name || slotItem.appId
                    show: dockBtn.hovered && !root._dragging
                    app: slotItem.appEntry ?? null
                    contextMenu: root.contextMenu
                }

                contentItem: DockAppIcon {
                    anchors.centerIn: parent
                    iconSource: SystemAppearance.iconPath(AppSearch.guessIcon(slotItem.appId), "image-missing")
                    windowCount: slotItem.appEntry?.toplevels?.length ?? 0
                    active: slotItem.appActive
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

                    const dragX = DockStyle.vertical ? dragHandler.centroid.scenePosition.y : dragHandler.centroid.scenePosition.x
                    let minDist    = Infinity
                    let nearestIdx = currentVisualIdx

                    for (let i = 0; i < slotRepeater.count; i++) {
                        if (i === currentVisualIdx) continue
                        const child = slotRepeater.itemAt(i)
                        if (!child) continue
                        const cc   = child.mapToItem(null, child.width / 2, child.height / 2)
                        const dist = Math.abs(dragX - (DockStyle.vertical ? cc.y : cc.x))
                        if (dist < minDist) { minDist = dist; nearestIdx = i }
                    }

                    if (nearestIdx !== currentVisualIdx) {
                        const neighbor = slotRepeater.itemAt(nearestIdx)
                        if (!neighbor) return
                        const nc = neighbor.mapToItem(null, neighbor.width / 2, neighbor.height / 2)
                        const ncAxis = DockStyle.vertical ? nc.y : nc.x
                        const shouldSwap = (nearestIdx > currentVisualIdx)
                            ? (dragX >= ncAxis)
                            : (dragX <= ncAxis)

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
        // The button whose windows the card shows. It only changes to a button
        // that has a preview, so a card that is closing (pointer moved to an app
        // with no windows) keeps its content and place while it fades out.
        property Item shownButton: null
        readonly property var appTopLevel: shownButton?.appToplevel ?? null
        // Also catches the hovered app opening its first window.
        readonly property bool hoveredHasPreview: DockStyle.previewsFor(root.lastHoveredButton?.appToplevel)
        onHoveredHasPreviewChanged: followHoveredButton()

        function followHoveredButton() {
            const button = root.lastHoveredButton
            if (!previewPopup.hoveredHasPreview || !root.QsWindow)
                return
            previewPopup.shownButton = button
            previewPopup.cachedCenter = root.popupCenterForButton(button)
        }

        // One window: a header carries the app name, window title and close button,
        // and the tile drops its own title row.
        readonly property bool mergedHeader: appTopLevel?.toplevels?.length === 1

        property bool shouldShow: (popupMouseArea.containsMouse || root.buttonHovered)
                                  && !root._dragging
                                  && !(root.contextMenu?.isOpen ?? false)
                                  && hoveredHasPreview

        property bool show: false
        property real cachedCenter: 0
        readonly property real shiftX: DockStyle.position === "left" ? -12 : DockStyle.position === "right" ? 12 : 0
        readonly property real shiftY: DockStyle.vertical ? 0 : 12

        Connections {
            target: root
            function onLastHoveredButtonChanged() {
                previewPopup.followHoveredButton()
            }
            function onButtonHoveredChanged() {
                if (root.buttonHovered)
                    previewPopup.followHoveredButton()
                updateTimer.restart()
            }
        }

        onShouldShowChanged: {
            updateTimer.restart()
        }

        onShowChanged: {
            if (show) {
                closeAnim.stop()
                openAnim.restart()
            } else if (root.buttonHovered) {
                // Pointer moved to another dock icon (one with no preview, which
                // shows its tooltip instead): drop the card at once rather than
                // fading it over the new tooltip.
                openAnim.stop()
                closeAnim.stop()
                body.opacity = 0
            } else {
                openAnim.stop()
                closeAnim.restart()
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: bodyScale
                properties: "xScale,yScale"
                from: 0.85
                to: 1
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: bodyShift
                property: "x"
                from: previewPopup.shiftX
                to: 0
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: bodyShift
                property: "y"
                from: previewPopup.shiftY
                to: 0
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: body
                property: "opacity"
                to: 1
                duration: 130
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: bodyScale
                properties: "xScale,yScale"
                to: 0.9
                duration: 110
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: bodyShift
                property: "x"
                to: previewPopup.shiftX * 0.6
                duration: 110
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: bodyShift
                property: "y"
                to: previewPopup.shiftY * 0.6
                duration: 110
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: body
                property: "opacity"
                to: 0
                duration: 90
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
        }

        Timer {
            id: updateTimer
            interval: previewPopup.shouldShow ? 100 : 30
            onTriggered: {
                previewPopup.show = previewPopup.shouldShow
            }
        }

        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.None
            gravity: DockStyle.position === "left" ? (Edges.Bottom | Edges.Right)
                : DockStyle.position === "right" ? (Edges.Bottom | Edges.Left)
                : (Edges.Top | Edges.Right)
            edges: Edges.Top | Edges.Left
            // The card has an elevation margin around it, so shift by that to put
            // its visible edge on DockStyle.popupSideEdge / popupBottomEdge.
            rect.x: DockStyle.vertical
                ? DockStyle.popupSideEdge(root.QsWindow.window?.width ?? 0)
                    + (DockStyle.position === "left" ? -1 : 1) * Appearance.sizes.elevationMargin
                : 0
            rect.y: DockStyle.vertical ? 0 : DockStyle.popupBottomEdge + Appearance.sizes.elevationMargin
        }

        visible: body.opacity > 0
        // Only the card (plus the gap down to the dock) takes input. The popup
        // surface is larger than the card and overlaps the dock's edge, so
        // without this it would steal hover from neighbouring dock icons.
        mask: Region {
            item: popupBackground
            Region { item: gapBridge }
        }
        color: "transparent"
        implicitWidth: DockStyle.vertical ? popupMouseArea.implicitWidth : (root.QsWindow.window?.width ?? 1)
        implicitHeight: DockStyle.vertical
            ? (root.QsWindow.window?.height ?? 1)
            : popupMouseArea.implicitHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2

        MouseArea {
            id: popupMouseArea
            anchors.bottom: DockStyle.vertical ? undefined : parent.bottom
            anchors.left: DockStyle.position === "left" ? parent.left : undefined
            anchors.right: DockStyle.position === "right" ? parent.right : undefined
            implicitWidth:  popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: DockStyle.vertical
                ? popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2
                : root.maxWindowPreviewHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2
            hoverEnabled: true
            x: DockStyle.vertical ? 0 : previewPopup.cachedCenter - width / 2
            y: DockStyle.vertical
                ? Math.max(0, Math.min((root.QsWindow.window?.height ?? 0) - height, previewPopup.cachedCenter - height / 2))
                : 0

            Item {
                id: body
                anchors.fill: parent
                opacity: 0
                transform: [
                    Scale {
                        id: bodyScale
                        origin.x: DockStyle.position === "left" ? Appearance.sizes.elevationMargin
                            : DockStyle.position === "right" ? body.width - Appearance.sizes.elevationMargin
                            : body.width / 2
                        origin.y: DockStyle.vertical ? body.height / 2 : body.height - Appearance.sizes.elevationMargin
                        xScale: 0.85
                        yScale: 0.85
                    },
                    Translate {
                        id: bodyShift
                    }
                ]

                // Covers the gap between the card and the dock, so moving the
                // pointer from the icon to the card keeps the preview open.
                Item {
                    id: gapBridge
                    readonly property real size: DockStyle.popupGap + 2
                    x: DockStyle.position === "left" ? popupBackground.x - size
                        : DockStyle.position === "right" ? popupBackground.x + popupBackground.width
                        : popupBackground.x
                    y: DockStyle.vertical ? popupBackground.y : popupBackground.y + popupBackground.height
                    width: DockStyle.vertical ? size : popupBackground.width
                    height: DockStyle.vertical ? popupBackground.height : size
                }

                StyledRectangularShadow {
                    target: popupBackground
                }

                Rectangle {
                    id: popupBackground
                    WindowGlass {
                        anchors.fill: parent
                        glassEnabled: (parent?.color.a ?? 0) > 0
                        cardRadius: parent?.radius ?? 0
                        tint: parent?.color ?? 'transparent'
                    }
                    property real padding: 5
                    clip: true
                    color: DockStyle.popupColor
                    border.width: 1
                    border.color: DockStyle.popupBorderColor
                    radius: Appearance.rounding.normal
                    anchors.bottom: DockStyle.vertical ? undefined : parent.bottom
                    anchors.bottomMargin: Appearance.sizes.elevationMargin
                    anchors.horizontalCenter: DockStyle.vertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: DockStyle.vertical ? parent.verticalCenter : undefined
                    anchors.left: DockStyle.position === "left" ? parent.left : undefined
                    anchors.right: DockStyle.position === "right" ? parent.right : undefined
                    anchors.leftMargin: Appearance.sizes.elevationMargin
                    anchors.rightMargin: Appearance.sizes.elevationMargin
                    implicitHeight: previewColumn.implicitHeight + padding * 2
                    implicitWidth:  previewColumn.implicitWidth  + padding * 2
                    Behavior on implicitWidth {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on implicitHeight {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    ColumnLayout {
                        id: previewColumn
                        anchors.centerIn: parent
                        spacing: 0

                        RowLayout {
                            id: previewHeader
                            // Only for a single window, where it replaces the tile's title row.
                            // With several windows the hovered icon and the tile titles say enough.
                            visible: previewPopup.mergedHeader
                            Layout.fillWidth: true
                            // Takes the place of the tile's title row, so the popup height is unchanged.
                            Layout.preferredHeight: root.windowControlsHeight
                            Layout.leftMargin: 5
                            spacing: 6

                            IconImage {
                                implicitSize: 16
                                // Guarded so the icon lookup only runs when the header is shown.
                                source: previewPopup.mergedHeader
                                    ? SystemAppearance.iconPath(AppSearch.guessIcon(previewPopup.appTopLevel.appId), "image-missing")
                                    : ""
                            }

                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                text: previewPopup.shownButton?.desktopEntry?.name || (previewPopup.appTopLevel?.appId ?? "")
                                color: DockStyle.popupTextColor
                            }

                            StyledText {
                                // Width 0 so a long window title never widens the card; it elides instead.
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: "— " + (previewPopup.appTopLevel?.toplevels[0]?.title ?? "")
                                elide: Text.ElideRight
                                color: DockStyle.popupSubtextColor
                            }

                            DockPreviewCloseButton {
                                size: root.windowControlsHeight
                                onClicked: previewPopup.appTopLevel?.toplevels[0]?.close()
                            }
                        }

                        RowLayout {
                            id: previewRowLayout

                            Repeater {
                                model: ScriptModel {
                                    values: WM.compositor === "hyprland" ? (previewPopup.appTopLevel?.toplevels ?? []) : []
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
                                            visible: !previewPopup.mergedHeader
                                            contentWidth: parent.width - anchors.margins * 2

                                            StyledText {
                                                Layout.margins: 5
                                                Layout.fillWidth: true
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                text: windowButton.modelData?.title
                                                elide: Text.ElideRight
                                                color: DockStyle.popupTextColor
                                            }

                                            DockPreviewCloseButton {
                                                size: root.windowControlsHeight
                                                onClicked: windowButton.modelData?.close()
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            implicitHeight: screencopyView.height
                                            implicitWidth:  screencopyView.width

                                            SmoothScreencopyView {
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

                                            // Ring on the app's focused window, so scrolling on the
                                            // icon shows which window is now active.
                                            Rectangle {
                                                anchors.fill: screencopyView
                                                anchors.margins: -3
                                                radius: Appearance.rounding.small + 3
                                                color: "transparent"
                                                border.width: 2
                                                border.color: Appearance.colors.colPrimary
                                                opacity: windowButton.modelData?.activated ? 1 : 0
                                                Behavior on opacity {
                                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
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
}
