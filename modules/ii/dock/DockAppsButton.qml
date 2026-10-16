import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

DockButton {
    visible: Config.options.dock.showAppsButton
    Layout.topMargin: 0
    Layout.leftMargin: 0
    innerInset: DockStyle.appsButtonInnerInset
    outerInset: DockStyle.appsButtonOuterInset

    contentItem: MaterialSymbol {
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        iconSize: DockStyle.buttonBase / 2
        text: "apps"
        color: Appearance.colors.colOnLayer0
    }
}
