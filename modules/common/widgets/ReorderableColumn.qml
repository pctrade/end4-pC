// soon
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property var order: []
    property bool editMode: false
    property real itemSpacing: 10
    property color accentColor: Appearance.colors.colPrimary
    property real cornerRadius: Appearance.rounding?.normal ?? 12

    property string fillKey: ""
    property real fillMinHeight: 60

    signal reordered(var newOrder)
    property var componentForKey: function(key) { return null }

    property var workingOrder: order.slice()
    onOrderChanged: root.workingOrder = order.slice()

    property var heightMap: ({})

    function naturalHeight(key) {
        return root.heightMap[key] ?? 0
    }

    function effectiveHeight(key) {
        if (!root.editMode && key === root.fillKey && root.fillKey.length > 0) {
            let othersTotal = 0
            for (let i = 0; i < root.workingOrder.length; i++) {
                const k = root.workingOrder[i]
                if (k === root.fillKey) continue
                othersTotal += root.naturalHeight(k)
            }
            const spacingTotal = Math.max(0, root.workingOrder.length - 1) * root.itemSpacing
            const remaining = root.height - othersTotal - spacingTotal
            return Math.max(root.fillMinHeight, remaining)
        }
        return root.naturalHeight(key)
    }

    function yForKey(key) {
        let y = 0
        for (let i = 0; i < root.workingOrder.length; i++) {
            const k = root.workingOrder[i]
            if (k === key) break
            y += root.effectiveHeight(k) + root.itemSpacing
        }
        return y
    }

    Repeater {
        id: repeater
        model: root.order

        delegate: Item {
            id: slot
            required property string modelData
            required property int index

            width: root.width
            height: root.effectiveHeight(modelData)

            property real baseY: root.yForKey(modelData)
            property real pressY: 0
            y: dragArea.drag.active ? slot.pressY : slot.baseY
            z: dragArea.drag.active ? 100 : 0

            Behavior on y {
                enabled: !dragArea.drag.active
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                enabled: !dragArea.drag.active
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            function reportHeight() {
                let hm = Object.assign({}, root.heightMap)
                hm[slot.modelData] = loader.implicitHeight
                root.heightMap = hm
            }

            Item {
                id: dragSurface
                width: slot.width
                height: slot.height
                x: 0
                y: 0

                Loader {
                    id: loader
                    anchors.fill: parent
                    sourceComponent: root.componentForKey(slot.modelData)
                    onImplicitHeightChanged: slot.reportHeight()
                    Component.onCompleted: slot.reportHeight()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.cornerRadius
                    color: ColorUtils.transparentize(root.accentColor, 0.75)
                    visible: dragArea.drag.active
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.cornerRadius
                    color: "transparent"
                    border.width: 2
                    border.color: root.accentColor
                    visible: dragArea.drag.active
                }

                Loader {
                    active: dragArea.drag.active
                    sourceComponent: StyledRectangularShadow {
                        target: dragSurface
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: root.editMode
                    drag.target: dragSurface
                    drag.axis: Drag.YAxis
                    cursorShape: root.editMode ? Qt.SizeVerCursor : Qt.ArrowCursor

                    property real minY: 0
                    property real maxY: 0
                    drag.minimumY: minY
                    drag.maximumY: maxY

                    onPressed: {
                        slot.pressY = slot.y
                        dragArea.minY = -slot.pressY
                        dragArea.maxY = root.height - slot.pressY - slot.height
                    }

                    onPositionChanged: {
                        if (!drag.active) return
                        const currentIndex = root.workingOrder.indexOf(slot.modelData)
                        const centerY = slot.pressY + dragSurface.y + dragSurface.height / 2

                        let targetIndex = currentIndex
                        let accY = 0
                        for (let i = 0; i < root.workingOrder.length; i++) {
                            const k = root.workingOrder[i]
                            const h = root.effectiveHeight(k)
                            const itemMidY = accY + h / 2
                            if (centerY <= itemMidY) { targetIndex = i; break }
                            accY += h + root.itemSpacing
                            targetIndex = i + 1
                        }
                        targetIndex = Math.max(0, Math.min(root.workingOrder.length - 1, targetIndex))

                        if (targetIndex !== currentIndex) {
                            let newWorking = root.workingOrder.slice()
                            newWorking.splice(currentIndex, 1)
                            newWorking.splice(targetIndex, 0, slot.modelData)
                            root.workingOrder = newWorking
                        }
                    }

                    onReleased: {
                        dragSurface.x = 0
                        dragSurface.y = 0
                        root.order = root.workingOrder.slice()
                        root.reordered(root.order)
                    }
                }
            }
        }
    }
}