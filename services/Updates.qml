pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service.
 * Supports Arch (pacman/checkupdates/yay) and Debian-based (apt).
 */
Singleton {
    id: root

    property bool available: false
    property alias checking: checkUpdatesProc.running
    property int count: 0

    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    // Distro-aware availability check
    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["bash", "-c", "\
            if [ \"${SystemInfo.distroId}\" = \"arch\" ] || [ \"${SystemInfo.distroId}\" = \"cachyos\" ] || [ \"${SystemInfo.distroId}\" = \"endeavouros\" ]; then
                which checkupdates >/dev/null 2>&1 && echo \"arch\"
            elif command -v apt &>/dev/null && [ -f /etc/debian_version ]; then
                echo \"debian\"
            else
                echo \"unsupported\"
            fi
        "]
        onExited: (exitCode, exitStatus) => {
            const out = (exitStatus?.toString() ?? "").trim()
            root.available = (out === "arch" || out === "debian")
            root.refresh()
        }
    }

    // Distro-aware update count
    Process {
        id: checkUpdatesProc
        command: ["bash", "-c", "\
            if [ \"${SystemInfo.distroId}\" = \"arch\" ] || [ \"${SystemInfo.distroId}\" = \"cachyos\" ] || [ \"${SystemInfo.distroId}\" = \"endeavouros\" ]; then
                pacman=$(checkupdates 2>/dev/null | wc -l)
                aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0)
                echo $((pacman + aur))
            elif command -v apt &>/dev/null && [ -f /etc/debian_version ]; then
                apt update -qq 2>/dev/null
                apt list --upgradable 2>/dev/null | tail -n +2 | wc -l
            else
                echo 0
            fi
        "]
        stdout: StdioCollector {
            onStreamFinished: {
                root.count = parseInt(text.trim())
            }
        }
    }
}
