import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// What queued up behind a fullscreen window, handed back in one line once it ends. A click opens History,
// where every one of them is waiting.
RowLayout {
    id: digest
    required property Item di
    anchors {
        fill: parent
        leftMargin: 10
        rightMargin: 12
    }
    spacing: 8

    readonly property var payload: IslandEvents.fullscreenDigest.payload ?? ({})
    readonly property color tone: (digest.payload.level ?? 0) >= 2 ? Appearance.colors.colError : Appearance.colors.colPrimary

    MaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        text: "fullscreen_exit"
        iconSize: 18
        fill: 1
        color: digest.tone
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("While fullscreen")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: digest.payload.summary ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        visible: (digest.payload.count ?? 0) > 1
        implicitWidth: Math.max(20, countText.implicitWidth + 10)
        implicitHeight: 20
        radius: 10
        color: digest.tone

        StyledText {
            id: countText
            anchors.centerIn: parent
            text: `${digest.payload.count ?? 0}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: (digest.payload.level ?? 0) >= 2 ? Appearance.colors.colOnError : Appearance.colors.colOnPrimary
        }
    }
}
