import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    bottomContentPadding: 15

    component IconButton : RippleButton {
        id: iRoot
        property string iconName
        property string textString
        property color textColor: Appearance.colors.colOnPrimary

        toggled: true
        implicitHeight: 36
        padding: 14
        implicitWidth: layoutItem.implicitWidth + padding * 2
        buttonRadius: Appearance.rounding.full

        contentItem: Item {
            implicitWidth: layoutItem.implicitWidth
            implicitHeight: layoutItem.implicitHeight
            RowLayout {
                id: layoutItem
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: iRoot.iconName
                    color: iRoot.textColor
                    iconSize: Appearance.font.pixelSize.normal
                    Layout.alignment: Qt.AlignVCenter
                }
                StyledText {
                    text: iRoot.textString
                    color: iRoot.textColor
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    //This was intended to go into the results more deeply but in the end I didn't like it but I left it just in case lol
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

            ContentSubsection {
                title: Translation.tr("Custom OpenAI-compatible Providers")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 15

                    Repeater {
                        model: Config.options.ai.customProviders ? Config.options.ai.customProviders.length : 0

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.rounding.small

                            GroupedList {
                                cohesive: true

                                ConfigSwitch {
                                    text: Config.options.ai.customProviders[index].name
                                        ? Translation.tr("Enable %1").arg(Config.options.ai.customProviders[index].name)
                                        : Translation.tr("Enable provider %1").arg(index + 1)
                                    checked: Config.options.ai.customProviders[index].enabled
                                    onCheckedChanged: {
                                        let providers = [...Config.options.ai.customProviders];
                                        providers[index].enabled = checked;
                                        Config.options.ai.customProviders = providers;
                                    }
                                }

                                MaterialTextArea {
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Provider Name (e.g. OpenRouter)")
                                    text: Config.options.ai.customProviders[index].name
                                    wrapMode: TextEdit.Wrap
                                    onTextChanged: {
                                        let providers = [...Config.options.ai.customProviders];
                                        if (providers[index].name !== text) {
                                            providers[index].name = text;
                                            Config.options.ai.customProviders = providers;
                                        }
                                    }
                                }

                                MaterialTextArea {
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Base URL (e.g. https://openrouter.ai/api/v1)")
                                    text: Config.options.ai.customProviders[index].baseUrl
                                    wrapMode: TextEdit.Wrap
                                    onTextChanged: {
                                        let providers = [...Config.options.ai.customProviders];
                                        if (providers[index].baseUrl !== text) {
                                            providers[index].baseUrl = text;
                                            Config.options.ai.customProviders = providers;
                                        }
                                    }
                                }

                                MaterialTextField {
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("API Key")
                                    text: KeyringStorage.loaded ? (KeyringStorage.keyringData.apiKeys?.[`custom_provider_${index}`] || "") : ""
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData
                                    onTextChanged: {
                                        let currentText = text;
                                        Qt.callLater(() => {
                                            if (KeyringStorage.loaded) {
                                                KeyringStorage.setNestedField(["apiKeys", `custom_provider_${index}`], currentText);
                                            }
                                        });
                                    }
                                }

                                RowLayout {
                                    id: providerActionsRow
                                    Layout.fillWidth: true

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        id: removeProviderButton
                                        toggled: false
                                        textString: Translation.tr("Remove Provider")
                                        iconName: "delete"
                                        textColor: Appearance.colors.colError
                                        colRipple: Appearance.colors.colErrorActive
                                        onClicked: {
                                            const removedIndex = index;
                                            let providers = [...Config.options.ai.customProviders];
                                            providers.splice(removedIndex, 1);
                                            Config.options.ai.customProviders = providers;

                                            if (KeyringStorage.loaded) {
                                                KeyringStorage.setNestedField(["apiKeys", `custom_provider_${removedIndex}`], "");
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: sectionActionsRow
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 10
                        spacing: 10

                        IconButton {
                            id: addProviderButton
                            textString: Translation.tr("Add Provider")
                            iconName: "add"
                            onClicked: {
                                let providers = [...(Config.options.ai.customProviders || [])];
                                providers.push({ enabled: false, name: "New Provider", baseUrl: "" });
                                Config.options.ai.customProviders = providers;
                            }
                        }

                        IconButton {
                            id: fetchModelsButton
                            toggled: false
                            textColor: Appearance.colors.colPrimary
                            textString: Translation.tr("Fetch Models")
                            iconName: "sync"
                            onClicked: {
                                Ai.fetchCustomModels();
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Ai.customProviderFeedbackText
                    color: Appearance.colors.colSubtext
                    visible: text.length > 0
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
            icon: "file_open"
            shape: MaterialShape.Shape.Slanted
            title: Translation.tr("Save paths")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Video Recording Path")
                text: Config.options.screenRecord.savePath
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.screenRecord.savePath = text;
                }
            }
            
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
                text: Config.options.screenSnip.savePath
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.screenSnip.savePath = text;
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
            }

            ContentSubsection {
                title: Translation.tr("Prefixes")
                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Action")
                        text: Config.options.search.prefix.action
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.action = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Clipboard")
                        text: Config.options.search.prefix.clipboard
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.clipboard = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Emojis")
                        text: Config.options.search.prefix.emojis
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.emojis = text;
                        }
                    }
                }

                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Icons")
                        text: Config.options.search.prefix.symbols
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.symbols = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Shell command")
                        text: Config.options.search.prefix.shellCommand
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.shellCommand = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Web search")
                        text: Config.options.search.prefix.webSearch
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.webSearch = text;
                        }
                    }
                }
                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Apps")
                        text: Config.options.search.prefix.app
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.app = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Keybinds")
                        text: Config.options.search.prefix.keybinds
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.keybinds = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Math")
                        text: Config.options.search.prefix.math
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.math = text;
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Web search")
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Base URL")
                    text: Config.options.search.engineBaseUrl
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.engineBaseUrl = text;
                    }
                }
            }
        }

        ContentSection {
            icon: "deployed_code_update"
            title: Translation.tr("System updates (Arch only)")

            GroupedList {
                ConfigSwitch {
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
            }
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("City name")
                text: Config.options.bar.weather.city
                wrapMode: TextEdit.Wrap

                Timer {
                    id: cityDebounceTimer
                    interval: 1000
                    running: false
                    onTriggered: {
                        Config.options.bar.weather.city = parent.text
                    }
                }

                onTextChanged: {
                    cityDebounceTimer.restart()
                }
            }
        }
        WorldMap {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
        }
    }
}
