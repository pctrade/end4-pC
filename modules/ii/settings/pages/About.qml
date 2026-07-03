import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true
    bottomContentPadding: 35

    property string kernelVersion: ""
    property string uptime: ""
    property string shell: ""
    property string desktop: ""
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string disk: ""
    property string updates: ""
    property string installAge: ""
    property string packages: ""

    function refresh() {
        kernelVersion = "";
        uptime = "";
        shell = "";
        desktop = "";
        cpu = "";
        gpu = "";
        memory = "";
        disk = "";
        updates = "";
        installAge = "";
        packages = "";
        kernelProcess.running = true;
        desktopProcess.running = true;
        uptimeProcess.running = true;
        shellProcess.running = true;
        cpuProcess.running = true;
        gpuProcess.running = true;
        memoryProcess.running = true;
        diskProcess.running = true;
        updatesProcess.running = true;
        installAgeProcess.running = true;
        packagesProcess.running = true;
    }

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "bash", "-c",
            "killall qs; sleep 0.5; cd ~/.config/quickshell/ && rm -rf end4-pC && git clone https://github.com/pctrade/end4-pC.git && nohup qs -c end4-pC > /tmp/qs.log 2>&1 &"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    Component.onCompleted: refresh()

    Process {
        id: desktopProcess
        command: ["bash", "-c", "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then echo 'Hyprland'; elif pgrep -x hyprland >/dev/null; then echo 'Hyprland'; else echo \"${XDG_CURRENT_DESKTOP:-Unknown}\"; fi"]
        running: false
        stdout: SplitParser {
            onRead: data => desktop = data.trim() || "Unknown"
        }
    }

    Process {
        id: kernelProcess
        command: ["uname", "-r"]
        running: false
        stdout: SplitParser {
            onRead: data => kernelVersion = data.trim()
        }
    }

    Process {
        id: installAgeProcess
        command: ["bash", "-c", "install_sec=$(stat -c %W /); if [ \"$install_sec\" -le 0 ]; then install_sec=$(stat -c %Y /); fi; now_sec=$(date +%s); age_sec=$((now_sec - install_sec)); days=$((age_sec / 86400)); echo \"$days days\""]
        running: false
        stdout: SplitParser {
            onRead: data => installAge = data.trim()
        }
    }

    Process {
        id: uptimeProcess
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        running: false
        stdout: SplitParser {
            onRead: data => uptime = data.trim()
        }
    }

    Process {
        id: shellProcess
        command: ["bash", "-c", "echo $SHELL | awk -F'/' '{print $NF}'"]
        running: false
        stdout: SplitParser {
            onRead: data => shell = data.trim()
        }
    }

    Process {
        id: cpuProcess
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2- | sed 's/^ //' | sed 's/Intel(R)/Intel®/' | sed 's/Core(TM)/Core™/' | sed 's/CPU //' | sed 's/  */ /g' | sed 's/ @ */ @/'"]
        running: false
        stdout: SplitParser {
            onRead: data => cpu = data.trim()
        }
    }

    Process {
        id: gpuProcess
        command: ["bash", "-c", "glxinfo | grep 'renderer string' | grep -o 'Intel(R) HD Graphics [0-9]\\{4\\}' | sed 's/Intel(R)/Intel®/' || lspci | grep -i 'vga\\|3d\\|display' | cut -d':' -f3 | xargs"]
        running: false
        stdout: SplitParser {
            onRead: data => gpu = data.trim()
        }
    }

    Process {
        id: memoryProcess
        command: ["bash", "-c", "free -h | awk '/^Mem:/ {print $3 \" / \" $2}'"]
        running: false
        stdout: SplitParser {
            onRead: data => memory = data.trim()
        }
    }

    Process {
        id: diskProcess
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $3 \" / \" $2}'"]
        running: false
        stdout: SplitParser {
            onRead: data => disk = data.trim()
        }
    }

    Process {
        id: updatesProcess
        command: ["bash", "-c", "pacman_updates=$(checkupdates 2>/dev/null | wc -l); aur_updates=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0); total=$((pacman_updates + aur_updates)); if [ $total -eq 0 ]; then echo 'Up to date'; else echo \"$pacman_updates official, $aur_updates AUR\"; fi"]
        running: false
        stdout: SplitParser {
            onRead: data => updates = data.trim()
        }
    }

    Process {
        id: packagesProcess
        command: ["bash", "-c", "pacman_count=$(pacman -Q | wc -l); flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo 0); if [ \"$flatpak_count\" -gt 0 ]; then echo \"$pacman_count pacman, $flatpak_count fp\"; else echo \"$pacman_count pacman\"; fi"]
        running: false
        stdout: SplitParser {
            onRead: data => packages = data.trim()
        }
    }
    
    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 55
        spacing: 16

        IconImage {
            implicitWidth: 134
            implicitHeight: 134
            source: Quickshell.iconPath(SystemInfo.logo)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledText {
                text: SystemInfo.distroName
                font.pixelSize: Appearance.font.pixelSize.hugeass
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
            }

            StyledText {
                text: "Kernel " + (kernelVersion || "Loading...")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            Item {
                implicitWidth: colorRow.implicitWidth
                implicitHeight: 24

                Row {
                    id: colorRow
                    spacing: -8

                    Repeater {
                        model: [
                            Appearance.m3colors.m3primary,
                            Appearance.m3colors.m3secondary,
                            Appearance.m3colors.m3tertiary,
                            Appearance.m3colors.m3error,
                            Appearance.m3colors.m3primaryContainer,
                            Appearance.m3colors.m3secondaryContainer,
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 24
                            height: 24
                            radius: width / 2
                            color: modelData
                            z: index
                            border.width: 2
                            border.color: Appearance.colors.colLayer1
                        }
                    }
                }
            }
        }

        Rectangle {
            height: 110
            width: 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Appearance.colors.colOutline }
                GradientStop { position: 0.8; color: Appearance.colors.colOutline }
                GradientStop { position: 1.0; color: "transparent" }
            }
            opacity: 0.15
        }

        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            FloatingActionButton {
                iconText: "circles"
                buttonText: Translation.tr("Update Dots")
                expanded: false
                downAction: () => runUpdateDots()
                StyledToolTip {
                    text: Translation.tr("Update Shell to the latest version")
                }
            }

            FloatingActionButton {
                iconText: "deployed_code_update"
                buttonText: Translation.tr("Update System")
                expanded: false
                downAction: () => runSystemUpdate()
                StyledToolTip {
                    text: Translation.tr("Update your system packages")
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AboutCard {
                icon: "planner_review"
                label: "CPU"
                value: cpu || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Pentagon
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "monitor"
                label: "GPU"
                value: gpu || "sudo pacman -S mesa-utils"
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.ClamShell
                Layout.fillWidth: true
            }
        }

        GridLayout {
            columns: 3
            Layout.fillWidth: true
            rowSpacing: 8
            columnSpacing: 8

            AboutCard {
                icon: "memory"
                label: "Memory"
                value: memory || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Clover4Leaf
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "storage"
                label: "Disk"
                value: disk || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Cookie6Sided
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "terminal"
                label: "Shell"
                value: shell || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Gem
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "package_2"
                label: "Packages"
                value: packages || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Flower
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "update"
                label: "Updates"
                value: updates || "Checking..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.SoftBurst
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "timelapse"
                label: "Uptime"
                value: DateTime.uptime || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Sunny
                Layout.fillWidth: true
            }
        }
    }
}