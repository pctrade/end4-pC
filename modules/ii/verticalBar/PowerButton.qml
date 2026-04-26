import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    property real buttonPadding: 5
    implicitWidth: Config.options.bar.cornerStyle === 2 ? 27 : 27 + buttonPadding 
    implicitHeight: Config.options.bar.cornerStyle === 2 ? 27 : 27 + buttonPadding 
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active

    onPressed: {
        GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "power_settings_new"
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnLayer0
    }
}