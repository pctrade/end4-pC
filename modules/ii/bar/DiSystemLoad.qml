import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Sustained pressure (CPU, memory or GPU) and who's behind it. When one process is out of line (Pressure.culprit)
// the island says so by name — "Chrome · a tab is misbehaving" — instead of a generic "high CPU".
RowLayout {
    id: load
    required property Item di
    anchors {
        fill: parent
        leftMargin: 10
        rightMargin: 12
    }
    spacing: 7

    readonly property string kind: Pressure.kind || "cpu"
    readonly property real usage: Pressure.usage(load.kind)
    readonly property var culprit: Pressure.culprit
    readonly property var heaviest: Pressure.top
    readonly property color tone: load.culprit ? Appearance.colors.colError : IslandEvents.colorAttention

    MaterialSymbol {
        text: Pressure.icon(load.kind)
        iconSize: 17
        fill: 1
        color: load.tone
    }

    DiSparkline {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 20
        values: Pressure.history(load.kind)
        points: 20
        color: load.tone
        lineWidth: 1.5
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: Pressure.title(load.kind)
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: load.culprit ? Translation.tr("%1 is out of line · %2").arg(load.culprit.label).arg(load.culprit.text)
                : load.heaviest ? `${load.heaviest.label} · ${load.heaviest.text}` : ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: load.culprit ? load.tone : Appearance.colors.colOnLayer0
            opacity: load.culprit ? 1 : 0.7
            elide: Text.ElideRight
        }
    }

    StyledText {
        text: `${Math.round(load.usage * 100)}%`
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}
