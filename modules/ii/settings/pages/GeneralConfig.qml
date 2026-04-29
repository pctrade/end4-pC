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

    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }

            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }
    
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
            icon: "volume_up"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Audio")

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

        ContentSection {
            icon: "battery_android_full"
            shape: MaterialShape.Shape.SemiCircle
            title: Translation.tr("Battery")

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
                uniform: false
                Layout.fillWidth: false
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

        ContentSection {
            icon: "splitscreen_left"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Left Sidebar")

            ConfigRow {

                // AI policy
                ColumnLayout {
                    ContentSubsectionLabel {
                        text: Translation.tr("AI")
                    }

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.ai
                        onSelected: newValue => {
                            Config.options.policies.ai = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("No"),
                                icon: "close",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Yes"),
                                icon: "check",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("Local only"),
                                icon: "sync_saved_locally",
                                value: 2
                            }
                        ]
                    }
                }

                // Weeb policy
                ColumnLayout {

                    ContentSubsectionLabel {
                        text: Translation.tr("Weeb")
                    }

                    ConfigSelectionArray {
                        currentValue: Config.options.policies.weeb
                        onSelected: newValue => {
                            Config.options.policies.weeb = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("No"),
                                icon: "close",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Yes"),
                                icon: "check",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("Closet"),
                                icon: "ev_shadow",
                                value: 2
                            }
                        ]
                    }
                }
            }

            // Wallpapers
            ColumnLayout {
                Layout.topMargin: 15
                ContentSubsectionLabel {
                    text: Translation.tr("Online Wallpapers")
                }

                ConfigSwitch {
                    buttonIcon: "panorama"
                    text: Translation.tr('Enabled')
                    checked: Config.options.sidebar.wallpapers.enable
                    onCheckedChanged: {
                        Config.options.sidebar.wallpapers.enable = checked;
                    }
                }
            }

            ColumnLayout {

                ContentSubsectionLabel {
                    text: Translation.tr("Translator")
                }

                ConfigSwitch {
                    buttonIcon: "translate"
                    text: Translation.tr('Enable translator')
                    checked: Config.options.sidebar.translator.enable
                    onCheckedChanged: {
                        Config.options.sidebar.translator.enable = checked;
                    }
                }
            }

            // Media
            ColumnLayout {

                ContentSubsectionLabel {
                    text: Translation.tr("Media Player")
                }

                ConfigSwitch {
                    buttonIcon: "music_note_2"
                    text: Translation.tr('Enabled')
                    checked: Config.options.sidebar.media.enable
                    onCheckedChanged: {
                        Config.options.sidebar.media.enable = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "radio_button_partial"
                    text: Translation.tr('Follow Album Colors')
                    checked: Config.options.sidebar.media.artColors
                    onCheckedChanged: {
                        Config.options.sidebar.media.artColors = checked;
                    }
                }
            }
        }

        ContentSection {
            icon: "splitscreen_right"
            shape: MaterialShape.Shape.Slanted
            title: Translation.tr("Right Sidebar")

            ConfigSwitch {
                buttonIcon: "memory"
                text: Translation.tr('Keep right sidebar loaded')
                checked: Config.options.sidebar.keepRightSidebarLoaded
                onCheckedChanged: {
                    Config.options.sidebar.keepRightSidebarLoaded = checked;
                }
            }

            ContentSubsection {
                title: Translation.tr("Quick toggles")

                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.sidebar.quickToggles.style
                    onSelected: newValue => {
                        Config.options.sidebar.quickToggles.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "password_2",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Android"),
                            icon: "action_key",
                            value: "android"
                        }
                    ]
                }

                ConfigSpinBox {
                    enabled: Config.options.sidebar.quickToggles.style === "android"
                    icon: "add_column_left"
                    text: Translation.tr("Columns")
                    value: Config.options.sidebar.quickToggles.android.columns
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.quickToggles.android.columns = value;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Sliders")

                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.quickSliders.enable
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.enable = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "brightness_6"
                    text: Translation.tr("Brightness")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showBrightness
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showBrightness = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "volume_up"
                    text: Translation.tr("Volume")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showVolume
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showVolume = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Microphone")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showMic
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showMic = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Corner open")
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.sidebar.cornerOpen.enable
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.enable = checked;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "highlight_mouse_cursor"
                    text: Translation.tr("Hover to trigger")
                    checked: Config.options.sidebar.cornerOpen.clickless
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.clickless = checked;
                    }
                }
                Row {
                    ConfigSwitch {
                        enabled: !Config.options.sidebar.cornerOpen.clickless
                        text: Translation.tr("Force hover open at absolute corner")
                        checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked;
                        }
                    }
                    ConfigSpinBox {
                        icon: "arrow_cool_down"
                        text: Translation.tr("con desplazamiento vertical")
                        value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                        from: 0
                        to: 20
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value;
                        }
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "vertical_align_bottom"
                        text: Translation.tr("Place at bottom")
                        checked: Config.options.sidebar.cornerOpen.bottom
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.bottom = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "unfold_more_double"
                        text: Translation.tr("Value scroll")
                        checked: Config.options.sidebar.cornerOpen.valueScroll
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.valueScroll = checked;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Visualize region")
                    checked: Config.options.sidebar.cornerOpen.visualize
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.visualize = checked;
                    }
                }
                ConfigRow {
                    ConfigSpinBox {
                        icon: "arrow_range"
                        text: Translation.tr("Region width")
                        value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.cornerRegionWidth = value;
                        }
                    }
                    ConfigSpinBox {
                        icon: "height"
                        text: Translation.tr("Region height")
                        value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.cornerRegionHeight = value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "notification_sound"
            shape: MaterialShape.Shape.Clover8Leaf
            title: Translation.tr("Sounds")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "battery_android_full"
                    text: Translation.tr("Battery")
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
        }

        ContentSection {
            icon: "nest_clock_farsight_analog"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Time")

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clock")
                    text: Config.options.time.format
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.time.format = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Date")
                    text: Config.options.time.dateFormat
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.time.dateFormat = text;
                    }
                }
            }

            ConfigSwitch {
                buttonIcon: "pace"
                text: Translation.tr("Second precision")
                checked: Config.options.time.secondPrecision
                onCheckedChanged: {
                    Config.options.time.secondPrecision = checked;
                }
            }


            ContentSubsection {
                title: Translation.tr("Format")
                tooltip: ""

                ConfigSelectionArray {
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
                        {
                            displayName: Translation.tr("24h"),
                            value: "hh:mm"
                        },
                        {
                            displayName: Translation.tr("12h am/pm"),
                            value: "h:mm ap"
                        },
                        {
                            displayName: Translation.tr("12h AM/PM"),
                            value: "h:mm AP"
                        },
                    ]
                }
            }
        }

        ContentSection {
            icon: "language"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Language")

            ContentSubsection {
                title: Translation.tr("Interface Language")

                StyledComboBoxSearch {
                    id: languageSelector
                    buttonIcon: "language"
                    textRole: "displayName"

                    model: [
                        {
                            displayName: Translation.tr("Auto (System)"),
                            value: "auto"
                        },
                        ...Translation.allAvailableLanguages.map(lang => {
                            return {
                                displayName: lang,
                                value: lang
                            };
                        })]

                    currentIndex: {
                        const index = model.findIndex(item => item.value === Config.options.language.ui);
                        return index !== -1 ? index : 0;
                    }

                    onActivated: index => {
                        Config.options.language.ui = model[index].value;
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Generate translation with Gemini")

                ConfigRow {
                    MaterialTextArea {
                        id: localeInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")
                        text: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui
                    }
                    RippleButtonWithIcon {
                        id: generateTranslationBtn
                        Layout.fillHeight: true
                        nerdIcon: ""
                        enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())
                        mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                        onClicked: {
                            translationProc.locale = localeInput.text.trim();
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
