pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Supports Fedora (DNF + Flatpak) and Arch Linux (pacman/AUR).
 */
Singleton {
    id: root

    property bool available: true
    property alias checking: checkUpdatesProc.running
    property int count: 0
    
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {
        refresh();
    }

    function refresh() {
        if (checkUpdatesProc.running) return;
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

    Process {
        id: checkUpdatesProc
        command: ["bash", "-c", "
            total=0
            if command -v dnf &>/dev/null; then
                dnf_c=$(dnf check-update -q 2>/dev/null | grep -v '^Upgrades' | grep -v '^Security' | grep -v '^[[:space:]]*$' | wc -l || echo 0)
                total=$((total + dnf_c))
            elif command -v checkupdates &>/dev/null; then
                arch_c=$(checkupdates 2>/dev/null | wc -l || echo 0)
                aur_c=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0)
                total=$((total + arch_c + aur_c))
            fi
            if command -v flatpak &>/dev/null; then
                fp_out=$(echo 'n' | flatpak update 2>&1)
                if ! echo \"$fp_out\" | grep -q 'Nothing to update'; then
                    fp_c=$(echo \"$fp_out\" | grep -E '^[[:space:]]*[0-9]+\\.' | wc -l || echo 0)
                    total=$((total + fp_c))
                fi
            fi
            echo $total
        "]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = parseInt(text.trim());
                root.count = isNaN(c) ? 0 : c;
            }
        }
    }
}
