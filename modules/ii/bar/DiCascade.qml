import QtQuick

// Staggered entrance for a list item: fade, rise and scale on a spring.
// Only opacity, scale and a Translate move, so parent Layouts don't re-run.
QtObject {
    id: cascade
    required property Item target
    property int index: 0
    property int step: 30
    property int delay: 60
    property real rise: 8
    // Owns the target's scale, so press feedback is folded in here
    property bool pressed: false
    property real pressedScale: 0.95

    property DiSpring spring: DiSpring {
        stiffness: 240
        dampingRatio: 0.78
        epsilon: 0.002
    }
    property DiSpring press: DiSpring {
        target: cascade.pressed ? cascade.pressedScale : 1
        value: 1
        stiffness: 700
        dampingRatio: 0.6
        epsilon: 0.001
    }
    property Translate shift: Translate {
        y: (1 - cascade.spring.value) * cascade.rise
    }
    property Timer starter: Timer {
        interval: cascade.delay + cascade.index * cascade.step
        running: true
        onTriggered: cascade.spring.target = 1
    }

    Component.onCompleted: {
        cascade.target.transform = [cascade.shift]
        cascade.target.opacity = Qt.binding(() => Math.max(0, Math.min(1, cascade.spring.value)))
        cascade.target.scale = Qt.binding(() => (0.96 + 0.04 * cascade.spring.value) * cascade.press.value)
    }
}
