import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Compact second-screen view
RowLayout {
    id: disp
    required property Item di
    anchors {
        fill: parent
        leftMargin: disp.di.isMaterial ? 3 : 5
        rightMargin: 12
    }
    spacing: 9

    readonly property var payload: IslandHardware.displayPayload ?? ({})
    readonly property string layout: disp.payload.layout ?? "extend"
    readonly property var hero: ({ key: "hardware-icon", item: dispIcon })

    MaterialShapeWrappedMaterialSymbol {
        id: dispIcon
        DiEntrance { target: dispIcon }
        wrappedShape: MaterialShape.Shape.Circle
        color: Appearance.colors.colLayer2
        colSymbol: Appearance.colors.colOnLayer0
        text: disp.layout === "mirror" ? "screen_share" : disp.layout === "only" ? "tv" : "desktop_windows"
        iconSize: 14
        fill: 1
        padding: 5
    }

    StyledText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: (disp.payload.subtitle ?? "").split(" · ")[0] || Translation.tr("Second screen")
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Medium
        color: Appearance.colors.colOnLayer0
        elide: Text.ElideRight
    }

    StyledText {
        text: disp.layout === "mirror" ? Translation.tr("Mirror")
            : disp.layout === "only" ? Translation.tr("External only") : Translation.tr("Extend")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }
}
