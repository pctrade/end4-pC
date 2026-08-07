import QtQuick
import Quickshell.Io
import qs.modules.common
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    toggled: Persistent.states?.gameMode?.enabled ?? false
    icon: "gamepad"

    function setEnabled(enabled) {
        root.toggled = enabled
        Persistent.states.gameMode.enabled = enabled
    }

    mainAction: () => {
        const shouldEnable = !root.toggled;
        root.setEnabled(shouldEnable);

        if (shouldEnable) {
            HyprlandConfig.setMany({
                "animations:enabled": 0,
                "decoration:shadow:enabled": 0,
                "decoration:blur:enabled": 0,
                "general:gaps_in": 0,
                "general:gaps_out": 0,
                "general:border_size": 1,
                "decoration:rounding": 0,
                "general:allow_tearing": 1
            });

            Presets.activateGameMode();
            return;
        }

        if (Presets.restorePreviousPreset()) {
            return;
        }

        HyprlandConfig.resetMany([ //
            "animations:enabled", //
            "decoration:shadow:enabled", //
            "decoration:blur:enabled", //
            "general:gaps_in", //
            "general:gaps_out", //
            "general:border_size", //
            "decoration:rounding", //
            "general:allow_tearing", //
        ]);
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
    }

    Component.onCompleted: {
        if (Persistent.states?.gameMode?.enabled ?? false) {
            root.toggled = true
            HyprlandConfig.setMany({
                "animations:enabled": 0,
                "decoration:shadow:enabled": 0,
                "decoration:blur:enabled": 0,
                "general:gaps_in": 0,
                "general:gaps_out": 0,
                "general:border_size": 1,
                "decoration:rounding": 0,
                "general:allow_tearing": 1
            });
        }
    }

    tooltipText: Translation.tr("Game mode")
}
