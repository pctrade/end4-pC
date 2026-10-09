pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

/**
 * Handles GameMode status, syncing with feralinteractive/gamemode daemon and Hyprland optimizations.
 */
Singleton {
    id: root

    property bool active: false
    property int feralClientCount: 0
    property bool manualActive: false
    property bool feralAvailable: false
    property bool forcedOff: false

    readonly property string statusText: active ? Translation.tr("Active") : Translation.tr("Inactive")

    function load() {
        // Initializes the singleton
    }

    function applyHyprlandOptimizations() {
        if (WM.compositor !== "hyprland") return;
        Quickshell.execDetached([
            "bash", "-c",
            "hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true } })' 2>/dev/null || hyprctl --batch 'keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword general:allow_tearing 1'"
        ]);
    }

    function restoreHyprland() {
        if (WM.compositor !== "hyprland") return;
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function updateActiveState() {
        const shouldBeActive = !root.forcedOff && (root.manualActive || root.feralClientCount > 0);
        if (root.active !== shouldBeActive) {
            root.active = shouldBeActive;
            if (shouldBeActive) {
                root.applyHyprlandOptimizations();
            } else {
                root.restoreHyprland();
            }
        }
    }

    function refreshClientCount() {
        if (!clientCountProc.running) {
            clientCountProc.running = true;
        }
    }

    function toggle() {
        if (root.active) {
            root.manualActive = false;
            if (manualProc.running) {
                manualProc.running = false;
            }
            if (root.feralClientCount > 0) {
                root.forcedOff = true;
            }
            root.updateActiveState();
        } else {
            root.forcedOff = false;
            root.manualActive = true;
            if (root.feralAvailable && !manualProc.running) {
                manualProc.running = true;
            }
            root.updateActiveState();
        }
    }

    // Process holding manual gamemode request open
    Process {
        id: manualProc
        command: ["gamemoded", "-r"]
    }

    // Check if feral gamemode is installed
    Process {
        id: checkFeralProc
        running: true
        command: ["bash", "-c", "command -v gamemoded >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.feralAvailable = exitCode === 0;
            if (root.feralAvailable) {
                queryStatusProc.running = true;
                monitorProc.running = true;
            }
        }
    }

    // Query current status on startup
    Process {
        id: queryStatusProc
        command: ["gamemoded", "-s"]
        stdout: StdioCollector {
            onStreamFinished: {
                const isActive = text.includes("is active");
                if (isActive) {
                    root.refreshClientCount();
                } else {
                    root.feralClientCount = 0;
                    root.updateActiveState();
                }
            }
        }
    }

    // Live monitor of feralinteractive gamemode DBus events
    Process {
        id: monitorProc
        command: ["stdbuf", "-oL", "busctl", "--user", "monitor", "com.feralinteractive.GameMode"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("GameRegistered") || data.includes("GameUnregistered") || data.includes("ClientCount")) {
                    root.refreshClientCount();
                }
            }
        }
    }

    Process {
        id: clientCountProc
        command: ["bash", "-c", "busctl --user get-property com.feralinteractive.GameMode /com/feralinteractive/GameMode com.feralinteractive.GameMode ClientCount 2>/dev/null | awk '{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim()) || 0;
                root.feralClientCount = count;
                if (count === 0) {
                    root.forcedOff = false;
                }
                root.updateActiveState();
            }
        }
    }
}
