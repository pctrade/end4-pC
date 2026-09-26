import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Expanded pressure alert: which resource, how it's been going, and the processes behind it — with a way to end
// the one that's out of line. Opens on the resource that raised the alert; the tabs look at the other two.
ColumnLayout {
    id: xl
    required property Item di
    spacing: 10
    implicitWidth: 380
    readonly property real wantedWidth: 380

    property string kind: Pressure.kind || "cpu"
    readonly property real usage: Pressure.usage(xl.kind)
    readonly property var culprit: (Pressure.procs[xl.kind] ?? []).find(p => p.abnormal) ?? null
    readonly property color tone: xl.culprit ? Appearance.colors.colError
        : xl.usage >= 0.85 ? IslandEvents.colorAttention : Appearance.colors.colPrimary

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: Pressure.icon(xl.kind)
            iconSize: 20
            fill: 1
            color: xl.tone
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -2

            StyledText {
                Layout.fillWidth: true
                text: Pressure.title(xl.kind)
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: xl.culprit ? Translation.tr("%1 is using far more than the rest").arg(xl.culprit.label)
                    : xl.kind === "memory" ? `${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)} / ${ResourceUsage.maxAvailableMemoryString}`
                    : Translation.tr("Nothing out of line")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: xl.culprit ? xl.tone : Appearance.colors.colOnLayer0
                opacity: xl.culprit ? 1 : 0.65
                elide: Text.ElideRight
            }
        }
        StyledText {
            text: `${Math.round(xl.usage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 15
        color: Appearance.colors.colLayer1

        readonly property var kinds: Pressure.rc6Path !== "" ? ["cpu", "memory", "gpu"] : ["cpu", "memory"]
        readonly property real segment: (width - 4) / kinds.length

        Rectangle {
            x: 2 + parent.segment * Math.max(0, parent.kinds.indexOf(xl.kind))
            y: 2
            width: parent.segment
            height: parent.height - 4
            radius: height / 2
            color: Appearance.colors.colSecondaryContainer

            Behavior on x {
                NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors {
                fill: parent
                margins: 2
            }

            Repeater {
                model: parent.parent.kinds
                delegate: Item {
                    id: tab
                    required property string modelData
                    readonly property bool current: xl.kind === tab.modelData
                    width: parent.parent.segment
                    height: parent.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        StyledText {
                            text: tab.modelData === "memory" ? Translation.tr("Memory") : tab.modelData.toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: tab.current ? Font.DemiBold : Font.Normal
                            color: tab.current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: `${Math.round(Pressure.usage(tab.modelData) * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: tab.current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            opacity: 0.6
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xl.kind = tab.modelData
                    }
                }
            }
        }
    }

    DiSparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        values: Pressure.history(xl.kind)
        points: ResourceUsage.historyLength
        color: xl.tone
        threshold: xl.kind === "memory" ? Pressure.memoryThreshold : xl.kind === "gpu" ? Pressure.gpuThreshold : Pressure.cpuThreshold
    }

    DiProcessList {
        Layout.fillWidth: true
        kind: xl.kind
        visibleRows: 5
        fadeColor: xl.di.surfaceColor
    }
}
