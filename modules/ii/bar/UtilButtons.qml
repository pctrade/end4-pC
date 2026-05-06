import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : pill.implicitWidth
    implicitHeight: vertical ? pill.implicitHeight : Appearance.sizes.barHeight

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: isMaterial ? Appearance.colors.colPrimaryContainer : "transparent"
        radius: Appearance.rounding.full
        implicitWidth: isMaterial && !root.vertical ? flow.implicitWidth + 10 : root.vertical ? Appearance.sizes.verticalBarWidth - 10 : flow.implicitWidth + 4
        implicitHeight: isMaterial && root.vertical ? flow.implicitHeight + 10 : isMaterial ? 30 : root.vertical ? flow.implicitHeight + 4 : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.easing
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.easing
            }
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: isMaterial ? 2 : 4

            Loader {
                active: Config.options.bar.utilButtons.showScreenSnip
                visible: active
                sourceComponent: isMaterial ? utilButtonM3.createObject(this, {
                    iconText: "screenshot_region",
                    onClicked: () => Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
                }) : legacyScreenSnip
            }
            Component {
                id: legacyScreenSnip
                CircleUtilButton {
                    onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1; text: "screenshot_region"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showColorPicker
                visible: active
                sourceComponent: isMaterial ? colorPickerM3 : legacyColorPicker
            }
            Component {
                id: colorPickerM3
                UtilButton {
                    iconText: "colorize"
                    onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                }
            }
            Component {
                id: legacyColorPicker
                CircleUtilButton {
                    onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1; text: "colorize"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showScreenRecord
                visible: active
                sourceComponent: isMaterial ? screenRecordM3 : legacyScreenRecord
            }

            Component {
                id: legacyScreenRecord
                Item {
                    id: recordingItem
                    implicitWidth: btn.implicitWidth + timerRevealer.implicitWidth
                    implicitHeight: btn.implicitHeight

                    property bool isRecording: Config.options.bar.utilButtons.isRecording
                    property int elapsedSeconds: 0

                    onIsRecordingChanged: {
                        if (!isRecording) elapsedSeconds = 0
                    }

                    function formatTime(s) {
                        return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
                    }

                    Timer {
                        interval: 1000
                        repeat: true
                        running: recordingItem.isRecording
                        onTriggered: recordingItem.elapsedSeconds++
                    }

                    CircleUtilButton {
                        id: btn
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        colBackground: recordingItem.isRecording ? Appearance.colors.colPrimaryContainer : "transparent"
                        buttonRadius: recordingItem.isRecording ? Appearance.rounding.normal : implicitHeight / 2
                        onClicked: Quickshell.execDetached([Directories.recordScriptPath])

                        Behavior on colBackground { ColorAnimation { duration: 200 } }
                        Behavior on buttonRadius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        MaterialSymbol {
                            horizontalAlignment: Qt.AlignHCenter
                            fill: 1
                            text: recordingItem.isRecording ? "stop_circle" : "screen_record"
                            iconSize: Appearance.font.pixelSize.large
                            color: recordingItem.isRecording ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Revealer {
                        id: timerRevealer
                        anchors.left: btn.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: btn.verticalCenter
                        reveal: recordingItem.isRecording

                        StyledText {
                            width: implicitWidth
                            text: recordingItem.formatTime(recordingItem.elapsedSeconds)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            font.letterSpacing: -0.3
                            color: Appearance.colors.colOnLayer2
                            rightPadding: 8
                            Component.onCompleted: width = implicitWidth
                        }
                    }
                }
            }

            Component {
                id: screenRecordM3
                UtilButton {
                    iconText: Config.options.bar.utilButtons.isRecording ? "stop_circle" : "screen_record"
                    forceHovered: Config.options.bar.utilButtons.isRecording
                    onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showKeyboardToggle
                visible: active
                sourceComponent: isMaterial ? keyboardM3 : legacyKeyboard
            }
            Component {
                id: keyboardM3
                UtilButton {
                    iconText: "keyboard"
                    onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                }
            }
            Component {
                id: legacyKeyboard
                CircleUtilButton {
                    onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0; text: "keyboard"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showWallpaperToggle
                visible: active
                sourceComponent: isMaterial ? wallpaperM3 : legacyWallpaper
            }
            Component {
                id: wallpaperM3
                UtilButton {
                    iconText: "imagesmode"
                    onClicked: GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
                }
            }
            Component {
                id: legacyWallpaper
                CircleUtilButton {
                    onClicked: GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0; text: "imagesmode"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showMicToggle
                visible: active
                sourceComponent: isMaterial ? micM3 : legacyMic
            }
            Component {
                id: micM3
                UtilButton {
                    iconText: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                    onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                }
            }
            Component {
                id: legacyMic
                CircleUtilButton {
                    onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showDarkModeToggle
                visible: active
                sourceComponent: isMaterial ? darkModeM3 : legacyDarkMode
            }
            Component {
                id: darkModeM3
                UtilButton {
                    iconText: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    onClicked: (e) => {
                        if (Appearance.m3colors.darkmode)
                            Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`);
                        else
                            Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`);
                    }
                }
            }
            Component {
                id: legacyDarkMode
                CircleUtilButton {
                    onClicked: (e) => {
                        if (Appearance.m3colors.darkmode)
                            Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`);
                        else
                            Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`);
                    }
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            Loader {
                active: Config.options.bar.utilButtons.showPerformanceProfileToggle
                visible: active
                sourceComponent: isMaterial ? perfM3 : legacyPerf
            }
            Component {
                id: perfM3
                UtilButton {
                    iconText: switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "airwave"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    onClicked: (e) => {
                        if (PowerProfiles.hasPerformanceProfile) {
                            switch(PowerProfiles.profile) {
                                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
                            }
                        } else {
                            PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                        }
                    }
                }
            }
            Component {
                id: legacyPerf
                CircleUtilButton {
                    onClicked: (e) => {
                        if (PowerProfiles.hasPerformanceProfile) {
                            switch(PowerProfiles.profile) {
                                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
                            }
                        } else {
                            PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                        }
                    }
                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: return "energy_savings_leaf"
                            case PowerProfile.Balanced: return "airwave"
                            case PowerProfile.Performance: return "local_fire_department"
                        }
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }
    }
}