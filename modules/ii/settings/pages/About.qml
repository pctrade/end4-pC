import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

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
        GlobalStates.settingsOpen = false
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
    }

    function runUpdateDots() {
        GlobalStates.settingsOpen = false
        Quickshell.execDetached([
            "kitty", "--hold",
            "bash", "-c",
            "cd ~/.config/quickshell/ && rm -rf end4-pC && git clone https://github.com/pctrade/end4-pC.git && killall qs; nohup qs -c end4-pC > /tmp/qs.log 2>&1 &"
        ])
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
        command: ["bash", "-c", "pacman_count=$(pacman -Q | wc -l); flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo 0); echo \"$pacman_count pacman, $flatpak_count flatpak\""]
        running: false
        stdout: SplitParser {
            onRead: data => packages = data.trim()
        }
    }

    ContentSection {
        Layout.fillWidth: true
        Layout.topMargin: 50

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 20

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: contentRow.implicitHeight + 40
                radius: Appearance.rounding.cardRounding
                color: "transparent"

                RowLayout {
                    id: contentRow
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 40

                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 240
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 40
                        Layout.leftMargin: -40
                        Layout.rightMargin: 60
                        radius: 90
                        color: "transparent"

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 240
                            source: Quickshell.iconPath(SystemInfo.logo)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: "transparent"

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: -10

                                StyledText {
                                    text: SystemInfo.distroName
                                    font.pixelSize: Appearance.font.pixelSize.display
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurface
                                }

                                StyledText {
                                    text: "Kernel " + (kernelVersion || "Loading...")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnSurface
                                    opacity: 0.7
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.topMargin: 10
                            color: Appearance.colors.colOnSurface
                            opacity: 0.1
                        }

                        SystemInfoRow { label: Translation.tr("System Age  •"); value: installAge || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Desktop  •"); value: desktop || "Loading..." }
                        SystemInfoRow { label: Translation.tr("CPU  •"); value: cpu || "Loading..." }
                        SystemInfoRow { label: Translation.tr("GPU •"); value: gpu || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Memory  •"); value: memory || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Disk  •"); value: disk || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Packages  •"); value: packages || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Updates  •"); value: updates || "Checking..." }
                        SystemInfoRow { label: Translation.tr("Shell  •"); value: shell || "Loading..." }
                        SystemInfoRow { label: Translation.tr("Uptime  •"); value: uptime || "Loading..." }
                    }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                Layout.topMargin: 20

                SelectionGroupButton {
                    leftmost: true
                    rightmost: false
                    buttonIcon: "app_badging"
                    buttonText: Translation.tr("Update Dots")
                    toggled: false
                    onClicked: runUpdateDots()
                }

                SelectionGroupButton {
                    leftmost: false
                    rightmost: true
                    buttonIcon: "deployed_code_update"
                    buttonText: Translation.tr("Update System")
                    toggled: false
                    onClicked: runSystemUpdate()
                }
            }
        }
    }

    component SystemInfoRow: Rectangle {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 25
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 12

            StyledText {
                Layout.preferredWidth: 40
                text: parent.parent.label
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
                opacity: 0.7
                horizontalAlignment: Text.AlignRight
            }

            StyledText {
                Layout.fillWidth: true
                text: parent.parent.value
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }
}