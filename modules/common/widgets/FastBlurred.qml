import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

Item {
    id: root
    required property Item blurSource
    property real cardRadius: 30
    property color tint: "white"
    property real tintOpacity: 0.15
    property real blurRadius: Config.options.background.widgets.blurRadius ?? 32
    property real trackX: 0
    property real trackY: 0

    readonly property real oversample: blurRadius * 1.5

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width; height: root.height
            radius: root.cardRadius
        }
    }

    FastBlur {
        id: blur
        x: -root.oversample
        y: -root.oversample
        width: root.width + root.oversample * 2
        height: root.height + root.oversample * 2
        radius: root.blurRadius
        visible: root.blurSource !== null
        source: root.blurSource ? shaderSource : null

        ShaderEffectSource {
            id: shaderSource
            sourceItem: root.blurSource
            sourceRect: {
                var _fx = root.trackX
                var _fy = root.trackY
                if (!root.blurSource) return Qt.rect(0, 0, 0, 0)
                var pt = root.mapToItem(root.blurSource, -root.oversample, -root.oversample)
                return Qt.rect(pt.x, pt.y, blur.width, blur.height)
            }
            hideSource: false
            live: true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: root.tint
        opacity: root.tintOpacity
    }
}