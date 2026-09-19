import qs.modules.common
import qs.services
import QtQuick

StyledText {
    id: root

    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0

    property real resolvedFill: fill >= 0.5 ? 1.0 : 0.0

    renderType: Text.NativeRendering

    font {
        hintingPreference: Font.PreferNoHinting
        family: Fonts?.iconMaterialFamily ?? "Material Symbols Rounded"
        pixelSize: iconSize
        weight: resolvedFill > 0.5 ? Font.DemiBold : Font.Normal
        variableAxes: {
            "FILL": resolvedFill,
            "opsz": iconSize,
        }
    }
}
