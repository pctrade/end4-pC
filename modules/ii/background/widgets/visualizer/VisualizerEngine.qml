import QtQuick
import qs

/*
 * Turns the raw cava levels into what the shader styles draw: smoothed levels
 * (fast attack, slow release), falling peaks, a beat pulse and a playback fade.
 * Ticks only while there is something to animate, and emits frame() after each step.
 */
Item {
    id: root
    visible: false

    property bool active: true
    property real sensitivity: 1
    property real maxValue: 1000

    readonly property int maxBands: 52
    readonly property list<real> raw: GlobalStates.visualizerPoints
    property int bandCount: 0
    property real time: 0
    property real bass: 0
    property real fade: 0
    // Mutated in place every frame, read them from frame()
    readonly property var levels: new Array(maxBands).fill(0)
    readonly property var peaks: new Array(maxBands).fill(0)

    signal frame()

    property real lastSignal: 0
    property real bassAverage: 0
    readonly property var peakHold: new Array(maxBands).fill(0)

    onRawChanged: {
        if (!root.active) return;
        if (root.raw.length > 0) root.bandCount = Math.min(root.raw.length, root.maxBands);
        for (let i = 0; i < root.raw.length; i++) {
            if (root.raw[i] > 0) {
                root.lastSignal = Date.now();
                ticker.running = true;
                return;
            }
        }
    }

    function step(dt) {
        const playing = Date.now() - root.lastSignal < 1000;
        const src = root.raw;
        root.time += dt;
        root.fade += ((playing ? 1 : 0) - root.fade) * Math.min(1, dt * (playing ? 4 : 1.5));

        let bassNow = 0;
        for (let i = 0; i < root.maxBands; i++) {
            const target = playing && i < src.length ? Math.min(1, src[i] / root.maxValue * root.sensitivity) : 0;
            const level = root.levels[i];
            root.levels[i] = level + (target - level) * Math.min(1, dt * (target > level ? 18 : 5));
            if (root.levels[i] >= root.peaks[i]) {
                root.peaks[i] = root.levels[i];
                root.peakHold[i] = 0.35;
            } else if (root.peakHold[i] > 0) {
                root.peakHold[i] -= dt;
            } else {
                root.peaks[i] = Math.max(root.levels[i], root.peaks[i] - dt * 0.45);
            }
            if (i < 4) bassNow += target / 4;
        }

        // A beat is bass energy rising well above its recent average
        root.bassAverage += (bassNow - root.bassAverage) * Math.min(1, dt * 1.5);
        if (bassNow > root.bassAverage * 1.3 + 0.04 && bassNow > 0.25)
            root.bass = Math.min(1, root.bass + (bassNow - root.bassAverage) * 2.5);
        root.bass *= Math.exp(-dt * 5);

        root.frame();
        if (!playing && root.fade < 0.002) {
            root.fade = 0;
            ticker.running = false;
        }
    }

    FrameAnimation {
        id: ticker
        running: false
        onTriggered: root.step(Math.min(frameTime, 0.1))
    }
}
