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
    // The WidgetCanvas this widget belongs to. Background widgets are
    // registered by whoever hosts them (e.g. WidgetsLoader), so they don't
    // need to be direct children of the canvas anymore.
    property Item canvas: null
    onCanvasChanged: { if (root.canvas) root.canvas.registerWidget(root) }

    property bool selected: false
    property bool groupDragActive: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    drag.target: draggable ? dragProxy : undefined
    cursorShape: (draggable && containsPress) ? Qt.ClosedHandCursor : draggable ? Qt.OpenHandCursor : Qt.ArrowCursor

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            root.handleContextMenu(mouse)
        } else if (mouse.modifiers & Qt.ControlModifier) {
            root.selected = !root.selected
        } else {
            if (root.canvas) root.canvas.clearSelection()
            root.selected = true
        }
    }

    // Default right-click behavior: toggle the global widget lock.
    // Subclasses (e.g. background widgets) override this to open a context menu.
    function handleContextMenu(mouse) {
        Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
    }

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    function snap(value) {
        return Math.round(value / root.gridSize) * root.gridSize
    }

    function updateCenterHighlight() {
        if (!root.canvas) return
        var canvas = root.canvas
        var widgetCenterX = dragProxy.x + root.width / 2
        var widgetCenterY = dragProxy.y + root.height / 2
        var threshold = root.gridSize
        var nearX = Math.abs(widgetCenterX - canvas.width / 2) < threshold
        var nearY = Math.abs(widgetCenterY - canvas.height / 2) < threshold
        canvas.setCenterActive(nearX, nearY)
    }

    function commitPosition() {}

    Component.onDestruction: {
        if (root.canvas) root.canvas.unregisterWidget(root)
    }

    // Sync dragProxy to widget position when press starts (before drag begins)
    onPressed: {
        dragProxy.x = root.x
        dragProxy.y = root.y
    }

    Item {
        id: dragProxy
        parent: root.canvas ?? root.parent
        x: root.x
        y: root.y

        onXChanged: if (root.dragging) root.updateCenterHighlight()
        onYChanged: if (root.dragging) root.updateCenterHighlight()
    }

    // RestoreNone strips the declarative x/y binding during drag;
    // commitPosition() → restoreXYBinding() re-establishes it after each drag.
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
        if (!root.dragging || !root.canvas) return
        root.canvas.updateGroupDrag(root)
    }
    onYChanged: {
        if (!root.dragging || !root.canvas) return
        root.canvas.updateGroupDrag(root)
    }

    onDraggingChanged: {
        var canvas = root.canvas
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

        // Sync dragProxy after drag ends so it's ready for next drag
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
