import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool vertical: Config.options.bar.vertical
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
        color: Appearance.colors.colOnLayer0
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