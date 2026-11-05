import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    property bool vertical: root.barConfig.vertical
    property real buttonPadding: 5

    implicitWidth: isMaterial ? 32 : 22
    implicitHeight: implicitWidth

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer1Active

    onPressed: {
        GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: !root.isMaterial
        text: "power_settings_new"
        iconSize: 18
        color: root.contentColor
    }

    MaterialShapeWrappedMaterialSymbol {
        anchors.centerIn: parent
        visible: root.isMaterial
        text: "power_settings_new"
        iconSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colOnPrimary
        colSymbol: Appearance.colors.colPrimary
        wrappedShape: MaterialShape.Shape.Cookie12Sided
        padding: 2
    }
}