import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

RippleButton {
    id: root

    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool popupOpen: false

    implicitWidth: 32
    implicitHeight: 32
    toggled: popupOpen

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: isMaterial
        ? Appearance.colors.colPrimaryHover
        : Appearance.colors.colLayer1Hover
    colRipple: isMaterial
        ? Appearance.colors.colPrimaryActive
        : Appearance.colors.colLayer1Active

    onClicked: popupOpen = !popupOpen

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) root.popupOpen = false
        }
    }

    LazyLoader {
        active: root.popupOpen
        component: ScrcpyPopup {
            anchorItem: root
            onDismissed: root.popupOpen = false
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "smartphone"
        iconSize: Appearance.font.pixelSize.normal
        color: root.isMaterial || root.popupOpen
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnLayer0
    }
}
