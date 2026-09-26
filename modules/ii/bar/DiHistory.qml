import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The compact face of the island's memory: the last thing that happened, and how many are behind it
RowLayout {
    id: history
    required property Item di
    anchors {
        fill: parent
        leftMargin: 10
        rightMargin: 12
    }
    spacing: 8

    readonly property var latest: IslandEvents.eventLog[0] ?? null

    MaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        text: "history"
        iconSize: 18
        fill: 1
        color: Appearance.colors.colPrimary
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: history.latest?.title ?? Translation.tr("Recent events")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: IslandEvents.eventLog.length > 1
                ? Translation.tr("and %1 more").arg(IslandEvents.eventLog.length - 1)
                : (history.latest?.subtitle ?? "")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }
}
