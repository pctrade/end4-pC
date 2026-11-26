import QtQuick
import qs.modules.common

Item {
    id: root
    property bool open: false
    property real closedScale: 0.6

    visible: opacity > 0
    opacity: root.open ? 1 : 0
    scale: root.open ? 1 : root.closedScale

    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? Appearance.animationCurves.expressiveEffectsDuration : 120
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Appearance.animationCurves.expressiveEffects : Appearance.animationCurves.emphasizedAccel
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: root.open ? 500 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Appearance.animationCurves.expressiveFastSpatial : Appearance.animationCurves.emphasizedAccel
        }
    }
}
