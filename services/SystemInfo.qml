pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: ""
    property string username: "user"
    property string hostname: ""
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: ""
    property string windowingSystem: ""
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string disk: ""
    property string shell: ""
    property string packages: ""
    property string installAge: ""
    property string kernelVersion: ""

    function refresh() {
        getCpu.running = false;       getCpu.running = true
        getGpu.running = false;       getGpu.running = true
        getMemory.running = false;    getMemory.running = true
        getDisk.running = false;      getDisk.running = true
        getShell.running = false;     getShell.running = true
        getPackages.running = false;  getPackages.running = true
        getInstallAge.running = false; getInstallAge.running = true
        getKernel.running = false; getKernel.running = true
    }

    function refreshHostname() {
        getHostname.running = false
        getHostname.running = true
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            getUsername.running = true
            getHostname.running = true
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
            const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            const idMatch = textOsRelease.match(/^ID="?(.+?)"?$/m)
            distroId = idMatch ? idMatch[1] : "unknown"

            const homeUrlMatch = textOsRelease.match(/^HOME_URL="(.+?)"/m)
            homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
            const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL="(.+?)"/m)
            documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
            const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL="(.+?)"/m)
            supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
            const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL="(.+?)"/m)
            bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
            const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL="(.+?)"/m)
            privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
            const logoFieldMatch = textOsRelease.match(/^LOGO="?(.+?)"?$/m)
            logo = logoFieldMatch ? logoFieldMatch[1] : ""

            switch (distroId) {
                case "artix":
                case "arch":        distroIcon = "arch-symbolic"; break
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break
                case "cachyos":     distroIcon = "cachyos-symbolic"; break
                case "nixos":       distroIcon = "nixos-symbolic"; break
                case "fedora":      distroIcon = "fedora-symbolic"; break
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos":       distroIcon = "ubuntu-symbolic"; break
                case "debian":
                case "raspbian":
                case "kali":        distroIcon = "debian-symbolic"; break
                case "funtoo":
                case "gentoo":      distroIcon = "gentoo-symbolic"; break
                default:            distroIcon = "arch-symbolic"; break
            }
            if (textOsRelease.toLowerCase().includes("nyarch"))
                distroIcon = "nyarch-symbolic"

            if (logo.trim().length === 0)
                logo = distroIcon
        }
    }

    Process {
        id: getUsername
        command: ["whoami"]
        stdout: SplitParser { onRead: data => root.username = data.trim() }
    }

    Process {
        id: getHostname
        command: ["cat", "/etc/hostname"]
        stdout: SplitParser { onRead: data => root.hostname = data.trim() }
    }

    Process {
        id: getDesktopEnvironment
        running: true
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP,$WAYLAND_DISPLAY"]
        stdout: StdioCollector {
            id: deCollector
            onStreamFinished: {
                const [desktop, wayland] = deCollector.text.split(",")
                root.desktopEnvironment = desktop.trim()
                root.windowingSystem = wayland.trim().length > 0 ? "Wayland" : "X11"
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }

    Process {
        id: getKernel
        running: false
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: data => root.kernelVersion = data.trim() }
    }

    Process {
        id: getCpu
        running: false
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2- | sed 's/^ //' | sed 's/Intel(R)/Intel®/' | sed 's/Core(TM)/Core™/' | sed 's/CPU //' | sed 's/  */ /g' | sed 's/ @ */ @/'"]
        stdout: SplitParser { onRead: data => root.cpu = data.trim() }
    }

    Process {
        id: getGpu
        running: false
        command: ["bash", "-c", `
            gpu=$(glxinfo 2>/dev/null | grep 'renderer string' | grep -o 'Intel(R) HD Graphics [0-9]\\{4\\}' | sed 's/Intel(R)/Intel®/')
            if [ -z "$gpu" ]; then
                gpu=$(lspci | grep -iE 'vga|3d|display' | head -1 | sed -E '
                    s/.*: //;
                    s/\\(rev [0-9a-f]+\\)//;
                    s/Advanced Micro Devices, Inc\\. \\[AMD\\/ATI\\]//;
                    s/NVIDIA Corporation//;
                    s/Intel Corporation//;
                    s/.*\\[([^]]+)\\]$/\\1/;
                    s/^ *//;
                    s/ *$//
                ')
            fi
            echo "$gpu"
        `]
        stdout: SplitParser { onRead: data => root.gpu = data.trim() }
    }

    Process {
        id: getMemory
        running: false
        command: ["bash", "-c", "LC_ALL=C free -h | awk '/^Mem:/ {print $3 \" / \" $2}'"]
        stdout: SplitParser { onRead: data => root.memory = data.trim() }
    }

    Process {
        id: getDisk
        running: false
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $3 \" / \" $2}'"]
        stdout: SplitParser { onRead: data => root.disk = data.trim() }
    }

    Process {
        id: getShell
        running: false
        command: ["bash", "-c", "echo $SHELL | awk -F'/' '{print $NF}'"]
        stdout: SplitParser { onRead: data => root.shell = data.trim() }
    }

    Process {
        id: getPackages
        running: false
        command: ["bash", "-c", "pacman_count=$(pacman -Q | wc -l); flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo 0); if [ \"$flatpak_count\" -gt 0 ]; then echo \"$pacman_count pacman, $flatpak_count fp\"; else echo \"$pacman_count pacman\"; fi"]
        stdout: SplitParser { onRead: data => root.packages = data.trim() }
    }

    Process {
        id: getInstallAge
        running: false
        command: ["bash", "-c", "install_sec=$(stat -c %W /); if [ \"$install_sec\" -le 0 ]; then install_sec=$(stat -c %Y /); fi; now_sec=$(date +%s); age_sec=$((now_sec - install_sec)); days=$((age_sec / 86400)); echo \"$days days\""]
        stdout: SplitParser { onRead: data => root.installAge = data.trim() }
    }
}