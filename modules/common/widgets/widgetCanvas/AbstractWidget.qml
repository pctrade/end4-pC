import QtQuick
import Quickshell
import qs.modules.common

/*
 * Widget to be placed on a WidgetCanvas
 */
MouseArea {
    id: root
    property alias animateXPos: xBehavior.enabled
    property alias animateYPos: yBehavior.enabled
    property bool draggable: true
    property int gridSize: 12
    property bool snapEnabled: true
    readonly property bool dragging: drag.active
    property bool showSelectionBorder: true
    property bool pinnedBottom: false

    property bool selected: false
    property bool groupDragActive: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    drag.target: draggable ? dragProxy : undefined
    cursorShape: (draggable && containsPress) ? Qt.ClosedHandCursor : draggable ? Qt.OpenHandCursor : Qt.ArrowCursor

    onPressed: (mouse) => {
        if (mouse.button !== Qt.LeftButton) return
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.bringToFront(root)
    }

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
        } else if (mouse.modifiers & Qt.ControlModifier) {
            root.selected = !root.selected
        } else {
            var canvas = findCanvas(root.parent)
            if (canvas) canvas.clearSelection()
            root.selected = true
        }
    }

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    function snap(value) {
        return Math.round(value / root.gridSize) * root.gridSize
    }

    function findCanvas(item) {
        var p = item
        while (p) {
            if (p.isWidgetCanvas === true) return p
            p = p.parent
        }
        return null
    }

    function updateCenterHighlight() {
        var canvas = findCanvas(root.parent)
        if (!canvas) return
        var widgetCenterX = dragProxy.x + root.width / 2
        var widgetCenterY = dragProxy.y + root.height / 2
        var threshold = root.gridSize
        var nearX = Math.abs(widgetCenterX - canvas.width / 2) < threshold
        var nearY = Math.abs(widgetCenterY - canvas.height / 2) < threshold
        canvas.setCenterActive(nearX, nearY)
    }

    function commitPosition() {}

    Component.onCompleted: { var canvas = findCanvas(root.parent); if (canvas) canvas.registerWidget(root) }

    Component.onDestruction: {
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.unregisterWidget(root)
    }

    Item {
        id: dragProxy
        parent: root.parent
        x: root.x
        y: root.y

        onXChanged: if (root.dragging) root.updateCenterHighlight()
        onYChanged: if (root.dragging) root.updateCenterHighlight()
    }

    Binding {
        target: root
        property: "x"
        value: root.snapEnabled ? root.snap(dragProxy.x) : dragProxy.x
        when: root.dragging
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "y"
        value: root.snapEnabled ? root.snap(dragProxy.y) : dragProxy.y
        when: root.dragging
        restoreMode: Binding.RestoreNone
    }

    onXChanged: {
        if (!root.dragging) return
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.updateGroupDrag(root)
    }
    onYChanged: {
        if (!root.dragging) return
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.updateGroupDrag(root)
    }

    onDraggingChanged: {
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.setDragging(dragging)

        if (dragging) {
            if (canvas) canvas.beginGroupDrag(root)
        } else {
            if (canvas) canvas.endGroupDrag()

            var left = root.x
            var right = root.x + root.width
            var top = root.y
            var bottom = root.y + root.height
            var verticalLines = [left, right]
            var horizontalLines = [top, bottom]

            var widgetCenterX = root.x + root.width / 2
            var widgetCenterY = root.y + root.height / 2
            if (canvas && Math.abs(widgetCenterX - canvas.width / 2) < root.gridSize / 2)
                verticalLines.push(canvas.width / 2)
            if (canvas && Math.abs(widgetCenterY - canvas.height / 2) < root.gridSize / 2)
                horizontalLines.push(canvas.height / 2)

            if (canvas && Config.options.background.showSnapLines)
                canvas.flashLines(verticalLines, horizontalLines)
        }

        dragProxy.x = root.x
        dragProxy.y = root.y
    }

    Rectangle {
        anchors.fill: parent
        visible: root.selected && root.showSelectionBorder && !Config.options.background.widgetsLocked
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
        radius: Appearance.rounding?.verylarge ?? 30
        z: 9999
    }

    Behavior on x {
        id: xBehavior
        enabled: !root.dragging && !root.groupDragActive
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    Behavior on y {
        id: yBehavior
        enabled: !root.dragging && !root.groupDragActive
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
}