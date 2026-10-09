import QtQuick
import Quickshell.Io
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    statusText: GameMode.statusText
    toggled: GameMode.active
    icon: "gamepad"

    mainAction: () => {
        GameMode.toggle();
    }

    tooltipText: Translation.tr("Game mode")
}
