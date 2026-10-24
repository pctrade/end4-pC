pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

Singleton {
    id: root

    // Share player selection with the regular media widget.
    readonly property MprisPlayer player: MprisController.activePlayer

    function load() {} // Register IPC controls even while the widget is disabled.

    function open() {
        if (root.player?.canRaise) {
            root.player.raise()
        }
    }

    IpcHandler {
        target: "spun"
        function open(): void { root.open() }
        function enableWidget(): void { Config.options.background.widgets.spun.enable = true }
        function disableWidget(): void { Config.options.background.widgets.spun.enable = false }
    }
}
