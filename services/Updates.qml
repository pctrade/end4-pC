pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service.
 * Supports multiple distros via Config.options.updates.distro:
 * - "auto" (default): detected from /etc/os-release
 * - "arch", "cachyos", "debian", "fedora", "opensuse": forced
 * - "custom": uses Config.options.updates.customUpdateCommand
 */
Singleton {
    id: root

    property bool available: false
    property alias checking: checkUpdatesProc.running
    property int count: 0
    // Kept for compatibility with bar widgets (UpdatesCount) that color by advisability
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    property string detectedId: "" // e.g. "cachyos"
    property string detectedIdLike: "" // e.g. "arch"

    readonly property string distroSetting: Config.options.updates.distro
    readonly property string resolvedDistro: {
        if (distroSetting !== "auto") return distroSetting;
        const id = detectedId;
        const like = detectedIdLike;
        if (id === "cachyos" || like.includes("cachyos")) return "cachyos";
        if (id === "ubuntu" || id === "debian" || id === "linuxmint" || id === "pop" || like.includes("debian")) return "debian";
        if (id === "fedora" || like.includes("fedora")) return "fedora";
        if (like.includes("suse") || id.includes("opensuse")) return "opensuse";
        if (id === "arch" || id === "archarm" || like.includes("arch")) return "arch";
        return "unknown";
    }

    readonly property var distroInfo: ({
        "arch": {
            "name": "Pacman + AUR",
            "availableCmd": "command -v checkupdates >/dev/null 2>&1",
            "countCmd": "pacman=$(checkupdates 2>/dev/null | wc -l); aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0); echo $((pacman + aur))",
            "updateCmd": "if command -v yay >/dev/null 2>&1; then yay -Syu --combinedupgrade=false; elif command -v paru >/dev/null 2>&1; then paru -Syu; else pkexec pacman -Syu; fi"
        },
        "cachyos": {
            "name": "CachyOS (cachy-update)",
            "availableCmd": "command -v checkupdates >/dev/null 2>&1 || command -v cachy-update >/dev/null 2>&1",
            "countCmd": "pacman=$(checkupdates 2>/dev/null | wc -l); aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0); echo $((pacman + aur))",
            "updateCmd": "if command -v cachy-update >/dev/null 2>&1; then cachy-update; elif command -v yay >/dev/null 2>&1; then yay -Syu --combinedupgrade=false; elif command -v paru >/dev/null 2>&1; then paru -Syu; else pkexec pacman -Syu; fi"
        },
        "debian": {
            "name": "APT",
            "availableCmd": "command -v apt-get >/dev/null 2>&1",
            "countCmd": "apt list --upgradable 2>/dev/null | tail -n +2 | wc -l",
            "updateCmd": "sudo apt update && sudo apt upgrade"
        },
        "fedora": {
            "name": "DNF",
            "availableCmd": "command -v dnf >/dev/null 2>&1",
            "countCmd": "dnf -q check-update 2>/dev/null | grep -cE '^[a-zA-Z0-9]' || true",
            "updateCmd": "sudo dnf upgrade"
        },
        "opensuse": {
            "name": "Zypper",
            "availableCmd": "command -v zypper >/dev/null 2>&1",
            "countCmd": "zypper -q list-updates 2>/dev/null | grep -c '^v ' || true",
            "updateCmd": "sudo zypper dup"
        },
        "custom": {
            "name": "Custom command",
            "availableCmd": "true",
            "countCmd": "echo 0",
            "updateCmd": Config.options.updates.customUpdateCommand
        },
        "unknown": {
            "name": "Updates",
            "availableCmd": "false",
            "countCmd": "echo 0",
            "updateCmd": "echo 'No update command for this distro'"
        }
    })

    readonly property var info: distroInfo[resolvedDistro] ?? distroInfo["unknown"]
    readonly property string updaterName: info.name
    readonly property string updateCommand: info.updateCmd
    // Whether an update action makes sense at all (independent of periodic checks being enabled)
    readonly property bool canRunUpdate: resolvedDistro === "custom"
        ? Config.options.updates.customUpdateCommand.length > 0
        : (resolvedDistro !== "unknown")

    onResolvedDistroChanged: {
        root.available = false;
        if (Config.ready && Config.options.updates.enableCheck)
            checkAvailabilityProc.running = true;
    }

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    // Detect distro from /etc/os-release for the "auto" setting
    Process {
        id: detectDistroProc
        running: true
        command: ["bash", "-c", ". /etc/os-release 2>/dev/null; echo \"${ID:-}|${ID_LIKE:-}\""]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|");
                root.detectedId = (parts[0] ?? "").trim();
                root.detectedIdLike = (parts[1] ?? "").trim();
            }
        }
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
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["bash", "-c", root.info.availableCmd]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            firstCheckTimer.start();
        }
    }

    Timer {
        id: firstCheckTimer
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Process {
        id: checkUpdatesProc
        command: ["bash", "-c", root.info.countCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                root.count = parseInt(text.trim()) || 0;
                root.maybeNotifySystem(root.count);
            }
        }
    }

    // --- Notify once per new state, with an "Update now" action -------------
    // State survives quickshell reloads, so an unchanged update count never
    // re-notifies. A fresh count (e.g. more updates arrived) re-notifies.
    function maybeNotifySystem(count) {
        if (!Config.ready || !Config.options.updates.notifySystemUpdates) return;
        if (count <= 0 || count === systemState.lastNotifiedCount) return;
        notifyProc.command = ["notify-send",
            "-a", "Shell",
            "-t", "600000",
            "-r", "772102",
            "-A", "update=Update now",
            `${count} system update${count === 1 ? "" : "s"} available`,
            `${root.updaterName}. "Update now" runs it in a terminal.`];
        notifyProc.running = true;
        systemState.lastNotifiedCount = count;
        systemStateWriteTimer.restart();
    }

    Process {
        id: notifyProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().toLowerCase() === "update") root.runUpdateInTerminal();
            }
        }
        onExited: (exitCode, exitStatus) => {}
    }

    // Pick a concrete update tool from Config.options.updates.systemUpdateTool.
    // "auto" prefers the distro-native tool (cachy-update on CachyOS).
    function toolCommand() {
        const tool = Config.options.updates.systemUpdateTool;
        if (tool === "cachy-update") return "cachy-update";
        if (tool === "yay") return "yay -Syu --combinedupgrade=false";
        if (tool === "paru") return "paru -Syu";
        if (tool === "pacman") return "pkexec pacman -Syu";
        if (resolvedDistro === "cachyos") return "cachy-update";
        return info.updateCmd;
    }

    function runUpdateInTerminal() {
        if (!root.canRunUpdate) return;
        const scriptPath = FileUtils.trimFileProtocol(`${Directories.scriptPath}/updates/run-system-update.sh`);
        Quickshell.execDetached(["kitty", "-e", "bash", scriptPath, root.toolCommand()]);
    }

    FileView {
        id: systemStateFile
        path: `${Directories.state}/user/system-updates.json`
        watchChanges: false
        onAdapterUpdated: systemStateWriteTimer.restart()

        JsonAdapter {
            id: systemState
            property int lastNotifiedCount: -1
        }
    }

    Timer {
        id: systemStateWriteTimer
        interval: 100
        repeat: false
        onTriggered: systemStateFile.writeAdapter()
    }
}
