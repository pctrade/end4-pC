import QtQuick
import qs.modules.common

/**
 * Apply shared touchpad sensitivity after content and nested controls have
 * received input. Mouse-wheel notches and horizontal-only gestures use Qt.
 * In ScrollView, declare this as an object property to keep it out of the
 * control's default contentData. TextArea still supplies the content size.
 */
MouseArea {
    id: root

    required property Flickable flickable
    property real touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor
    property real touchpadSensitivity: Config.options.interactions.scrolling.touchpadSensitivity
    readonly property bool scrolling: scrollTimer.running

    // Normalize old absolute values against 450, preserving ratios rather
    // than the old absolute movement speed.
    readonly property real relativeFactor: touchpadScrollFactor > 10
        ? touchpadScrollFactor / 450 : Math.max(0, touchpadScrollFactor)
    property bool _pixelGesture: false
    // Keep ownership until the phase reset, even when the inactivity timer expires.
    property bool _enhancedGesture: false

    // Stay in the viewport, behind content so nested views and wheel controls
    // can handle input before it reaches this area's native Flickable parent.
    parent: flickable.contentItem
    x: flickable.contentX
    y: flickable.contentY
    width: flickable.width
    height: flickable.height
    z: -1
    visible: Config.options.interactions.scrolling.fasterTouchpadScroll
    enabled: flickable.interactive
        && flickable.contentHeight + flickable.topMargin + flickable.bottomMargin > flickable.height
        && flickable.flickableDirection !== Flickable.HorizontalFlick
    acceptedButtons: Qt.NoButton

    Timer {
        id: scrollTimer
        interval: 120
        onTriggered: root._pixelGesture = false
    }

    // Native Qt tracking cannot resume halfway through our direct movement:
    // it still has the old press origin. Chain enhanced movement explicitly.
    function chainScroll(event) {
        event.accepted = true
        for (let ancestor = root.flickable.parent; ancestor; ancestor = ancestor.parent) {
            if (!(ancestor instanceof Flickable)) continue
            for (const child of ancestor.contentItem.children) {
                if (child instanceof TouchpadScrollArea && child.enabled && child.visible) {
                    child.handleWheel(event)
                    event.accepted = true
                    return
                }
            }
        }
    }

    function handleWheel(event) {
        event.accepted = false
        const f = root.flickable
        const dx = event.angleDelta.x
        const dy = event.angleDelta.y
        const px = event.pixelDelta.x
        const py = event.pixelDelta.y
        if (dx === 0 && dy === 0 && px === 0 && py === 0) {
            root._pixelGesture = false
            root._enhancedGesture = false
            scrollTimer.stop()
            // Qt needs gesture begin/end events to maintain its own tracking.
            return
        }
        // A horizontal-only gesture starts with native Qt scrolling. Once
        // enhanced tracking starts, keep both axes on the same path until end.
        if (!root._enhancedGesture && dy === 0 && py === 0) return
        // A mouse notch must pass through even just after a pixel gesture.
        if (px === 0 && py === 0 && dy !== 0 && Math.abs(dy) % 120 === 0) return

        root._enhancedGesture = true
        if (px !== 0 || py !== 0) root._pixelGesture = true
        scrollTimer.restart()
        if (px === 0 && py === 0 && root._pixelGesture) {
            // Ignore a rounded-to-zero pixel sample without changing units.
            event.accepted = true
            return
        }
        const scale = root.touchpadSensitivity * root.relativeFactor
        const deltaY = -(root._pixelGesture ? py : dy / 12) * scale
        const minY = f.originY - f.topMargin
        const maxY = Math.max(minY, f.originY + f.contentHeight - f.height + f.bottomMargin)
        const targetY = Math.max(minY, Math.min(maxY, f.contentY + deltaY))
        const horizontal = f.flickableDirection !== Flickable.VerticalFlick
            && f.contentWidth + f.leftMargin + f.rightMargin > f.width
        const deltaX = horizontal ? -(root._pixelGesture ? px : dx / 12) * scale : 0
        const minX = f.originX - f.leftMargin
        const maxX = Math.max(minX, f.originX + f.contentWidth - f.width + f.rightMargin)
        const targetX = horizontal ? Math.max(minX, Math.min(maxX, f.contentX + deltaX)) : f.contentX
        if (targetY === f.contentY && targetX === f.contentX && (deltaY !== 0 || deltaX !== 0)) {
            root.chainScroll(event)
            return
        }

        f.cancelFlick()
        if (horizontal) f.contentX = targetX
        f.contentY = targetY
        event.accepted = true
    }

    onWheel: event => root.handleWheel(event)
}
