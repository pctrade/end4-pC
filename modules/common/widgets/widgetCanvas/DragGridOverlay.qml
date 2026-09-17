import QtQuick
import qs.modules.common

/*
 * Pure-visual drag feedback (alignment grid, center cross, rubber-band
 * selection, drop snap-lines) that lives ABOVE the depth wallpaper container
 * so it stays visible while drag-selecting. It carries no input handling —
 * all events are owned by WidgetCanvas; this item only paints.
 *
 * The host (Background.qml) sets its z:
 *   depth wallpaper ON  -> 3 (above the depth container at z:1)
 *   depth wallpaper OFF -> 0 (exactly like the old canvas visuals: above the
 *                              wallpaper, below the widget layer)
 */
Item {
    id: root

    required property var canvas

    readonly property bool gridVisible: canvas.gridVisible

    Repeater {
        id: crossRepeater
        readonly property int cols: Math.ceil(root.width / canvas.gridSize) + 1
        readonly property int rows: Math.ceil(root.height / canvas.gridSize) + 1
        model: root.gridVisible ? cols * rows : 0
        delegate: Item {
            id: crossPoint
            required property int index
            readonly property int col: index % crossRepeater.cols
            readonly property int row: Math.floor(index / crossRepeater.cols)
            readonly property int crossSize: 5

            x: col * canvas.gridSize - crossSize / 2
            y: row * canvas.gridSize - crossSize / 2
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
        width: canvas.centerXActive ? 2 : 1
        height: root.height
        color: canvas.centerXActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: canvas.centerXActive ? 1 : 0.6

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
        height: canvas.centerYActive ? 2 : 1
        color: canvas.centerYActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: canvas.centerYActive ? 1 : 0.6

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
        visible: canvas.selecting
        x: canvas.selectionRect.x
        y: canvas.selectionRect.y
        width: canvas.selectionRect.width
        height: canvas.selectionRect.height
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