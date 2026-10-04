import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ContentSubsection {
    id: root

    property string sectionTitle
    property var layout: []
    property var getWidgetName: (id) => id
    property var availableWidgets: []
    property var onUpdate: (list) => {}
    signal widgetContextRequested(string widgetId)
    property var modeWidgets: []
    property var dynamicHoverModeWidgets: []
    property var widgetModes: ({})
    property var onModeChanged: (widget, mode) => {}
    property var rightAnchoredWidgets: []
    property var onAnchorsUpdate: (list) => {}

    property bool dragging: false
    property string draggingWidget: ""
    property point dragScenePoint: Qt.point(-1, -1)

    readonly property var leftWidgets:
        root.layout.filter(name => !root.rightAnchoredWidgets.includes(name))
    readonly property var rightWidgets:
        root.layout.filter(name => root.rightAnchoredWidgets.includes(name))

    title: sectionTitle
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.topMargin: -4

    function applyGroups(left, right) {
        root.onAnchorsUpdate(right.slice())
        root.onUpdate(left.concat(right))
    }

    function sourceIndex(sourceRight, displayIndex, listLength) {
        return sourceRight ? listLength - 1 - displayIndex : displayIndex
    }

    function removeWidget(widget, sourceRight, displayIndex) {
        const left = root.leftWidgets.slice()
        const right = root.rightWidgets.slice()
        const source = sourceRight ? right : left
        const index = root.sourceIndex(sourceRight, displayIndex, source.length)
        if (index >= 0 && index < source.length) source.splice(index, 1)
        root.applyGroups(left, right)
    }

    function addWidget(widget, anchorRight) {
        const left = root.leftWidgets.slice()
        const right = root.rightWidgets.slice()
        if (anchorRight) right.push(widget)
        else left.push(widget)
        root.applyGroups(left, right)
    }

    function moveWidget(widget, sourceRight, sourceDisplayIndex, scenePoint) {
        let target = null
        if (leftAnchorGroup.containsScene(scenePoint))
            target = leftAnchorGroup
        else if (rightAnchorGroup.containsScene(scenePoint))
            target = rightAnchorGroup
        if (!target) return

        const left = root.leftWidgets.slice()
        const right = root.rightWidgets.slice()
        const source = sourceRight ? right : left
        const oldIndex = root.sourceIndex(sourceRight, sourceDisplayIndex, source.length)
        if (oldIndex >= 0 && oldIndex < source.length) source.splice(oldIndex, 1)

        let displayList = target.anchorRight ? right.slice().reverse() : left.slice()
        const excludedIndex = sourceRight === target.anchorRight ? sourceDisplayIndex : -1
        const displayIndex = target.insertionIndex(scenePoint, excludedIndex)
        displayList.splice(Math.max(0, Math.min(displayIndex, displayList.length)), 0, widget)

        if (target.anchorRight)
            root.applyGroups(left, displayList.reverse())
        else
            root.applyGroups(displayList, right)
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        AnchorGroup {
            id: leftAnchorGroup
            anchorRight: false
            widgets: root.leftWidgets
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.45
        }

        AnchorGroup {
            id: rightAnchorGroup
            anchorRight: true
            widgets: root.rightWidgets
        }
    }

    component AnchorGroup: Rectangle {
        id: anchorGroup
        required property bool anchorRight
        required property var widgets

        Layout.fillWidth: true
        implicitHeight: groupColumn.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: root.dragging && containsScene(root.dragScenePoint)
            ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1

        Behavior on color { ColorAnimation { duration: 120 } }

        function containsScene(scenePoint) {
            const local = anchorGroup.mapFromItem(null, scenePoint.x, scenePoint.y)
            return local.x >= 0 && local.x <= width && local.y >= 0 && local.y <= height
        }

        function displayWidgets() {
            return anchorRight ? widgets.slice().reverse() : widgets
        }

        function insertionIndex(scenePoint, excludedIndex) {
            const candidates = []
            for (let i = 0; i < chipRepeater.count; i++) {
                const chip = chipRepeater.itemAt(i)
                if (!chip || i === excludedIndex) continue
                const center = chip.mapToItem(null, chip.width / 2, chip.height / 2)
                candidates.push({ chip: chip, center: center })
            }
            if (candidates.length === 0) return 0

            let nearest = 0
            let nearestDistance = Infinity
            for (let i = 0; i < candidates.length; i++) {
                const dx = scenePoint.x - candidates[i].center.x
                const dy = scenePoint.y - candidates[i].center.y
                const distance = Math.sqrt(dx * dx + dy * dy)
                if (distance < nearestDistance) {
                    nearestDistance = distance
                    nearest = i
                }
            }

            const center = candidates[nearest].center
            const after = anchorRight
                ? scenePoint.x < center.x
                : scenePoint.x > center.x
            return nearest + (after ? 1 : 0)
        }

        ColumnLayout {
            id: groupColumn
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: anchorGroup.anchorRight ? "format_align_right" : "format_align_left"
                    iconSize: 18
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: anchorGroup.anchorRight
                        ? Translation.tr("Anchored to the right")
                        : Translation.tr("Anchored to the left")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                ToolbarPairedFab {
                    iconText: addArea.dropdownOpen ? "keyboard_arrow_up" : "add"
                    onClicked: addArea.dropdownOpen = !addArea.dropdownOpen
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Math.max(chipFlow.implicitHeight, emptyLabel.implicitHeight)

                Flow {
                    id: chipFlow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    spacing: 3
                    layoutDirection: anchorGroup.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

                    Repeater {
                        id: chipRepeater
                        model: anchorGroup.displayWidgets()

                        delegate: WidgetChip {
                            required property var modelData
                            required property int index
                            widget: modelData
                            sourceRight: anchorGroup.anchorRight
                            sourceDisplayIndex: index
                        }
                    }
                }

                StyledText {
                    id: emptyLabel
                    visible: anchorGroup.widgets.length === 0
                    anchors {
                        left: anchorGroup.anchorRight ? undefined : parent.left
                        right: anchorGroup.anchorRight ? parent.right : undefined
                    }
                    text: Translation.tr("Drag components here")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    opacity: 0.7
                }
            }

            Item {
                id: addArea
                property bool dropdownOpen: false
                Layout.fillWidth: true
                clip: true
                implicitHeight: dropdownOpen ? addFlow.implicitHeight + 8 : 0
                visible: implicitHeight > 0
                opacity: dropdownOpen ? 1 : 0

                Behavior on implicitHeight {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Flow {
                    id: addFlow
                    anchors {
                        fill: parent
                        margins: 4
                    }
                    spacing: 3
                    layoutDirection: anchorGroup.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

                    Repeater {
                        model: root.availableWidgets
                        delegate: SelectionGroupButton {
                            required property var modelData
                            leftmost: true
                            rightmost: true
                            buttonText: modelData.name
                            buttonIcon: modelData.icon ?? ""
                            onClicked: {
                                root.addWidget(modelData.id, anchorGroup.anchorRight)
                                const keepOpen = ["visualizer", "divisor"]
                                if (!keepOpen.includes(modelData.id))
                                    Qt.callLater(() => { addArea.dropdownOpen = false })
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

    component WidgetChip: Rectangle {
        id: widgetChip
        required property string widget
        required property bool sourceRight
        required property int sourceDisplayIndex
        readonly property bool hasModes: root.modeWidgets.includes(widget)
        readonly property bool hasDynamicHoverMode:
            root.dynamicHoverModeWidgets.includes(widget)

        implicitWidth: chipContent.implicitWidth + (hasModes ? 6 : 0)
        implicitHeight: chipContent.implicitHeight
        radius: height / 2
        color: hasModes ? Appearance.colors.colPrimary : "transparent"
        opacity: dragHandler.active ? 0.65 : 1

        Behavior on opacity { NumberAnimation { duration: 100 } }

        RowLayout {
            id: chipContent
            anchors.fill: parent
            anchors.rightMargin: widgetChip.hasModes ? 6 : 0
            spacing: 0

            SelectionGroupButton {
                isDragging: dragHandler.active
                colBackgroundToggled: widgetChip.hasModes
                    ? "transparent" : Appearance.colors.colPrimary
                leftmost: true
                rightmost: true
                buttonIcon: "close"
                buttonText: root.getWidgetName(widgetChip.widget)
                altAction: () => root.widgetContextRequested(widgetChip.widget)
                toggled: !dragHandler.active

                DragHandler {
                    id: dragHandler
                    target: null

                    onActiveChanged: {
                        root.dragging = active
                        root.draggingWidget = active ? widgetChip.widget : ""
                        if (!active) {
                            root.moveWidget(widgetChip.widget, widgetChip.sourceRight,
                                widgetChip.sourceDisplayIndex, dragHandler.centroid.scenePosition)
                            root.dragScenePoint = Qt.point(-1, -1)
                        }
                    }

                    onCentroidChanged: {
                        if (active)
                            root.dragScenePoint = centroid.scenePosition
                    }
                }

                onClicked: root.removeWidget(widgetChip.widget, widgetChip.sourceRight, widgetChip.sourceDisplayIndex)
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
                        colText: toggled
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnPrimary
                        leftmost: true
                        rightmost: true
                        toggled: (root.widgetModes[widgetChip.widget] ?? "dynamic")
                            === modelData.mode
                        onClicked: root.onModeChanged(widgetChip.widget, modelData.mode)

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
