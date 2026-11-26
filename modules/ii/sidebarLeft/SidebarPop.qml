import QtQuick
import qs.modules.common

Item {
    id: root

    property bool active: true
    property int animIndex: 0
    property real travelX: 0
    property real travelY: 0
    property real exitX: travelX
    property int staggerMs: 45
    property real minScale: 0.25
    property bool fade: true
    property real damping: 0.32
    property bool smooth: false
    readonly property var smoothCurve: [0.32, 0.72, 0, 1, 1, 1]
    readonly property real speed: Math.max(0.5, Config.options.settings.animationSpeed ?? 1)

    property real animScale: active ? 1 : minScale
    property real animOpacity: active || !fade ? 1 : 0
    property real offsetX: active ? 0 : travelX
    property real offsetY: active ? 0 : travelY

    transformOrigin: Item.Center
    scale: animScale
    opacity: animOpacity
    transform: Translate {
        x: root.offsetX
        y: root.offsetY
    }

    onActiveChanged: {
        if (!root.initialized) return
        const enter = root.smooth ? smoothEnter : enterAnim
        const exit = root.smooth ? smoothExit : exitAnim
        if (root.active) {
            exit.stop()
            if (root.smooth && root.animOpacity < 0.05) root.offsetX = root.travelX
            enter.restart()
        } else {
            enter.stop()
            exit.restart()
        }
    }

    property bool initialized: false
    Component.onCompleted: {
        root.initialized = true
        if (root.active) {
            root.animScale = root.minScale
            root.animOpacity = root.fade ? 0 : 1
            root.offsetX = root.travelX
            root.offsetY = root.travelY
            if (root.smooth) smoothEnter.start()
            else enterAnim.start()
        }
    }

    ParallelAnimation {
        id: smoothEnter
        NumberAnimation { target: root; property: "animScale"; to: 1; duration: 420 / root.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: root.smoothCurve }
        NumberAnimation { target: root; property: "offsetX"; to: 0; duration: 420 / root.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: root.smoothCurve }
        NumberAnimation { target: root; property: "offsetY"; to: 0; duration: 420 / root.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: root.smoothCurve }
        NumberAnimation { target: root; property: "animOpacity"; to: 1; duration: 260 / root.speed; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: smoothExit
        NumberAnimation { target: root; property: "animScale"; to: root.minScale; duration: 220 / root.speed; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "offsetX"; to: root.exitX; duration: 220 / root.speed; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "offsetY"; to: root.travelY; duration: 220 / root.speed; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "animOpacity"; to: root.fade ? 0 : 1; duration: 160 / root.speed; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: enterAnim
        PauseAnimation { duration: root.animIndex * root.staggerMs }
        ParallelAnimation {
            SpringAnimation { target: root; property: "animScale"; to: 1; spring: 2.6 * root.speed; damping: root.damping }
            SpringAnimation { target: root; property: "offsetX"; to: 0; spring: 2.6 * root.speed; damping: root.damping }
            SpringAnimation { target: root; property: "offsetY"; to: 0; spring: 2.6 * root.speed; damping: root.damping }
            NumberAnimation { target: root; property: "animOpacity"; to: 1; duration: 220 / root.speed; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: exitAnim
        PauseAnimation { duration: root.animIndex * (root.staggerMs - 4) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "animScale"; to: root.minScale; duration: 260 / root.speed; easing.type: Easing.InBack }
            NumberAnimation { target: root; property: "offsetX"; to: root.travelX; duration: 280 / root.speed; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "offsetY"; to: root.travelY; duration: 280 / root.speed; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "animOpacity"; to: root.fade ? 0 : 1; duration: 220 / root.speed; easing.type: Easing.InQuad }
        }
    }
}
