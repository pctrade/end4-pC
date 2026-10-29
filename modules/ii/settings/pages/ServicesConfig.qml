import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    bottomContentPadding: 15
    
    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "neurology"
            shape: MaterialShape.Shape.Ghostish
            title: Translation.tr("AI")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("System prompt")
                text: Config.options.ai.systemPrompt
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.options.ai.systemPrompt = text;
                    });
                }
            }
        }

        ContentSection {
            icon: "cell_tower"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Networking")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("User agent (for services that require it)")
                text: Config.options.networking.userAgent
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.networking.userAgent = text;
                }
            }
        }

        ContentSection {
            icon: "music_cast"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Music Recognition")

            GroupedList {
                ConfigSpinBox {
                    icon: "timer_off"
                    text: Translation.tr("Total duration timeout (s)")
                    value: Config.options.musicRecognition.timeout
                    from: 10
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.musicRecognition.timeout = value;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (s)")
                    value: Config.options.musicRecognition.interval
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.options.musicRecognition.interval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "file_open"
            shape: MaterialShape.Shape.Slanted
            title: Translation.tr("Save paths")

            GroupedList {
                ConfigTextArea {
                    id: videoRecordPathField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "video_file"
                    text: Translation.tr("Video Recording Path")
                    value: Config.options.screenRecord.savePath
                    onValueChanged: {
                        videoRecordPathDebounceTimer.restart();
                    }

                    Timer {
                        id: videoRecordPathDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.screenRecord.savePath = videoRecordPathField.value;
                        }
                    }
                }

                ConfigTextArea {
                    id: screenshotPathField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "screenshot_monitor"
                    text: Translation.tr("Screenshot Path (leave empty to just copy)")
                    value: Config.options.screenSnip.savePath
                    onValueChanged: {
                        screenshotPathDebounceTimer.restart();
                    }

                    Timer {
                        id: screenshotPathDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.screenSnip.savePath = screenshotPathField.value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "search"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Search")

            GroupedList {
                ConfigSwitch {
                    text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
                    checked: Config.options.search.sloppy
                    onCheckedChanged: {
                        Config.options.search.sloppy = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "preview"
                    text: Translation.tr("Show clipboard preview popups")
                    checked: Config.options.search.clipboardPreviewPopup
                    onCheckedChanged: {
                        Config.options.search.clipboardPreviewPopup = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Prefixes")

                GroupedList {
                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "bolt"
                            fieldWidth: 100
                            text: Translation.tr("Action")
                            value: Config.options.search.prefix.action
                            onValueChanged: {
                                Config.options.search.prefix.action = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "content_paste"
                            fieldWidth: 100
                            text: Translation.tr("Clipboard")
                            value: Config.options.search.prefix.clipboard
                            onValueChanged: {
                                Config.options.search.prefix.clipboard = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "mood"
                            fieldWidth: 100
                            text: Translation.tr("Emojis")
                            value: Config.options.search.prefix.emojis
                            onValueChanged: {
                                Config.options.search.prefix.emojis = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "emoji_symbols"
                            fieldWidth: 100
                            text: Translation.tr("Icons")
                            value: Config.options.search.prefix.symbols
                            onValueChanged: {
                                Config.options.search.prefix.symbols = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "terminal"
                            fieldWidth: 100
                            text: Translation.tr("Shell command")
                            value: Config.options.search.prefix.shellCommand
                            onValueChanged: {
                                Config.options.search.prefix.shellCommand = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            fieldWidth: 100
                            buttonIcon: "travel_explore"
                            text: Translation.tr("Web search")
                            value: Config.options.search.prefix.webSearch
                            onValueChanged: {
                                Config.options.search.prefix.webSearch = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "apps"
                            fieldWidth: 100
                            text: Translation.tr("Apps")
                            value: Config.options.search.prefix.app
                            onValueChanged: {
                                Config.options.search.prefix.app = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "keyboard_command_key"
                            fieldWidth: 100
                            text: Translation.tr("Keybinds")
                            value: Config.options.search.prefix.keybinds
                            onValueChanged: {
                                Config.options.search.prefix.keybinds = value;
                            }
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Web search")

                GroupedList {
                    ConfigTextArea {
                        id: baseUrlField
                        Layout.fillWidth: true
                        fieldWidth: 320
                        buttonIcon: "travel_explore"
                        text: Translation.tr("Base URL")
                        value: Config.options.search.engineBaseUrl
                        onValueChanged: {
                            baseUrlDebounceTimer.restart();
                        }

                        Timer {
                            id: baseUrlDebounceTimer
                            interval: 600
                            repeat: false
                            onTriggered: {
                                Config.options.search.engineBaseUrl = baseUrlField.value;
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "web_asset"
            title: Translation.tr("Webapps")

            GroupedList {
                ConfigTextArea {
                    id: webappUrlField
                    Layout.fillWidth: true
                    fieldWidth: 320
                    fieldHeight: 64
                    multiline: true
                    buttonIcon: "language"
                    text: Translation.tr("Website URL")
                    placeholderText: Translation.tr("example.com (one per line)")
                    confirmButtonVisible: webappUrlField.value.trim() !== "" && !Webapps.busy
                    confirmButtonIcon: "add"
                    onConfirmClicked: {
                        Webapps.create(webappUrlField.value);
                        webappUrlField.value = "";
                    }
                }
            }

            StyledText {
                visible: Webapps.error !== ""
                Layout.fillWidth: true
                Layout.leftMargin: 8
                text: Translation.tr("Could not create: %1").arg(Webapps.error)
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            ContentSubsection {
                title: Translation.tr("Your webapps")
                visible: Webapps.items.length > 0

                GroupedList {
                    ColumnLayout {
                        spacing: 10

                        Repeater {
                            model: Webapps.items

                            delegate: RowLayout {
                                id: webappRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    source: webappRow.modelData.icon.startsWith("/") ? "file://" + webappRow.modelData.icon : ""
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: webappRow.modelData.name
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: webappRow.modelData.url
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                    }
                                }

                                RippleButtonWithIcon {
                                    materialIcon: "open_in_new"
                                    mainText: Translation.tr("Open")
                                    onClicked: Webapps.open(webappRow.modelData.id)
                                }
                                RippleButtonWithIcon {
                                    materialIcon: "delete"
                                    mainText: Translation.tr("Remove")
                                    onClicked: Webapps.remove(webappRow.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "deployed_code_update"
            title: Translation.tr("System updates (Arch only)")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "update"
                    text: Translation.tr("Enable update checks")
                    checked: Config.options.updates.enableCheck
                    onCheckedChanged: {
                        Config.options.updates.enableCheck = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Check interval (mins)")
                    value: Config.options.updates.checkInterval
                    from: 60
                    to: 1440
                    stepSize: 60
                    onValueChanged: {
                        Config.options.updates.checkInterval = value;
                    }
                }

                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "desktop_windows"
                    text: Translation.tr("Distro / package manager")
                    description: Translation.tr("Auto-detect reads /etc/os-release. Custom uses the command below.")
                    fieldWidth: 240
                    model: [
                        { "displayName": Translation.tr("Auto-detect"), "icon": "travel_explore", "value": "auto" },
                        { "displayName": "Arch (yay → paru → pacman)", "icon": "terminal", "value": "arch" },
                        { "displayName": "CachyOS (cachy-update)", "icon": "terminal", "value": "cachyos" },
                        { "displayName": "Debian / Ubuntu (apt)", "icon": "terminal", "value": "debian" },
                        { "displayName": "Fedora (dnf)", "icon": "terminal", "value": "fedora" },
                        { "displayName": "openSUSE (zypper)", "icon": "terminal", "value": "opensuse" },
                        { "displayName": Translation.tr("Custom command"), "icon": "edit", "value": "custom" },
                    ]
                    currentValue: Config.options.updates.distro
                    onSelected: newValue => {
                        Config.options.updates.distro = newValue;
                    }
                }

                ConfigTextArea {
                    id: customUpdateCommandField
                    visible: Config.options.updates.distro === "custom"
                    Layout.fillWidth: true
                    buttonIcon: "terminal"
                    text: Translation.tr("Custom update command")
                    placeholderText: Translation.tr("e.g. sudo apt update && sudo apt upgrade")
                    value: Config.options.updates.customUpdateCommand
                    onValueChanged: customUpdateCommandDebounce.restart()

                    Timer {
                        id: customUpdateCommandDebounce
                        interval: 500
                        repeat: false
                        onTriggered: {
                            Config.options.updates.customUpdateCommand = customUpdateCommandField.value;
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "system_update_alt"
                    text: Translation.tr("Notify when system packages have updates")
                    description: Translation.tr("Ping once per new update count, with an “Update now” action that runs the command in a terminal.")
                    checked: Config.options.updates.notifySystemUpdates
                    onCheckedChanged: {
                        Config.options.updates.notifySystemUpdates = checked;
                    }
                }

                ConfigComboBox {
                    visible: ["arch", "cachyos"].includes(Updates.resolvedDistro)
                    Layout.fillWidth: true
                    buttonIcon: "handyman"
                    text: Translation.tr("System update tool")
                    description: Translation.tr("Which tool the “Update now” action runs. Auto prefers cachy-update on CachyOS.")
                    fieldWidth: 220
                    model: [
                        { "displayName": Translation.tr("Auto (cachy-update → yay → paru → pacman)"), "icon": "auto_awesome", "value": "auto" },
                        { "displayName": "cachy-update", "icon": "terminal", "value": "cachy-update" },
                        { "displayName": "yay", "icon": "terminal", "value": "yay" },
                        { "displayName": "paru", "icon": "terminal", "value": "paru" },
                        { "displayName": "pacman (polkit)", "icon": "terminal", "value": "pacman" },
                    ]
                    currentValue: Config.options.updates.systemUpdateTool
                    onSelected: newValue => {
                        Config.options.updates.systemUpdateTool = newValue;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "cloud_download"
                    text: Translation.tr("Notify about upstream end4-pC updates")
                    checked: Config.options.updates.notifyUpstreamUpdates
                    onCheckedChanged: {
                        Config.options.updates.notifyUpstreamUpdates = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Upstream check interval (mins)")
                    value: Config.options.updates.upstreamCheckInterval
                    from: 30
                    to: 1440
                    stepSize: 30
                    onValueChanged: {
                        Config.options.updates.upstreamCheckInterval = value;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "merge"
                    text: Translation.tr("Notify about a secondary “fixes” repo")
                    description: Translation.tr("Also watch a fork of the config (e.g. your personal fixes branch) and let the notification merge, skip, or view it.")
                    checked: Config.options.updates.notifyFixesRepo
                    onCheckedChanged: {
                        Config.options.updates.notifyFixesRepo = checked;
                    }
                }

                ConfigTextArea {
                    id: fixesRepoUrlField
                    visible: Config.options.updates.notifyFixesRepo
                    Layout.fillWidth: true
                    buttonIcon: "link"
                    text: Translation.tr("Fixes repo URL")
                    placeholderText: Translation.tr("e.g. https://github.com/youruser/end4-pC-YourFixes.git")
                    value: Config.options.updates.fixesRepoUrl
                    onValueChanged: fixesRepoUrlDebounce.restart()

                    Timer {
                        id: fixesRepoUrlDebounce
                        interval: 500
                        repeat: false
                        onTriggered: {
                            Config.options.updates.fixesRepoUrl = fixesRepoUrlField.value.trim();
                        }
                    }
                }

            }
        }

        ContentSection {
            icon: "weather_mix"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Weather")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "assistant_navigation"
                    text: Translation.tr("Enable GPS based location")
                    checked: Config.options.bar.weather.enableGPS
                    onCheckedChanged: {
                        Config.options.bar.weather.enableGPS = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "thermometer"
                    text: Translation.tr("Fahrenheit unit")
                    checked: Config.options.bar.weather.useUSCS
                    onCheckedChanged: {
                        Config.options.bar.weather.useUSCS = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (m)")
                    value: Config.options.bar.weather.fetchInterval
                    from: 5
                    to: 50
                    stepSize: 5
                    onValueChanged: {
                        Config.options.bar.weather.fetchInterval = value;
                    }
                }
                ConfigTextArea {
                    id: cityField
                    Layout.fillWidth: true
                    buttonIcon: "location_city"
                    text: Translation.tr("City name")
                    value: Config.options.bar.weather.city
                    onValueChanged: cityDebounceTimer.restart()

                    Timer {
                        id: cityDebounceTimer
                        interval: 1000
                        running: false
                        onTriggered: Config.options.bar.weather.city = cityField.value
                    }
                }
            }
        }
        WorldMap {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
        }
    }
}
