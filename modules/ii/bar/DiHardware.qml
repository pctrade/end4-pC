import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A hardware moment, compact: what happened first, the detail under it, the number that matters on the right
RowLayout {
    id: hw
    required property Item di
    anchors {
        fill: parent
        leftMargin: hw.di.isMaterial ? 3 : 5
        rightMargin: 12
    }
    spacing: 10

    readonly property var payload: IslandHardware.payload
    readonly property color accent: IslandEvents.toneColor(hw.payload.tone)
    readonly property bool quick: hw.payload.kind === "caps" || hw.payload.kind === "layout"
    readonly property var hero: ({ key: "hardware-icon", item: hwIcon })

    MaterialShapeWrappedMaterialSymbol {
        id: hwIcon

        DiEntrance { target: hwIcon }
        wrappedShape: hw.payload.tone === "error" ? MaterialShape.Shape.Cookie4Sided
            : hw.payload.tone === "success" ? MaterialShape.Shape.Cookie9Sided : MaterialShape.Shape.Circle
        color: ColorUtils.transparentize(hw.accent, 0.78)
        colSymbol: hw.accent
        text: hw.payload.icon ?? "memory"
        iconSize: 15
        fill: 1
        padding: 5

        SequentialAnimation on scale {
            running: hw.payload.tone === "error" || (hw.payload.tone === "attention" && !hw.quick)
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 1.1; duration: IslandMotion.long; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: IslandMotion.long; easing.type: Easing.InOutSine }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: hw.payload.title ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: hw.payload.tone === "error" ? hw.accent : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: hw.payload.status || hw.payload.subtitle || ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    StyledText {
        visible: (hw.payload.value ?? "") !== ""
        text: hw.payload.value ?? ""
        font.pixelSize: hw.quick ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
        color: hw.accent
    }
}
