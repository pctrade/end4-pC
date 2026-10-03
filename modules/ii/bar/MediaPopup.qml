import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Services.Mpris

StyledPopup {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    popupContentMargin: 0
    popupColor: "transparent"
    popupRadius: 0
    popupBorderWidth: 0
    popupShadowEnabled: false
    popupEnabled: !GlobalStates.mediaControlsOpen && root.activePlayer !== null
    property bool barHovered: false
    property bool hoverBridgeActive: false
    readonly property bool keepsBarExpanded: root.popupHovered || root.hoverBridgeActive

    shouldShow: !GlobalStates.barStyleEditorOpen && root.popupEnabled && Config.options.bar.tooltips.enable
        && (root.targetHovered || root.popupHovered || root.hoverBridgeActive)

    onTargetHoveredChanged: {
        if (root.targetHovered) {
            root.hoverBridgeActive = false
            root.hoverBridgeTimer.stop()
            root.barReturnTimer.stop()
        } else {
            root.hoverBridgeActive = true
            root.hoverBridgeTimer.restart()
            root.barReturnTimer.restart()
        }
    }

    onPopupHoveredChanged: {
        if (root.popupHovered) {
            root.hoverBridgeActive = false
            root.hoverBridgeTimer.stop()
            root.barReturnTimer.stop()
        } else if (!root.targetHovered) {
            root.hoverBridgeActive = true
            root.hoverBridgeTimer.restart()
            root.barReturnTimer.restart()
        }
    }

    onBarHoveredChanged: {
        if (root.barHovered && !root.targetHovered && !root.popupHovered)
            root.barReturnTimer.restart()
    }

    property Timer hoverBridgeTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.targetHovered && !root.popupHovered)
                root.hoverBridgeActive = false
        }
    }

    property Timer barReturnTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (root.barHovered && !root.targetHovered && !root.popupHovered) {
                root.hoverBridgeTimer.stop()
                root.hoverBridgeActive = false
            }
        }
    }

    Player {
        player: root.activePlayer
        visualizerPoints: GlobalStates.visualizerPoints
        implicitWidth: Appearance.sizes.mediaControlsWidth
        implicitHeight: Appearance.sizes.mediaControlsHeight
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
    }
}
