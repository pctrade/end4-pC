import qs.modules.common
import QtQuick

Canvas {
    id: root

    required property Item anchorItem
    property bool hoverActive: false
    property bool locked: false
    required property real currentWidth
    property string resizeMode: "horizontal" 

    signal resized(real newValue)
    signal resizeFinished()

    width: 62
    height: 62
    anchors {
        right: anchorItem.right
        bottom: anchorItem.bottom
        rightMargin: -8
        bottomMargin: -8
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
            var delta = root.resizeMode === "diagonal"
                ? Math.max(globalPos.x - startX, globalPos.y - startY)
                : (globalPos.x - startX)
            root.resized(startValue + delta)
        }
        onReleased: {
            root.resizeFinished()
        }
    }
}