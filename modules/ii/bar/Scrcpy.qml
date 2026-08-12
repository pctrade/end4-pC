import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

RippleButton {
    id: root

    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: 32
    implicitHeight: 32

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: isMaterial
        ? Appearance.colors.colPrimaryHover
        : Appearance.colors.colLayer1Hover
    colRipple: isMaterial
        ? Appearance.colors.colPrimaryActive
        : Appearance.colors.colLayer1Active

    onPressed: {
        Quickshell.execDetached(["/usr/bin/scrcpy"])
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "smartphone"
        iconSize: Appearance.font.pixelSize.normal
        color: root.isMaterial
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnLayer0
    }
}
