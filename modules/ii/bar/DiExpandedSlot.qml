import QtQuick
import qs.modules.common
import qs.services

// One of the two layers DiExpandedContent crossfades between. Holds a single view, centred,
// and scrolls only when the view is taller than the island can get.
Item {
    id: slot
    required property Item host
    property string contentId: ""
    readonly property Item view: loader.item
    readonly property real padding: 14

    readonly property real naturalHeight: (loader.item?.implicitHeight ?? 60) + slot.padding * 2
    // A view's own wantedWidth wins: a root Layout reports the last width it was given as implicitWidth
    readonly property real naturalWidth: (loader.item?.wantedWidth ?? loader.item?.implicitWidth ?? 280) + slot.padding * 2
    readonly property bool scrollable: slot.naturalHeight > slot.host.maxHeight + 1

    property real shift: 0

    // Overscroll stretches like a rubber band; pulled far enough it hands off to the island.
    // `pull` is raw overscroll (positive past the top), `stretch` is the drawn value with resistance.
    signal overscrolled(int direction)
    property real pull: 0
    property double shownAt: 0
    readonly property real pullToSwitch: 110
    readonly property real stretch: {
        const reach = 48
        const x = Math.abs(slot.pull)
        return Math.sign(slot.pull) * (1 - 1 / (x * 0.55 / reach + 1)) * reach
    }

    width: slot.host.width
    height: Math.min(slot.naturalHeight, slot.host.maxHeight)
    y: (slot.host.height - slot.height) / 2 + slot.shift
    opacity: 0
    visible: slot.contentId !== ""
    transformOrigin: Item.Center

    function show(id, direction, instant) {
        leaving.stop()
        entering.stop()
        slot.contentId = id
        flick.contentY = 0
        pullBack.stop()
        slot.pull = 0
        slot.shownAt = Date.now()
        if (instant) {
            slot.opacity = 1
            slot.scale = 1
            slot.shift = 0
            return
        }
        slot.opacity = 0
        slot.scale = 0.975
        slot.shift = 14 * direction
        entering.start()
    }

    function leave(direction) {
        entering.stop()
        leaving.travel = -10 * direction
        leaving.start()
    }

    SequentialAnimation {
        id: entering
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: slot; property: "opacity"; to: 1; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
            NumberAnimation { target: slot; property: "scale"; to: 1; duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            NumberAnimation { target: slot; property: "shift"; to: 0; duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
        }
    }

    SequentialAnimation {
        id: leaving
        property real travel: 0
        ParallelAnimation {
            NumberAnimation { target: slot; property: "opacity"; to: 0; duration: IslandMotion.short - 60; easing.type: Easing.InCubic }
            NumberAnimation { target: slot; property: "scale"; to: 0.965; duration: IslandMotion.short; easing.type: Easing.OutCubic }
            NumberAnimation { target: slot; property: "shift"; to: leaving.travel; duration: IslandMotion.short; easing.type: Easing.OutCubic }
        }
        // Unloaded when gone so hidden views drop their timers and bindings
        ScriptAction { script: slot.contentId = "" }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: slot.scrollable
        interactive: slot.scrollable
        contentWidth: width
        contentHeight: slot.naturalHeight
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            parent: flick
            anchors.fill: parent
            z: 10
            enabled: slot.scrollable
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                wheel.accepted = true
                const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * 48
                const atTop = flick.contentY <= 0.5
                const atBottom = flick.contentY >= flick.contentHeight - flick.height - 0.5
                if ((step > 0 && atTop) || (step < 0 && atBottom)) {
                    // Ignore the tail of the previous gesture (touchpad momentum)
                    if (slot.host.currentSlot !== slot || Date.now() - slot.shownAt < 350) return
                    pullBack.stop()
                    slot.pull += step
                    pullRelease.restart()
                    if (Math.abs(slot.pull) >= slot.pullToSwitch) {
                        const direction = slot.pull < 0 ? 1 : -1
                        pullBack.start()
                        slot.overscrolled(direction)
                    }
                    return
                }
                if (slot.pull !== 0) pullBack.start()
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - step))
            }
        }

        Loader {
            id: loader
            x: slot.padding
            y: slot.padding + slot.stretch
            width: flick.width - slot.padding * 2
            height: loader.item?.implicitHeight ?? 60
            sourceComponent: slot.contentId === "" ? null : slot.host.componentFor(slot.contentId)
        }
    }

    Timer {
        id: pullRelease
        interval: 140
        onTriggered: pullBack.start()
    }
    NumberAnimation {
        id: pullBack
        target: slot
        property: "pull"
        to: 0
        duration: IslandMotion.medium
        easing.type: Easing.OutCubic
    }

    Rectangle {
        visible: slot.scrollable
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: slot.padding + (slot.height - slot.padding * 2 - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
        width: 3
        height: Math.max(24, (slot.height - slot.padding * 2) * flick.height / Math.max(1, flick.contentHeight))
        radius: 1.5
        color: Appearance.colors.colOnLayer0
        opacity: flick.moving ? 0.5 : 0.2

        Behavior on opacity {
            NumberAnimation { duration: IslandMotion.short }
        }
    }
}
