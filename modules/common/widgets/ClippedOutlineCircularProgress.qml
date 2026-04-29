import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property int implicitSize: 18
    property int lineWidth: 2
    property real value: 0
    property color colPrimary: Appearance?.colors.colOnSecondaryContainer ?? "#8EB840"
    property color colSecondary: ColorUtils.transparentize(colPrimary, 0.5) ?? "#888888"
    property real gapAngle: 360 / 18
    property bool enableAnimation: true
    property int animationDuration: 800
    property var easingType: Easing.OutCubic

    default property Item textMask: Item {}

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    property real degree: value * 360
    property real centerX: root.width / 2
    property real centerY: root.height / 2
    property real arcRadius: root.implicitSize / 2 - root.lineWidth / 2
    property real startAngle: -90

    Behavior on degree {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.colPrimary
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle + root.gapAngle
                sweepAngle: root.degree - root.gapAngle * 2
            }
        }

        ShapePath {
            strokeColor: root.colSecondary
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle + root.degree + root.gapAngle
                sweepAngle: 360 - root.degree - root.gapAngle * 2
            }
        }
    }

    Item {
        anchors.fill: parent
        children: [root.textMask]
    }
}