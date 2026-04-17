import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.topMargin: Appearance.sizes.elevationMargin + dockRow.padding + Appearance.rounding.normal
    Layout.bottomMargin: Appearance.sizes.hyprlandGapsOut + dockRow.padding + Appearance.rounding.normal
    Layout.fillHeight: true
    implicitWidth: 1
    color: Appearance.colors.colLayer0Border
}
