import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.modules.common

/**
 * Material 3 Expressive (Wavy) circular Dial.
 */
Dial {
    id: control

    property int implicitSize: 30
    property int lineWidth: 4
    property color colPrimary: Appearance.m3colors.m3onSecondaryContainer
    property color colSecondary: Appearance.colors.colSecondaryContainer
    property real gapAngle: 360 / 18
    property bool fill: false
    property int fillOverflow: 2

    property real waveAmplitude: 1.6
    property real waveLength: 15
    property real waveFrequency: (2 * Math.PI * bg.arcRadius) / waveLength
    property real wavePhase: 0

    stepSize: 0.05

    property bool enableAnimation: !pressed

    inputMode: Dial.Horizontal

    NumberAnimation on wavePhase {
        from: 0
        to: 360
        duration: 2000
        loops: Animation.Infinite
        running: true
    }

    MouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.NoButton

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                control.increase();
            } else {
                control.decrease();
            }
            control.moved();

            wheel.accepted = true;
        }
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    background: Item {
        id: bg
        anchors.fill: parent

        property real degree: control.position * 360
        property real centerX: width / 2
        property real centerY: height / 2
        property real arcRadius: Math.min(width, height) / 2 - control.lineWidth - control.waveAmplitude
        property real startAngle: 90

        Behavior on degree {
            enabled: control.enableAnimation
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        Loader {
            active: control.fill
            anchors.fill: parent
            sourceComponent: Circle {
                color: control.colSecondary
            }
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: secondaryPath
                strokeColor: control.colSecondary
                strokeWidth: control.lineWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: bg.centerX
                    centerY: bg.centerY
                    radiusX: bg.arcRadius
                    radiusY: bg.arcRadius
                    startAngle: bg.startAngle - control.gapAngle
                    sweepAngle: Math.min(0, -(360 - bg.degree - 2 * control.gapAngle))
                }
            }

            ShapePath {
                id: primaryPath
                strokeColor: control.colPrimary
                strokeWidth: control.lineWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"

                PathPolyline {
                    path: {
                        let pts = [];
                        let cx = bg.centerX;
                        let cy = bg.centerY;
                        let r = bg.arcRadius;
                        let startDeg = bg.startAngle;
                        let sweepDeg = bg.degree;

                        if (sweepDeg <= 0) {
                            return [Qt.point(cx + r * Math.cos(startDeg * Math.PI / 180), cy + r * Math.sin(startDeg * Math.PI / 180))];
                        }

                        let steps = Math.max(20, Math.floor(sweepDeg * 1.5));
                        for (let i = 0; i <= steps; i++) {
                            let currentDeg = startDeg + (sweepDeg * i / steps);
                            let rad = currentDeg * Math.PI / 180;

                            let edgeFactor = 1.0;
                            if (i < 4)
                                edgeFactor = i / 4.0;
                            if (steps - i < 4)
                                edgeFactor = (steps - i) / 4.0;

                            let waveOffset = control.waveAmplitude * Math.sin((currentDeg * control.waveFrequency + control.wavePhase) * Math.PI / 180) * edgeFactor;

                            let currentR = r + waveOffset;
                            let x = cx + currentR * Math.cos(rad);
                            let y = cy + currentR * Math.sin(rad);
                            pts.push(Qt.point(x, y));
                        }
                        return pts;
                    }
                }
            }
        }
    }

    handle: Item {
        width: control.lineWidth * 2
        height: control.lineWidth * 2

        property real currentDeg: control.background.startAngle + control.background.degree
        property real edgeFactor: control.background.degree > 0 ? 1.0 : 0.0
        property real waveOffset: control.waveAmplitude * Math.sin((currentDeg * control.waveFrequency + control.wavePhase) * Math.PI / 180) * edgeFactor
        property real currentR: control.background.arcRadius

        x: control.background.centerX - width / 2 + currentR * Math.cos(currentDeg * Math.PI / 180)
        y: control.background.centerY - height / 2 + currentR * Math.sin(currentDeg * Math.PI / 180)
    }
}
