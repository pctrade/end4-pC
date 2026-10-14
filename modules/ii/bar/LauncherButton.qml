import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool vertical: root.barConfig.vertical
    property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4

    implicitWidth: 22
    implicitHeight: 22

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimaryContainer : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? Appearance.colors.colLayer1Active : Appearance.colors.colLayer1Active
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.overviewOpen

    onPressed: {
        GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
    }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 18
        text: "search"
        color: root.contentColor
    }
}