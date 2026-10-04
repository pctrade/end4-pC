import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ContentSubsection {
    id: root

    property string sectionTitle
    property var layout
    property var getWidgetName: (id) => id
    property var availableWidgets: []
    property var onUpdate: (list) => {}
    property var modeWidgets: []
    property var dynamicHoverModeWidgets: []
    property var widgetModes: ({})
    property var onModeChanged: (widget, mode) => {}
    property bool centerItems: false
    property bool anchorControls: false
    property var rightAnchoredWidgets: []
    property var onAnchorChanged: (widget, anchor) => {}
    signal widgetContextRequested(string widgetId)

    property bool liveReflow: false
    property bool reflowAnimate: true
    property int reflowTarget: -1
    property var slotOffsets: []
    property var draggedSlot: null

    function computeReflow(draggedIndex, targetIndex) {
        const count = itemRepeater.count
        const order = []
        for (let k = 0; k < count; k++) if (k !== draggedIndex) order.push(k)
        order.splice(targetIndex, 0, draggedIndex)

        const flowWidth = itemFlow.width
        const gap = itemFlow.spacing
        const slots = new Array(count)
        let x = 0
        let y = 0
        let rowHeight = 0
        for (const k of order) {
            const chip = itemRepeater.itemAt(k)
            if (!chip) continue
            if (x > 0 && x + chip.width > flowWidth) {
                x = 0
                y += rowHeight + gap
                rowHeight = 0
            }
            slots[k] = { x: x, y: y }
            x += chip.width + gap
            rowHeight = Math.max(rowHeight, chip.height)
        }

        const offsets = []
        for (let k = 0; k < count; k++) {
            const chip = itemRepeater.itemAt(k)
            offsets.push(chip && slots[k] ? { x: slots[k].x - chip.x, y: slots[k].y - chip.y } : { x: 0, y: 0 })
        }
        root.slotOffsets = offsets
        root.draggedSlot = slots[draggedIndex] ?? null
    }

    title: sectionTitle
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.topMargin: -4

    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        Item {
            Layout.fillWidth: true
            implicitHeight: itemFlow.implicitHeight

            Flow {
                id: itemFlow
                anchors.fill: root.centerItems ? undefined : parent
                anchors.horizontalCenter: root.centerItems ? parent.horizontalCenter : undefined
                width: root.centerItems ? implicitWidth : parent.width
                spacing: 2

                Repeater {
                    id: itemRepeater
                    model: root.layout

                    delegate: Rectangle {
                        id: widgetChip
                        required property var modelData
                        required property int index
                        readonly property bool hasModes: root.modeWidgets.includes(modelData)
                        readonly property bool hasDynamicHoverMode: root.dynamicHoverModeWidgets.includes(modelData)
                        readonly property bool hasControls: hasModes || root.anchorControls
                        implicitWidth: chipContent.implicitWidth + (hasControls ? 6 : 0)
                        implicitHeight: chipContent.implicitHeight
                        radius: height / 2
                        color: hasControls ? Appearance.colors.colPrimary : "transparent"

                        property real dragOffsetX: 0
                        property real dragOffsetY: 0
                        property real displaceX: root.liveReflow && !dragHandler.active ? (root.slotOffsets[index]?.x ?? 0) : 0
                        property real displaceY: root.liveReflow && !dragHandler.active ? (root.slotOffsets[index]?.y ?? 0) : 0

                        Behavior on displaceX {
                            enabled: root.reflowAnimate
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on displaceY {
                            enabled: root.reflowAnimate
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        property bool settlePending: false
                        property point settleScenePos: Qt.point(0, 0)

                        transform: Translate { x: widgetChip.dragOffsetX + widgetChip.displaceX; y: widgetChip.dragOffsetY + widgetChip.displaceY }
                        z: (dragHandler.active || settleAnim.running) ? 100 : 0

                        ParallelAnimation {
                            id: settleAnim
                            NumberAnimation { target: widgetChip; property: "dragOffsetX"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { target: widgetChip; property: "dragOffsetY"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                        }

                        function startSettle(scenePos) {
                            widgetChip.settleScenePos = scenePos
                            widgetChip.settlePending = true
                            settleFallback.restart()
                        }

                        function applySettle() {
                            if (!widgetChip.settlePending) return
                            widgetChip.settlePending = false
                            const nowScene = widgetChip.mapToItem(null, 0, 0)
                            widgetChip.dragOffsetX = widgetChip.settleScenePos.x - (nowScene.x - widgetChip.dragOffsetX)
                            widgetChip.dragOffsetY = widgetChip.settleScenePos.y - (nowScene.y - widgetChip.dragOffsetY)
                            settleAnim.restart()
                        }

                        onXChanged: widgetChip.applySettle()
                        onYChanged: widgetChip.applySettle()

                        Timer {
                            id: settleFallback
                            interval: 60
                            onTriggered: widgetChip.applySettle()
                        }

                        Rectangle {
                            visible: dragHandler.active
                            anchors.fill: parent
                            anchors.margins: -3
                            z: 5
                            radius: widgetChip.height / 2 + 3
                            color: "transparent"
                            border.width: 2
                            border.color: Appearance.colors.colPrimary
                        }

                        DragHandler {
                            id: dragHandler
                            target: null

                            function findNewIndex(dragX, dragY) {
                                let newIndex = index
                                let minDist = Infinity

                                for (let i = 0; i < itemRepeater.count; i++) {
                                    if (i === index) continue
                                    const child = itemRepeater.itemAt(i)
                                    if (!child) continue
                                    const childCenter = itemFlow.mapToItem(null, child.x + child.width / 2, child.y + child.height / 2)
                                    const dx = dragX - childCenter.x
                                    const dy = dragY - childCenter.y
                                    const dist = Math.sqrt(dx * dx + dy * dy)
                                    if (dist < minDist) {
                                        minDist = dist
                                        newIndex = i
                                    }
                                }
                                return newIndex
                            }

                            onActiveChanged: {
                                if (active) {
                                    settleAnim.stop()
                                    widgetChip.settlePending = false
                                    root.reflowTarget = index
                                    root.slotOffsets = []
                                    root.draggedSlot = null
                                    root.liveReflow = true
                                    return
                                }

                                root.reflowAnimate = false
                                root.liveReflow = false
                                Qt.callLater(() => { root.reflowAnimate = true })
                                dropIndicator.visible = false
                                dropIndicator.targetIndex = -1
                                const dragX = dragHandler.centroid.scenePosition.x
                                const dragY = dragHandler.centroid.scenePosition.y
                                const newIndex = findNewIndex(dragX, dragY)
                                if (newIndex === index) {
                                    settleAnim.restart()
                                    return
                                }

                                const sceneBefore = widgetChip.mapToItem(null, 0, 0)
                                widgetChip.dragOffsetX = 0
                                widgetChip.dragOffsetY = 0
                                let list = root.layout.slice()
                                const item = list.splice(index, 1)[0]
                                list.splice(newIndex, 0, item)
                                root.onUpdate(list)
                                itemRepeater.itemAt(newIndex)?.startSettle(sceneBefore)
                            }

                            onCentroidChanged: {
                                if (!active) return
                                widgetChip.dragOffsetX = centroid.scenePosition.x - centroid.scenePressPosition.x
                                widgetChip.dragOffsetY = centroid.scenePosition.y - centroid.scenePressPosition.y

                                const newIndex = findNewIndex(centroid.scenePosition.x, centroid.scenePosition.y)
                                if (newIndex !== root.reflowTarget || !root.draggedSlot) {
                                    root.reflowTarget = newIndex
                                    root.computeReflow(index, newIndex)
                                }
                                const slot = root.draggedSlot
                                if (slot) {
                                    dropIndicator.width = widgetChip.width
                                    dropIndicator.height = widgetChip.height
                                    dropIndicator.x = slot.x
                                    dropIndicator.y = slot.y
                                    dropIndicator.visible = true
                                    dropIndicator.targetIndex = newIndex
                                } else {
                                    dropIndicator.visible = false
                                    dropIndicator.targetIndex = -1
                                }
                            }
                        }

                        RowLayout {
                            id: chipContent
                            anchors.fill: parent
                            anchors.rightMargin: widgetChip.hasControls ? 6 : 0
                            spacing: 0

                            SelectionGroupButton {
                                isDragging: dragHandler.active
                                colBackgroundToggled: widgetChip.hasControls ? "transparent" : Appearance.colors.colPrimary
                                leftmost: true; rightmost: true
                                buttonIcon: "close"
                                buttonText: root.getWidgetName(modelData)
                                altAction: () => root.widgetContextRequested(modelData)
                                toggled: !dragHandler.active


                                onClicked: {
                                    let list = root.layout.slice()
                                    list.splice(index, 1)
                                    root.onUpdate(list)
                                }
                            }
                            RowLayout {
                                visible: widgetChip.hasModes
                                spacing: 1
                                Repeater {
                                    model: widgetChip.hasDynamicHoverMode ? [
                                        { label: "D", mode: "dynamic", title: Translation.tr("Dynamic: expand with Dynamic Island") },
                                        { label: "DH", mode: "dynamicHover", title: Translation.tr("Dynamic hover: expand when hovering the component") },
                                        { label: "C", mode: "compact", title: Translation.tr("Always compact") },
                                        { label: "E", mode: "expanded", title: Translation.tr("Always expanded") }
                                    ] : [
                                        { label: "D", mode: "dynamic", title: Translation.tr("Dynamic: expand on hover") },
                                        { label: "C", mode: "compact", title: Translation.tr("Always compact") },
                                        { label: "E", mode: "expanded", title: Translation.tr("Always expanded") }
                                    ]
                                    delegate: SelectionGroupButton {
                                        required property var modelData
                                        buttonText: modelData.label
                                        contentItem: StyledText {
                                            text: parent.buttonText
                                            color: parent.colText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        horizontalPadding: 0
                                        verticalPadding: 0
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.minimumWidth: 26
                                        Layout.maximumWidth: 26
                                        Layout.minimumHeight: 26
                                        Layout.maximumHeight: 26
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: false
                                        Layout.fillHeight: false
                                        leftRadius: 13
                                        rightRadius: 13
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colPrimaryHover
                                        colBackgroundActive: Appearance.colors.colPrimaryActive
                                        colBackgroundToggled: Appearance.colors.colOnPrimary
                                        colBackgroundToggledHover: Appearance.colors.colOnPrimary
                                        colBackgroundToggledActive: Appearance.colors.colOnPrimary
                                        colText: toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimary
                                        leftmost: true
                                        rightmost: true
                                        toggled: (root.widgetModes[widgetChip.modelData] ?? "dynamic") === modelData.mode
                                        onClicked: root.onModeChanged(widgetChip.modelData, modelData.mode)
                                        StyledToolTip {
                                            text: parent.modelData.title
                                            delay: 400
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                visible: root.anchorControls
                                Layout.leftMargin: 3
                                Layout.rightMargin: 3
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 1
                                implicitHeight: 16
                                radius: 1
                                color: Appearance.colors.colOnPrimary
                                opacity: 0.35
                            }
                            RowLayout {
                                visible: root.anchorControls
                                spacing: 1
                                Repeater {
                                    model: [
                                        { label: "L", anchor: "left", title: Translation.tr("Anchor to the left edge") },
                                        { label: "R", anchor: "right", title: Translation.tr("Anchor to the right edge") }
                                    ]
                                    delegate: SelectionGroupButton {
                                        required property var modelData
                                        buttonText: modelData.label
                                        contentItem: StyledText {
                                            text: parent.buttonText
                                            color: parent.colText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        horizontalPadding: 0
                                        verticalPadding: 0
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.minimumWidth: 26
                                        Layout.maximumWidth: 26
                                        Layout.minimumHeight: 26
                                        Layout.maximumHeight: 26
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: false
                                        Layout.fillHeight: false
                                        leftRadius: 13
                                        rightRadius: 13
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colPrimaryHover
                                        colBackgroundActive: Appearance.colors.colPrimaryActive
                                        colBackgroundToggled: Appearance.colors.colOnPrimary
                                        colBackgroundToggledHover: Appearance.colors.colOnPrimary
                                        colBackgroundToggledActive: Appearance.colors.colOnPrimary
                                        colText: toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimary
                                        leftmost: true
                                        rightmost: true
                                        toggled: modelData.anchor === "right"
                                            ? root.rightAnchoredWidgets.includes(widgetChip.modelData)
                                            : !root.rightAnchoredWidgets.includes(widgetChip.modelData)
                                        onClicked: root.onAnchorChanged(widgetChip.modelData, modelData.anchor)
                                        StyledToolTip {
                                            text: parent.modelData.title
                                            delay: 400
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: dropIndicator
                property int targetIndex: -1
                visible: false
                z: 99
                radius: height / 2
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                border.width: 2
                border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        ToolbarPairedFab {
            visible: !root.centerItems || root.layout.length === 0
            Layout.rightMargin: 8
            Layout.topMargin: -20
            Layout.alignment: Qt.AlignVCenter
            iconText: dropdown.dropdownOpen ? "keyboard_arrow_up" : "add"
            onClicked: dropdown.dropdownOpen = !dropdown.dropdownOpen
        }
    }

    Item {
        id: dropdown
        Layout.fillWidth: true
        Layout.topMargin: 5
        clip: true
        implicitHeight: dropdownOpen ? dropdownRect.implicitHeight + 8 : 0
        visible: implicitHeight > 0
        opacity: dropdownOpen ? 1 : 0

        property bool dropdownOpen: false

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: dropdownRect
            anchors.top: parent.top
            anchors.topMargin: 4
            width: parent.width
            implicitHeight: dropdownFlow.implicitHeight + 8
            color: "transparent"
            radius: Appearance.rounding.large

            Flow {
                id: dropdownFlow
                anchors { fill: parent; margins: 8 }
                spacing: 2
                Repeater {
                    model: root.availableWidgets
                    delegate: SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: modelData.name
                        buttonIcon: modelData.icon ?? ""  
                        onClicked: {
                            let list = root.layout.slice()
                            list.push(modelData.id)
                            root.onUpdate(list)
                            const keepOpen = ["visualizer", "divisor"]
                            if (!keepOpen.includes(modelData.id)) {
                                Qt.callLater(() => { dropdown.dropdownOpen = false })
                            }
                        }
                    }
                }
                StyledText {
                    visible: root.availableWidgets.length === 0
                    text: Translation.tr("No widgets available")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
