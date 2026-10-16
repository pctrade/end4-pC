import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    
    Process {
        id: translationProc
        property string locale: ""
        command: [Directories.aiTranslationScriptPath, translationProc.locale]
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "palette"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("System Appearance")

            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "category"
                    text: Translation.tr("Icon theme")
                    fieldWidth: 260
                    fixedWidth: true
                    searchable: true
                    model: SystemAppearance.toOptions(SystemAppearance.iconThemes)
                    currentValue: SystemAppearance.iconTheme
                    onSelected: newValue => SystemAppearance.setIcons(newValue)
                }
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "mouse"
                    text: Translation.tr("Cursor theme")
                    fieldWidth: 260
                    fixedWidth: true
                    searchable: true
                    model: SystemAppearance.toOptions(SystemAppearance.cursorThemes)
                    currentValue: SystemAppearance.cursorTheme
                    onSelected: newValue => SystemAppearance.setCursor(newValue, SystemAppearance.cursorSize)
                }
                ConfigSpinBox {
                    icon: "ads_click"
                    text: Translation.tr("Cursor size")
                    value: SystemAppearance.cursorSize
                    from: 16
                    to: 64
                    stepSize: 2
                    onValueChanged: {
                        if (value !== SystemAppearance.cursorSize) SystemAppearance.setCursor(SystemAppearance.cursorTheme, value)
                    }
                }
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "text_fields"
                    text: Translation.tr("System font")
                    fieldWidth: 260
                    fixedWidth: true
                    searchable: true
                    model: SystemAppearance.toOptions(SystemAppearance.fonts)
                    currentValue: SystemAppearance.fontFamily
                    onSelected: newValue => SystemAppearance.setFont("ui", newValue, SystemAppearance.fontSize)
                }
                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("System font size")
                    value: SystemAppearance.fontSize
                    from: 8
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        if (value !== SystemAppearance.fontSize) SystemAppearance.setFont("ui", SystemAppearance.fontFamily, value)
                    }
                }
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "terminal"
                    text: Translation.tr("Monospace font")
                    fieldWidth: 260
                    fixedWidth: true
                    searchable: true
                    model: SystemAppearance.toOptions(SystemAppearance.fonts)
                    currentValue: SystemAppearance.monoFamily
                    onSelected: newValue => SystemAppearance.setFont("mono", newValue, SystemAppearance.monoSize)
                }
                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Monospace font size")
                    value: SystemAppearance.monoSize
                    from: 8
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        if (value !== SystemAppearance.monoSize) SystemAppearance.setFont("mono", SystemAppearance.monoFamily, value)
                    }
                }
            }
        }

        ContentSection {
            icon: "nest_clock_farsight_analog"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Time")

            Rectangle {
                id: previewCard
                Layout.fillWidth: true
                implicitHeight: 180
                radius: Appearance.rounding.normal
                clip: true

                gradient: Gradient { // I didn't like how it turned out but in case I regret it 
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Appearance.colors.colLayer1  }
                    GradientStop { position: 0.6; color: Appearance.colors.colLayer1  }
                    GradientStop { position: 1.0; color: Appearance.colors.colLayer1  }
                }

                property date now: new Date()

                Timer {
                    interval: Config.options.time.secondPrecision ? 1000 : 15000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: previewCard.now = new Date()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    ColumnLayout {
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Appearance.font.family.expressive
                            font.pixelSize: 42
                            font.letterSpacing: 1
                            font.features: { "tnum": 1 }
                            font.weight: Font.Medium
                            color: Appearance.colors.colPrimary
                            text: {
                                const fmt = Config.options.time.format;
                                if (Config.options.time.secondPrecision) {
                                    if (fmt === "hh:mm") return Qt.formatTime(previewCard.now, "hh:mm:ss");
                                    if (fmt === "h:mm ap") return Qt.formatTime(previewCard.now, "h:mm:ss ap");
                                    if (fmt === "h:mm AP") return Qt.formatTime(previewCard.now, "h:mm:ss AP");
                                }
                                return Qt.formatTime(previewCard.now, fmt);
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: DateTime.longDate
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 32
                            font.weight: Font.Normal
                            opacity: 0.6
                            color: Appearance.colors.colPrimary
                        }
                    }

                    AndroidClock {
                        Layout.rightMargin: 6
                        width: 130
                        height: 130
                        backgroundColor: Appearance.colors.colPrimaryContainer
                        handColor:       Appearance.colors.colPrimary
                        centerDotColor:  Appearance.colors.colPrimary
                    }
                }
            }

            GroupedList {
                Layout.topMargin: -2
                ConfigSelectionArray {
                    text: Translation.tr("Format")
                    icon: "schedule"
                    currentValue: Config.options.time.format
                    onSelected: newValue => {
                        if (newValue === "hh:mm") {
                            Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                        }
                        Config.options.time.format = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("24h"), value: "hh:mm" },
                        { displayName: Translation.tr("12h am/pm"), value: "h:mm ap" },
                        { displayName: Translation.tr("12h AM/PM"), value: "h:mm AP" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "pace"
                    text: Translation.tr("Second precision")
                    checked: Config.options.time.secondPrecision
                    onCheckedChanged: {
                        Config.options.time.secondPrecision = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "date_range"
                    text: Translation.tr("Show date")
                    checked: Config.options.time.showDate
                    onCheckedChanged: {
                        Config.options.time.showDate = checked;
                    }
                }
                ConfigTextArea {
                    Layout.fillWidth: true
                    buttonIcon: "scoreboard"
                    text: Translation.tr("Clock String Format")
                    placeholderText: Translation.tr("Clock String Format")
                    value: Config.options.time.format
                    onValueChanged: {
                        Config.options.time.format = value;
                    }
                }
                
                ConfigTextArea {
                    Layout.fillWidth: true
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Date String Format")
                    placeholderText: Translation.tr("Date String Format")
                    value: Config .options.time.dateFormat
                    onValueChanged: {
                        Config.options.time.dateFormat = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "mouse"
            shape: MaterialShape.Shape.Cookie7Sided
            title: Translation.tr("Device batteries")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "warning"
                        text: Translation.tr("Low warning")
                        value: Config.options.battery.peripheralLow
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.peripheralLow = value;
                        }
                    }
                    ConfigSpinBox {
                        icon: "dangerous"
                        text: Translation.tr("Critical warning")
                        value: Config.options.battery.peripheralCritical
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.peripheralCritical = value;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "notifications"
                    text: Translation.tr("Notify when a device battery is low")
                    checked: Config.options.battery.peripheralNotify
                    onCheckedChanged: {
                        Config.options.battery.peripheralNotify = checked;
                    }
                }
            }
        }

        ContentSection {
            icon: "battery_android_full"
            shape: MaterialShape.Shape.SemiCircle
            title: Translation.tr("Battery")
            visible: Battery.available

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "warning"
                        text: Translation.tr("Low warning")
                        value: Config.options.battery.low
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.low = value;
                        }
                    }
                    ConfigSpinBox {
                        icon: "dangerous"
                        text: Translation.tr("Critical warning")
                        value: Config.options.battery.critical
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.critical = value;
                        }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "pause"
                        text: Translation.tr("Automatic suspend")
                        checked: Config.options.battery.automaticSuspend
                        onCheckedChanged: {
                            Config.options.battery.automaticSuspend = checked;
                        }
                    }
                    ConfigSpinBox {
                        enabled: Config.options.battery.automaticSuspend
                        text: Translation.tr("at")
                        value: Config.options.battery.suspend
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.suspend = value;
                        }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "charger"
                        text: Translation.tr("Full warning")
                        value: Config.options.battery.full
                        from: 0
                        to: 101
                        stepSize: 5
                        onValueChanged: {
                            Config.options.battery.full = value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "volume_up"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Audio")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "hearing"
                    text: Translation.tr("Earbang protection")
                    checked: Config.options.audio.protection.enable
                    onCheckedChanged: {
                        Config.options.audio.protection.enable = checked;
                    }
                }
                ConfigRow {
                    enabled: Config.options.audio.protection.enable
                    ConfigSpinBox {
                        icon: "arrow_warm_up"
                        text: Translation.tr("Max allowed increase")
                        value: Config.options.audio.protection.maxAllowedIncrease
                        from: 0
                        to: 100
                        stepSize: 2
                        onValueChanged: {
                            Config.options.audio.protection.maxAllowedIncrease = value;
                        }
                    }
                    ConfigSpinBox {
                        icon: "vertical_align_top"
                        text: Translation.tr("Volume limit")
                        value: Config.options.audio.protection.maxAllowed
                        from: 0
                        to: 154 // pavucontrol allows up to 153%
                        stepSize: 2
                        onValueChanged: {
                            Config.options.audio.protection.maxAllowed = value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "notification_sound"
            shape: MaterialShape.Shape.Clover8Leaf
            title: Translation.tr("Sounds")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "battery_android_full"
                    text: Translation.tr("Battery")
                    enabled: Battery.available
                    checked: Config.options.sounds.battery
                    onCheckedChanged: {
                        Config.options.sounds.battery = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "av_timer"
                    text: Translation.tr("Pomodoro")
                    checked: Config.options.sounds.pomodoro
                    onCheckedChanged: {
                        Config.options.sounds.pomodoro = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Football")
                visible: Config.options.sidebar.football.enable

                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "notifications_active"
                        text: Translation.tr("Live alerts")
                        checked: Config.options.sidebar.football.alerts
                        onCheckedChanged: { Config.options.sidebar.football.alerts = checked }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Alerts for")
                        icon: "filter_alt"
                        currentValue: Config.options.sidebar.football.alertsScope
                        onSelected: newValue => { Config.options.sidebar.football.alertsScope = newValue }
                        options: [
                            { displayName: Translation.tr("My parlay"), icon: "layers", value: "parlay" },
                            { displayName: Translation.tr("All matches"), icon: "public", value: "all" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "campaign"
                        text: Translation.tr("Goal sound")
                        checked: Config.options.sidebar.football.goalSound
                        onCheckedChanged: { Config.options.sidebar.football.goalSound = checked }
                    }
                    ConfigTextArea {
                        id: goalFileField
                        Layout.fillWidth: true
                        fieldWidth: 320
                        buttonIcon: "audio_file"
                        text: Translation.tr("Goal sound file (empty = default)")
                        placeholderText: "~/Music/goal.ogg"
                        value: Config.options.sidebar.football.goalSoundPath
                        onValueChanged: goalFileTimer.restart()

                        Timer {
                            id: goalFileTimer
                            interval: 600
                            onTriggered: Config.options.sidebar.football.goalSoundPath = goalFileField.value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "flag"
                        text: Translation.tr("Corner sound")
                        checked: Config.options.sidebar.football.cornerSound
                        onCheckedChanged: { Config.options.sidebar.football.cornerSound = checked }
                    }
                    ConfigTextArea {
                        id: cornerFileField
                        Layout.fillWidth: true
                        fieldWidth: 320
                        buttonIcon: "audio_file"
                        text: Translation.tr("Corner sound file (empty = default)")
                        placeholderText: "~/Music/corner.ogg"
                        value: Config.options.sidebar.football.cornerSoundPath
                        onValueChanged: cornerFileTimer.restart()

                        Timer {
                            id: cornerFileTimer
                            interval: 600
                            onTriggered: Config.options.sidebar.football.cornerSoundPath = cornerFileField.value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "notifications"
                        text: Translation.tr("Goal notifications")
                        checked: Config.options.sidebar.football.notify
                        onCheckedChanged: { Config.options.sidebar.football.notify = checked }
                    }
                    ConfigSpinBox {
                        icon: "volume_up"
                        text: Translation.tr("Sound volume")
                        value: Config.options.sidebar.football.soundVolume
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: { Config.options.sidebar.football.soundVolume = value }
                    }
                }
            }
        }

        ContentSection {
            icon: "language_japanese_kana"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Language")

            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "language"
                    text: Translation.tr("Interface Language")
                    fieldWidth: 240
                    model: [
                        { displayName: Translation.tr("Auto (System)"), value: "auto" },
                        ...Translation.allAvailableLanguages.map(lang => ({ displayName: lang, value: lang }))
                    ]
                    currentValue: Config.options.language.ui
                    onSelected: newValue => {
                        Config.options.language.ui = newValue;
                    }
                }

                ColumnLayout {
                    id: translationCol
                    Layout.fillWidth: true
                    spacing: 8

                    ConfigTextArea {
                        id: localeField
                        Layout.fillWidth: true
                        buttonIcon: "translate"
                        text: Translation.tr("Locale code")
                        placeholderText: Translation.tr("e.g. fr_FR, de_DE, zh_CN...")
                        value: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui
                    }

                    RippleButtonWithIcon {
                        id: generateTranslationBtn
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 50
                        Layout.rightMargin: 8
                        nerdIcon: ""
                        enabled: !translationProc.running || (translationProc.locale !== localeField.value.trim())
                        mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                        onClicked: {
                            translationProc.locale = localeField.value.trim();
                            translationProc.running = false;
                            translationProc.running = true;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "work_alert"
            shape: MaterialShape.Shape.PuffyDiamond
            title: Translation.tr("Work safety")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "assignment"
                    text: Translation.tr("Hide clipboard images copied from sussy sources")
                    checked: Config.options.workSafety.enable.clipboard
                    onCheckedChanged: {
                        Config.options.workSafety.enable.clipboard = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "wallpaper"
                    text: Translation.tr("Hide sussy/anime wallpapers")
                    checked: Config.options.workSafety.enable.wallpaper
                    onCheckedChanged: {
                        Config.options.workSafety.enable.wallpaper = checked;
                    }
                }
            }
        }
    }
}
