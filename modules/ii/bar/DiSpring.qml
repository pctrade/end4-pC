import QtQuick

// Damped spring integrated every frame, driven by stiffness + damping ratio.
// Changing `target` mid-flight keeps the current velocity.
QtObject {
    id: spring

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real stiffness: 380
    property real dampingRatio: 0.84
    property real epsilon: 0.25
    readonly property bool moving: spring.ticker.running

    property bool animated: true

    // Straight to the target, no motion (without touching a binding on `target`)
    function snap() {
        spring.ticker.stop()
        spring.value = spring.target
        spring.velocity = 0
    }

    Component.onCompleted: spring.value = spring.target
    onTargetChanged: {
        if (!spring.animated) spring.snap()
        else if (!spring.ticker.running) spring.ticker.start()
    }
    onAnimatedChanged: if (!spring.animated) spring.snap()

    property FrameAnimation ticker: FrameAnimation {
        onTriggered: {
            // A dropped frame must not become a huge step; small substeps keep a stiff spring stable
            const dt = Math.min(frameTime, 1 / 30)
            const steps = Math.max(1, Math.ceil(dt * 240))
            const h = dt / steps
            const k = spring.stiffness
            const c = 2 * spring.dampingRatio * Math.sqrt(k)
            let x = spring.value
            let v = spring.velocity
            for (let i = 0; i < steps; i++) {
                v += (-k * (x - spring.target) - c * v) * h
                x += v * h
            }
            if (Math.abs(x - spring.target) < spring.epsilon && Math.abs(v) < spring.epsilon * 12) {
                x = spring.target
                v = 0
                stop()
            }
            spring.value = x
            spring.velocity = v
        }
    }
}
