import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.translator
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Translator widget with the `trans` commandline tool.
 */
Item {
    id: root

    // Sizes
    property real padding: Appearance.spacing.verysmall

    // Widgets
    property var inputField: inputCanvas.inputTextArea

    // Widget variables
    property bool translationFor: false
    property string translatedText: ""
    property list<string> languages: []

    // Options
    property string targetLanguage: Config.options.language.translator.targetLanguage
    property string sourceLanguage: Config.options.language.translator.sourceLanguage
    property string hostLanguage: targetLanguage

    // States
    property bool showLanguageSelector: false
    property bool languageSelectorTarget: false

    function showLanguageSelectorDialog(isTargetLang: bool) {
        root.languageSelectorTarget = isTargetLang;
        root.showLanguageSelector = true
    }

    function swapLanguages() {
        let temp = root.targetLanguage;
        root.targetLanguage = root.sourceLanguage;
        root.sourceLanguage = temp;
        Config.options.language.translator.targetLanguage = root.targetLanguage;
        Config.options.language.translator.sourceLanguage = root.sourceLanguage;
        translateTimer.restart();
    }

    onFocusChanged: (focus) => {
        if (focus) {
            root.inputField.forceActiveFocus()
        }
    }

    Timer {
        id: translateTimer
        interval: Config.options.sidebar.translator.delay
        repeat: false
        onTriggered: () => {
            if (root.inputField.text.trim().length > 0) {
                translateProc.running = false;
                translateProc.buffer = "";
                translateProc.running = true;
            } else {
                root.translatedText = "";
            }
        }
    }

    Process {
        id: translateProc
        command: ["bash", "-c", `trans -brief -no-bidi`
            + ` -source '${StringUtils.shellSingleQuoteEscape(root.sourceLanguage)}'`
            + ` -target '${StringUtils.shellSingleQuoteEscape(root.targetLanguage)}'`
            + ` '${StringUtils.shellSingleQuoteEscape(root.inputField.text.trim())}'`]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                translateProc.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.translatedText = translateProc.buffer.trim();
        }
    }

    Process {
        id: getLanguagesProc
        command: ["trans", "-list-languages", "-no-bidi"]
        property list<string> bufferList: ["auto"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                getLanguagesProc.bufferList.push(data.trim());
            }
        }
        onExited: (exitCode, exitStatus) => {
            let langs = getLanguagesProc.bufferList
                .filter(lang => lang.trim().length > 0 && lang !== "auto")
                .sort((a, b) => a.localeCompare(b));
            langs.unshift("auto");
            root.languages = langs;
            getLanguagesProc.bufferList = [];
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: Appearance.spacing.normal

        TextCanvas {
            id: inputCanvas
            Layout.fillWidth: true
            isInput: true
            containerColor: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.8)
            placeholderText: Translation.tr("Enter text to translate...")
            onInputTextChanged: {
                translateTimer.restart();
            }
            GroupButton {
                id: pasteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_paste"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = Quickshell.clipboardText
                }
            }
            GroupButton {
                id: deleteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: inputCanvas.inputTextArea.text.length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "close"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.verylarge

            Item { Layout.fillWidth: true }

            LanguageSelectorButton {
                id: sourceLanguageButton
                displayText: root.sourceLanguage
                buttonColor: Appearance.colors.colSecondaryContainer
                onClicked: root.showLanguageSelectorDialog(false)
            }

            GroupButton {
                id: swapButton
                Layout.preferredWidth: height
                colBackground: Appearance.colors.colTertiaryContainer
                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                buttonRadius: Appearance.rounding.full
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "autorenew"
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: root.swapLanguages()
            }

            LanguageSelectorButton {
                id: targetLanguageButton
                displayText: root.targetLanguage
                buttonColor: Appearance.colors.colPrimaryContainer
                onClicked: root.showLanguageSelectorDialog(true)
            }

            Item { Layout.fillWidth: true }
        }

        TextCanvas {
            id: outputCanvas
            Layout.fillWidth: true
            isInput: false
            containerColor: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.8)
            placeholderText: Translation.tr("Translation goes here...")
            property bool hasTranslation: (root.translatedText.trim().length > 0)
            text: hasTranslation ? root.translatedText : ""
            GroupButton {
                id: copyButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: outputCanvas.displayedText.trim().length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_copy"
                    color: copyButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    Quickshell.clipboardText = outputCanvas.displayedText
                }
            }
            GroupButton {
                id: searchButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: outputCanvas.displayedText.trim().length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "travel_explore"
                    color: searchButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    let url = Config.options.search.engineBaseUrl + outputCanvas.displayedText;
                    for (let site of Config.options.search.excludedSites) {
                        url += ` -site:${site}`;
                    }
                    Qt.openUrlExternally(url);
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        visible: root.showLanguageSelector
        z: 9999
        sourceComponent: SelectionDialog {
            id: languageSelectorDialog
            titleText: Translation.tr("Select Language")
            items: root.languages
            defaultChoice: root.languageSelectorTarget ? root.targetLanguage : root.sourceLanguage
            onCanceled: () => {
                root.showLanguageSelector = false;
            }
            onSelected: (result) => {
                root.showLanguageSelector = false;
                if (!result || result.length === 0) return;
                if (root.languageSelectorTarget) {
                    root.targetLanguage = result;
                    Config.options.language.translator.targetLanguage = result;
                } else {
                    root.sourceLanguage = result;
                    Config.options.language.translator.sourceLanguage = result;
                }
                translateTimer.restart();
            }
        }
    }
}