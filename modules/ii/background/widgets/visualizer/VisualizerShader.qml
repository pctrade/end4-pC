import QtQuick

/*
 * One of the GPU visualizer styles (shaders/<style>.frag.qsb), fed by a VisualizerEngine.
 * Levels and peaks go to the shader packed four per vector.
 */
ShaderEffect {
    id: root

    required property string style
    required property VisualizerEngine engine
    property color color1
    property color color2
    property color color3
    // Ring only: texture provider for the cover, and whether it holds one
    property Item cover: null
    property real hasCover: 0

    readonly property real time: engine.time
    readonly property real bass: engine.bass
    readonly property real fade: engine.fade
    readonly property real bandCount: engine.bandCount
    readonly property vector2d resolution: Qt.vector2d(width, height)

    property vector4d b0; property vector4d b1; property vector4d b2; property vector4d b3
    property vector4d b4; property vector4d b5; property vector4d b6; property vector4d b7
    property vector4d b8; property vector4d b9; property vector4d b10; property vector4d b11
    property vector4d b12
    property vector4d p0; property vector4d p1; property vector4d p2; property vector4d p3
    property vector4d p4; property vector4d p5; property vector4d p6; property vector4d p7
    property vector4d p8; property vector4d p9; property vector4d p10; property vector4d p11
    property vector4d p12

    visible: fade > 0
    blending: true
    fragmentShader: Qt.resolvedUrl(`shaders/${style}.frag.qsb`)

    Connections {
        target: root.engine
        function onFrame() {
            const l = root.engine.levels;
            const p = root.engine.peaks;
            for (let k = 0; k < 13; k++) {
                const i = k * 4;
                root[`b${k}`] = Qt.vector4d(l[i], l[i + 1], l[i + 2], l[i + 3]);
                root[`p${k}`] = Qt.vector4d(p[i], p[i + 1], p[i + 2], p[i + 3]);
            }
        }
    }
}
