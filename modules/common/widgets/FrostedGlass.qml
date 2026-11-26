import QtQuick
import qs.modules.common

Item {
    id: root
    required property Item blurSource
    property real cardRadius: 30
    property real topLeftRadius: cardRadius
    property real topRightRadius: cardRadius
    property real bottomRightRadius: cardRadius
    property real bottomLeftRadius: cardRadius
    property color tint: "white"
    property real tintOpacity: 0
    readonly property string tintChoice: Config.options.background.widgets.glass.tint ?? "transparent"
    readonly property bool tintOverride: tintChoice !== "transparent"
    readonly property color washColor: tintOverride ? Appearance.getColorFromName(tintChoice) : tint
    readonly property real washOpacity: tintOverride ? Config.options.background.widgets.glass.tintStrength : tintOpacity
    readonly property real rimWidth: Config.options.background.widgets.glass.rimWidth
    readonly property real pull: Config.options.background.widgets.glass.pull
    readonly property real split: Config.options.background.widgets.glass.split
    readonly property real haze: Config.options.background.widgets.glass.haze
    readonly property real vividness: Config.options.background.widgets.glass.vividness
    readonly property real sheen: Config.options.background.widgets.glass.sheen
    property real flareLeft: 0
    property real flareRight: 0
    property real hangLeft: 0
    property real hangRight: 0
    property int edge: 0
    property real trackX: 0
    property real trackY: 0

    ShaderEffectSource {
        id: capture
        sourceItem: root.blurSource
        sourceRect: {
            var _fx = root.trackX
            var _fy = root.trackY
            if (!root.blurSource) return Qt.rect(0, 0, 0, 0)
            var pt = root.mapToItem(root.blurSource, 0, 0)
            return Qt.rect(pt.x, pt.y, root.width, root.height)
        }
        mipmap: true
        hideSource: false
        live: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.blurSource !== null && root.width > 0 && root.height > 0

        property var backdrop: capture
        property vector2d size: Qt.vector2d(width, height)
        property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        property real rimWidth: root.rimWidth
        property real pull: root.pull
        property real split: root.split
        property real haze: root.haze
        property real vividness: root.vividness
        property real sheen: root.sheen
        property vector2d flares: Qt.vector2d(root.flareLeft, root.flareRight)
        property vector2d hangs: Qt.vector2d(root.hangLeft, root.hangRight)
        property real edge: root.edge
        property color wash: Qt.rgba(root.washColor.r, root.washColor.g, root.washColor.b, root.washOpacity)

        fragmentShader: Qt.resolvedUrl("shaders/liquidLens.frag.qsb")
    }
}
