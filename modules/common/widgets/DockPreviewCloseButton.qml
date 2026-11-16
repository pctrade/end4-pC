import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

// Round close button used in the dock's window preview popup.
GroupButton {
    property real size: 30
    colBackgroundHover: ColorUtils.transparentize(DockStyle.popupTextColor, 0.88)
    colBackgroundActive: ColorUtils.transparentize(DockStyle.popupTextColor, 0.8)
    baseWidth: size
    baseHeight: size
    buttonRadius: Appearance.rounding.full
    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: "close"
        iconSize: Appearance.font.pixelSize.normal
        color: DockStyle.popupTextColor
    }
}
