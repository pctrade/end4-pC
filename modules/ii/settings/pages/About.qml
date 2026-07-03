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
                text: "Kernel " + (SystemInfo.kernelVersion || "Loading...")
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
                value: SystemInfo.cpu || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Pentagon
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "monitor"
                label: "GPU"
                value: SystemInfo.gpu || "sudo pacman -S mesa-utils"
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
                value: SystemInfo.memory || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Clover4Leaf
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "storage"
                label: "Disk"
                value: SystemInfo.disk || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Cookie6Sided
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "terminal"
                label: "Shell"
                value: SystemInfo.shell || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Gem
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "package_2"
                label: "Packages"
                value: SystemInfo.packages || "Loading..."
                iconColor: Appearance.colors.colPrimary
                iconShape: MaterialShape.Shape.Flower
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "update"
                label: "Updates"
                value: Updates.checking ? "Checking..." : (Updates.count === 0 ? "Up to date" : `${Updates.count}`)
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