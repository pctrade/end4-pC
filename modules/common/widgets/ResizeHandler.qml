import qs.modules.common
import QtQuick

Canvas {
    id: root

    required property Item anchorItem
    property bool hoverActive: false
    property bool locked: false
    required property real currentWidth
    property string resizeMode: "horizontal" 
    property bool rotatable: false
    property real currentRotation: 0

    signal resized(real newValue)
    signal resizedXY(real dx, real dy, real startWidth)
    signal resizeFinished()
    signal rotated(real newAngle)
    signal rotateFinished()

    readonly property bool widgetSelected: {
        let item = root.anchorItem
        while (item) {
            if (item.selected === true) return true
            item = item.parent
        }
        return false
    }
    property real selectionInset: widgetSelected ? 8 : 0

    Behavior on selectionInset {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    width: 62
    height: 62
    anchors {
        right: anchorItem.right
        bottom: anchorItem.bottom
        rightMargin: -8 + selectionInset
        bottomMargin: -8 + selectionInset
    }
    opacity: (hoverActive || resizeArea.containsMouse || resizeArea.pressed) ? 0.85 : 0
    visible: opacity > 0 && !locked

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    property color strokeCol: Appearance.colors.colOnPrimaryContainer
    onStrokeColChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = strokeCol
        ctx.lineWidth = 3
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(width * 0.5, height * 0.5, width * 0.35, 0, Math.PI * 0.5)
        ctx.stroke()
    }

    MouseArea {
        id: resizeArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: root.resizeMode === "diagonal" ? Qt.SizeFDiagCursor : Qt.SizeHorCursor
        preventStealing: true

        property real startValue: 0
        property real startX: 0
        property real startY: 0

        onPressed: (mouse) => {
            startValue = root.currentWidth
            var globalPos = mapToItem(null, mouse.x, mouse.y)
            startX = globalPos.x
            startY = globalPos.y
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            var globalPos = mapToItem(null, mouse.x, mouse.y)
            var dx = globalPos.x - startX
            var dy = globalPos.y - startY
            var delta = root.resizeMode === "diagonal"
                ? Math.max(dx, dy)
                : dx
            root.resized(startValue + delta)
            root.resizedXY(dx, dy, startValue)
        }
        onReleased: {
            root.resizeFinished()
        }
    }

    Canvas {
        id: rotateHandle
        visible: root.rotatable && !root.locked
        anchors {
            right: parent.left
            bottom: parent.top
            rightMargin: -width / 2
            bottomMargin: 8
        }
        width: 36
        height: 36
        opacity: (root.hoverActive || rotateArea.containsMouse || rotateArea.pressed) ? 0.85 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        property color strokeCol: Appearance.colors.colOnPrimaryContainer
        onStrokeColChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = strokeCol
            ctx.lineWidth = 3
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(width * 0.5, height * 0.5, width * 0.3, Math.PI * 0.15, Math.PI * 1.75)
            ctx.stroke()

            var endAngle = Math.PI * 1.75
            var r = width * 0.3
            var ax = width * 0.5 + Math.cos(endAngle) * r
            var ay = height * 0.5 + Math.sin(endAngle) * r
            ctx.beginPath()
            ctx.moveTo(ax, ay)
            ctx.lineTo(ax - 5, ay - 3)
            ctx.moveTo(ax, ay)
            ctx.lineTo(ax - 3, ay + 5)
            ctx.stroke()
        }

        MouseArea {
            id: rotateArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            property real centerX: 0
            property real centerY: 0
            property real startAngle: 0
            property real startRotation: 0

            onPressed: (mouse) => {
                var center = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, root.anchorItem.height / 2)
                centerX = center.x
                centerY = center.y
                var globalPos = mapToItem(null, mouse.x, mouse.y)
                startAngle = Math.atan2(globalPos.y - centerY, globalPos.x - centerX)
                startRotation = root.currentRotation
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return
                var globalPos = mapToItem(null, mouse.x, mouse.y)
                var angle = Math.atan2(globalPos.y - centerY, globalPos.x - centerX)
                var deltaDeg = (angle - startAngle) * 180 / Math.PI
                root.rotated(startRotation + deltaDeg)
            }
            onReleased: {
                root.rotateFinished()
            }
        }
    }
}