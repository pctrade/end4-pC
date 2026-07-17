// Behavior adapted for end4-pC's plugin host, inspired by:
// https://github.com/na-ive/nandoroid-shell/blob/main/dotfiles/.config/quickshell/nandoroid/widgets/AtAGlance.qml

import QtQuick
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property int fontSize: 24
    property string fontFamily: ""
    property bool showGreeting: true
    property bool showDate: true
    property bool showQuote: true
    property string alignment: "left"
    property var quotesData: ({})
    property string currentQuote: ""

    implicitWidth: 420
    implicitHeight: content.implicitHeight

    readonly property date currentDate: DateTime.clock.date
    readonly property int currentHour: currentDate.getHours()
    readonly property string timePeriod: {
        if (currentHour >= 5 && currentHour < 12) return "morning";
        if (currentHour >= 12 && currentHour < 17) return "afternoon";
        if (currentHour >= 17 && currentHour < 22) return "evening";
        return "midnight";
    }
    readonly property string greeting: {
        switch (timePeriod) {
        case "morning": return "Good morning.";
        case "afternoon": return "Good afternoon.";
        case "evening": return "Good evening.";
        default: return "Good night.";
        }
    }
    readonly property string formattedDate: Qt.locale().toString(currentDate, "dddd, MMMM d")
    readonly property int textAlignment: alignment === "center"
        ? Text.AlignHCenter
        : alignment === "right" ? Text.AlignRight : Text.AlignLeft

    function updateQuote() {
        const periodQuotes = root.quotesData[root.timePeriod];
        const choices = Array.isArray(periodQuotes) && periodQuotes.length > 0
            ? periodQuotes
            : root.quotesData.general;
        if (!Array.isArray(choices) || choices.length === 0) {
            root.currentQuote = "";
            return;
        }
        root.currentQuote = choices[Math.floor(Math.random() * choices.length)];
    }

    onTimePeriodChanged: updateQuote()

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.updateQuote()
    }

    FileView {
        id: quotesFile
        path: Qt.resolvedUrl("quotes.json")
        onLoaded: {
            try {
                root.quotesData = JSON.parse(quotesFile.text());
                root.updateQuote();
            } catch (error) {
                console.warn("[AtAGlance] Failed to parse quotes: " + error);
            }
        }
        onLoadFailed: error => console.warn("[AtAGlance] Failed to load quotes: " + error)
    }

    Column {
        id: content
        width: root.width
        spacing: 8

        StyledText {
            visible: root.showGreeting
            width: parent.width
            text: root.greeting
            font.pixelSize: Math.round(root.fontSize * 1.2)
            font.family: root.fontFamily || Appearance.font.family.main
            font.weight: Font.DemiBold
            color: Appearance.colors.colPrimary
            wrapMode: Text.WordWrap
            horizontalAlignment: root.textAlignment
        }

        StyledText {
            visible: root.showDate
            width: parent.width
            text: "It's " + root.formattedDate
            font.pixelSize: root.fontSize
            font.family: root.fontFamily || Appearance.font.family.main
            color: Appearance.colors.colSecondary
            wrapMode: Text.WordWrap
            horizontalAlignment: root.textAlignment
        }

        StyledText {
            visible: root.showQuote && root.currentQuote !== ""
            width: parent.width
            text: root.currentQuote
            font.pixelSize: Math.round(root.fontSize * 0.8)
            font.family: root.fontFamily || Appearance.font.family.main
            color: Appearance.colors.colOnLayer0
            wrapMode: Text.WordWrap
            horizontalAlignment: root.textAlignment
        }
    }
}
