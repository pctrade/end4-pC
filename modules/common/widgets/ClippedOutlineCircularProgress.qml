import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property int implicitSize: 18
    property int lineWidth: 2
    property real value: 0
    property color colPrimary: Appearance?.colors.colOnSecondaryContainer ?? "#685496"
    property color colTrack: ColorUtils.transparentize(colPrimary, 0.5) ?? "#80685496"

    // ─── Huequito a cada lado del progreso (inicio y fin) ───────────────────
    // Cada extremo del arco de progreso tiene este gap contra el track.
    // El progreso arranca endGapAngle° tarde y termina endGapAngle° antes.
    property real endGapAngle: 5
    // ─────────────────────────────────────────────────────────────────────────

    // Hueco decorativo fijo en la parte inferior (M3 style)
    property real bottomGapAngle: 50

    property bool enableAnimation: true
    property int animationDuration: 800
    property var easingType: Easing.OutCubic

    default property Item textMask: Item {
        width: root.implicitSize
        height: root.implicitSize
        StyledText {
            anchors.centerIn: parent
            text: Math.round(root.value * 100)
            font.pixelSize: root.implicitSize * 0.38
            font.weight: Font.Medium
        }
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    readonly property real totalSweep: 360 - bottomGapAngle
    readonly property real startAngleDeg: 90 + bottomGapAngle / 2

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real arcRadius: implicitSize / 2 - lineWidth / 2 - 0.5

    property real _animatedValue: value
    Behavior on _animatedValue {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }

    readonly property real rawProgressSweep: _animatedValue * totalSweep
    readonly property bool hasProgress: rawProgressSweep > endGapAngle * 2
    readonly property real progressStart: startAngleDeg + endGapAngle
    readonly property real progressSweep: hasProgress ? rawProgressSweep - endGapAngle * 2 : 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.smooth: true

        // Track completo — siempre fijo por debajo
        ShapePath {
            strokeColor: root.colTrack
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngleDeg
                sweepAngle: root.totalSweep
            }
        }

        // Progreso — strokeColor transparente cuando no hay suficiente valor
        // (ShapePath no soporta "visible", se oculta con color transparente)
        ShapePath {
            strokeColor: root.hasProgress ? root.colPrimary : "transparent"
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.progressStart
                sweepAngle: root.progressSweep
            }
        }
    }

    // Contenido interno (texto/icono)
    Item {
        anchors.centerIn: parent
        width: root.implicitSize
        height: root.implicitSize
        children: [root.textMask]
    }
}
