import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// ZeroTier, pinned: it is the thing that quietly breaks voice calls, so it gets a switch you can reach
RowLayout {
    id: zt
    required property Item di
    anchors {
        fill: parent
        leftMargin: 8
        rightMargin: 12
    }
    spacing: 8

    readonly property bool up: IslandEvents.ztUp
    readonly property bool risky: zt.up && IslandEvents.voiceCallActive
    readonly property color accent: zt.risky ? IslandEvents.colorAttention
        : zt.up ? IslandEvents.colorSuccess : Appearance.colors.colOnLayer0

    Binding {
        target: IslandEvents
        property: "ztWatch"
        value: true
        restoreMode: Binding.RestoreValue
    }

    TapHandler {
        onTapped: IslandEvents.toggleZeroTier()
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    MaterialShapeWrappedMaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        wrappedShape: zt.risky ? MaterialShape.Shape.Cookie4Sided : MaterialShape.Shape.Cookie9Sided
        color: ColorUtils.transparentize(zt.accent, 0.75)
        colSymbol: zt.accent
        text: IslandEvents.ztBusy ? "sync" : zt.up ? "vpn_lock" : "vpn_key_off"
        iconSize: 14
        fill: 1
        padding: 5

        RotationAnimator on rotation {
            running: IslandEvents.ztBusy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1200
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: zt.risky ? Translation.tr("ZeroTier on during a call")
                : zt.up ? Translation.tr("ZeroTier on") : Translation.tr("ZeroTier off")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: zt.risky ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: IslandEvents.ztBusy ? Translation.tr("Changing…")
                : zt.risky ? Translation.tr("Tap to turn off")
                : zt.up ? (IslandEvents.ztNetwork !== "" ? IslandEvents.ztNetwork : Translation.tr("Connected"))
                : Translation.tr("Tap to turn on")
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }
}
