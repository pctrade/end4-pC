import QtQuick
import qs.modules.common

MouseArea {
    id: root
    property int gridSize: 24
    property bool showGrid: false
    readonly property bool isWidgetCanvas: true
    readonly property bool gridVisible: showGrid && Config.options.background.showGrid

    property bool centerXActive: false
    property bool centerYActive: false

    property var registeredWidgets: []
    property bool selecting: false
    property point selectionStartPoint: Qt.point(0, 0)
    property rect selectionRect: Qt.rect(0, 0, 0, 0)

    property var groupDragMemberStarts: []
    property real groupDragStartX: 0
    property real groupDragStartY: 0

    function setDragging(active) {
        root.showGrid = active
        if (!active) {
            root.centerXActive = false
            root.centerYActive = false
        }
    }

    function setCenterActive(xActive, yActive) {
        root.centerXActive = xActive
        root.centerYActive = yActive
    }

    function registerWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.concat([widget])
    }

    function unregisterWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.filter(w => w !== widget)
    }

    function bringToFront(widget) {
        if (widget.pinnedBottom) return
        let maxZ = 0
        for (const w of root.registeredWidgets) {
            if (w !== widget && !w.pinnedBottom && w.z > maxZ) maxZ = w.z
        }
        widget.z = maxZ + 1
    }

    function clearSelection() {
        for (const widget of root.registeredWidgets) widget.selected = false
    }

    function rectsIntersect(a, b) {
        return a.x < b.x + b.width && a.x + a.width > b.x
            && a.y < b.y + b.height && a.y + a.height > b.y
    }

    function selectWithinRect(rect) {
        for (const widget of root.registeredWidgets) {
            const widgetRect = Qt.rect(widget.x, widget.y, widget.width, widget.height)
            widget.selected = root.rectsIntersect(rect, widgetRect)
        }
    }

    function beginGroupDrag(initiator) {
        if (!initiator.selected) {
            root.groupDragMemberStarts = []
            return
        }
        root.groupDragStartX = initiator.x
        root.groupDragStartY = initiator.y
        root.groupDragMemberStarts = root.registeredWidgets
            .filter(w => w.selected && w !== initiator)
            .map(w => ({ widget: w, startX: w.x, startY: w.y }))
        for (const entry of root.groupDragMemberStarts) entry.widget.groupDragActive = true
    }

    function updateGroupDrag(initiator) {
        if (root.groupDragMemberStarts.length === 0) return
        const dx = initiator.x - root.groupDragStartX
        const dy = initiator.y - root.groupDragStartY
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.x = entry.startX + dx
            entry.widget.y = entry.startY + dy
        }
    }

    function endGroupDrag() {
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.groupDragActive = false
            entry.widget.commitPosition()
        }
        root.groupDragMemberStarts = []
    }

    onPressed: (mouse) => {
        if (Config.options.background.widgetsLocked) return
        root.selecting = true
        root.selectionStartPoint = Qt.point(mouse.x, mouse.y)
        root.selectionRect = Qt.rect(mouse.x, mouse.y, 0, 0)
        if (!(mouse.modifiers & Qt.ControlModifier)) root.clearSelection()
    }

    onPositionChanged: (mouse) => {
        if (!root.selecting) return
        const startX = root.selectionStartPoint.x
        const startY = root.selectionStartPoint.y
        const rectX = Math.min(startX, mouse.x)
        const rectY = Math.min(startY, mouse.y)
        const rectW = Math.abs(mouse.x - startX)
        const rectH = Math.abs(mouse.y - startY)
        root.selectionRect = Qt.rect(rectX, rectY, rectW, rectH)
        root.selectWithinRect(root.selectionRect)
    }

    onReleased: {
        root.selecting = false
    }

    Repeater {
        id: crossRepeater
        readonly property int cols: Math.ceil(root.width / root.gridSize) + 1
        readonly property int rows: Math.ceil(root.height / root.gridSize) + 1
        model: root.gridVisible ? cols * rows : 0
        delegate: Item {
            id: crossPoint
            required property int index
            readonly property int col: index % crossRepeater.cols
            readonly property int row: Math.floor(index / crossRepeater.cols)
            readonly property int crossSize: 5

            x: col * root.gridSize - crossSize / 2
            y: row * root.gridSize - crossSize / 2
            width: crossSize
            height: crossSize

            Rectangle {
                anchors.centerIn: parent
                width: crossPoint.crossSize
                height: 1
                color: Appearance.colors.colLayer0Border
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: crossPoint.crossSize
                color: Appearance.colors.colLayer0Border
            }
        }
    }

    Rectangle {
        id: centerLineV
        visible: root.gridVisible
        x: root.width / 2 - width / 2
        width: root.centerXActive ? 2 : 1
        height: root.height
        color: root.centerXActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.centerXActive ? 1 : 0.6

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on width {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: centerLineH
        visible: root.gridVisible
        y: root.height / 2 - height / 2
        width: root.width
        height: root.centerYActive ? 2 : 1
        color: root.centerYActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.centerYActive ? 1 : 0.6

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on height {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: selectionRectVisual
        visible: root.selecting
        x: root.selectionRect.x
        y: root.selectionRect.y
        width: root.selectionRect.width
        height: root.selectionRect.height
        color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.15)
        border.width: 1
        border.color: Appearance.colors.colPrimary
        z: 9999
    }

    Component {
        id: flashLineComponent
        Rectangle {
            id: flashLine
            property bool vertical: true
            property real linePos: 0
            color: Appearance.colors.colPrimary
            x: vertical ? linePos : 0
            y: vertical ? 0 : linePos
            width: vertical ? 2 : root.width
            height: vertical ? root.height : 2

            NumberAnimation on opacity {
                from: 0.9
                to: 0
                duration: 2000
                easing.type: Easing.OutCubic
                running: true
                onFinished: flashLine.destroy()
            }
        }
    }

    function flashLines(verticalPositions, horizontalPositions) {
        for (let i = 0; i < verticalPositions.length; i++)
            flashLineComponent.createObject(root, { vertical: true, linePos: verticalPositions[i] })
        for (let i = 0; i < horizontalPositions.length; i++)
            flashLineComponent.createObject(root, { vertical: false, linePos: horizontalPositions[i] })
    }
}