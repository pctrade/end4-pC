import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Download details: speed, where the traffic comes from (per process) and the latest bursts
ColumnLayout {
    id: xnet
    required property Item di
    spacing: 10
    implicitWidth: 380
    readonly property real wantedWidth: 380

    readonly property bool active: IslandEvents.downloadActive
    readonly property var sources: IslandEvents.downloadSources
    readonly property real maxRx: Math.max(1, ...xnet.sources.map(s => s.rx))
    readonly property string topName: IslandEvents.downloadTop?.name ?? ""
    property double now: Date.now()

    Binding {
        target: IslandEvents
        property: "downloadWatch"
        value: true
        restoreMode: Binding.RestoreValue
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: xnet.now = Date.now()
    }

    function duration(ms) {
        const s = Math.max(0, Math.round(ms / 1000))
        return s < 60 ? `${s} s` : `${Math.floor(s / 60)} min ${s % 60} s`
    }

    component Tile: Rectangle {
        id: tile
        property string icon
        property string label
        property string value
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 12
        color: Appearance.colors.colLayer1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                MaterialSymbol {
                    text: tile.icon
                    iconSize: 14
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: tile.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tile.value
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "download"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Network activity")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            visible: xnet.active && IslandEvents.downloadSince > 0
            text: xnet.duration(xnet.now - IslandEvents.downloadSince)
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Tile {
            icon: "arrow_downward"
            label: Translation.tr("Download")
            value: IslandEvents.formatBytes(IslandEvents.downloadRate, true)
        }
        Tile {
            icon: "arrow_upward"
            label: Translation.tr("Upload")
            value: IslandEvents.formatBytes(IslandEvents.uploadRate, true)
        }
        Tile {
            icon: "data_usage"
            label: Translation.tr("Total")
            value: IslandEvents.formatBytes(IslandEvents.burstBytes, false)
        }
    }

    StyledText {
        visible: IslandEvents.partialFiles.length > 0
        text: Translation.tr("Files arriving")
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: IslandEvents.partialFiles

        delegate: Rectangle {
            id: fileRow
            required property var modelData
            readonly property real progress: modelData.total > 0 ? Math.max(0, Math.min(1, modelData.bytes / modelData.total)) : -1
            Layout.fillWidth: true
            implicitHeight: 52
            radius: 12
            color: Appearance.colors.colLayer1

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 8
                    bottomMargin: 8
                }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "download"
                        iconSize: 15
                        fill: 1
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: fileRow.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: fileRow.progress >= 0 ? `${Math.round(fileRow.progress * 100)}%`
                            : IslandEvents.formatBytes(fileRow.modelData.bytes, false)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.8
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

                    Rectangle {
                        width: fileRow.progress >= 0 ? parent.width * fileRow.progress : parent.width * 0.3
                        height: parent.height
                        radius: 2
                        color: Appearance.colors.colPrimary
                        opacity: fileRow.progress >= 0 ? 1 : 0.5

                        Behavior on width {
                            NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                        }

                        SequentialAnimation on x {
                            running: fileRow.progress < 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: fileRow.width * 0.6; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: [IslandEvents.formatBytes(fileRow.modelData.rate, true),
                        fileRow.modelData.total > 0 ? `${IslandEvents.formatBytes(fileRow.modelData.bytes, false)} / ${IslandEvents.formatBytes(fileRow.modelData.total, false)}` : "",
                        fileRow.modelData.total > 0 && fileRow.modelData.rate > 1024
                            ? IslandEvents.remainingTime((fileRow.modelData.total - fileRow.modelData.bytes) / fileRow.modelData.rate) : ""
                    ].filter(Boolean).join(" · ")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.65
                    elide: Text.ElideRight
                }
            }
        }
    }

    Graph {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        visible: IslandEvents.downloadHistory.length > 1
        values: IslandEvents.downloadHistory.map(v => v / Math.max(1, IslandEvents.downloadPeak))
        points: 40
        color: Appearance.colors.colPrimary
        fillOpacity: 0.25
    }

    StyledText {
        text: Translation.tr("Where it comes from")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    StyledText {
        Layout.fillWidth: true
        visible: IslandEvents.downloadSourcesError !== "" || xnet.sources.length === 0
        text: IslandEvents.downloadSourcesError === "missing" ? Translation.tr("Install nethogs to see where it comes from")
            : IslandEvents.downloadSourcesError === "sudo" ? Translation.tr("nethogs needs passwordless sudo")
            : IslandEvents.downloadSourcesError !== "" ? Translation.tr("Couldn't measure per process")
            : Translation.tr("Identifying…")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.75
        wrapMode: Text.Wrap
    }

    Repeater {
        model: IslandEvents.downloadSourcesError === "" ? xnet.sources : []
        delegate: ColumnLayout {
            id: sourceRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 4

            readonly property bool unknown: sourceRow.modelData.name === "unknown"
            readonly property string label: IslandEvents.sourceLabel(sourceRow.modelData)
            readonly property real sessionBytes: IslandEvents.downloadTotals[sourceRow.label]?.bytes ?? 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    implicitWidth: 22
                    implicitHeight: 22

                    Image {
                        id: sourceIcon
                        anchors.fill: parent
                        visible: !sourceRow.unknown && status === Image.Ready
                        source: sourceRow.unknown ? "" : Quickshell.iconPath(sourceRow.modelData.icon, true)
                        sourceSize.width: 44
                        sourceSize.height: 44
                        asynchronous: true
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !sourceIcon.visible
                        text: sourceRow.unknown ? "lan" : "terminal"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        text: sourceRow.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: sourceRow.index === 0 ? Font.DemiBold : Font.Normal
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: [
                            sourceRow.modelData.pid > 0 ? `PID ${sourceRow.modelData.pid}` : "",
                            `↑ ${IslandEvents.formatBytes(sourceRow.modelData.tx, true)}`,
                            sourceRow.sessionBytes > 0 ? `${IslandEvents.formatBytes(sourceRow.sessionBytes, false)} ${Translation.tr("downloaded")}` : ""
                        ].filter(t => t !== "").join(" · ")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    text: IslandEvents.formatBytes(sourceRow.modelData.rx, true)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: sourceRow.index === 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 1.5
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)

                Rectangle {
                    width: parent.width * Math.min(1, sourceRow.modelData.rx / xnet.maxRx)
                    height: parent.height
                    radius: parent.radius
                    color: sourceRow.index === 0 ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: hintText.text !== ""
        implicitHeight: hintText.implicitHeight + 14
        radius: 10
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)

        StyledText {
            id: hintText
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 10
            }
            text: /^(chrome|chromium|brave|vesktop|code)$/.test(xnet.topName)
                ? Translation.tr("In the browser, Shift+Esc shows which tab is using the network")
                : /^(firefox|zen|zen-bin)$/.test(xnet.topName)
                    ? Translation.tr("In Firefox/Zen, about:processes shows which tab is using the network")
                    : ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            wrapMode: Text.Wrap
        }
    }

    StyledText {
        visible: IslandEvents.recentDownloads.length > 0
        text: Translation.tr("Recent")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: IslandEvents.recentDownloads.slice(0, 3)
        delegate: StyledText {
            required property var modelData
            Layout.fillWidth: true
            text: [
                Qt.formatTime(new Date(modelData.time), "hh:mm"),
                xnet.duration(modelData.seconds * 1000),
                IslandEvents.formatBytes(modelData.bytes, false),
                modelData.sources.map(s => s.label).join(", ") || Translation.tr("unknown source")
            ].join(" · ")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
    }

    RippleButton {
        Layout.alignment: Qt.AlignRight
        implicitHeight: 30
        buttonRadius: 15
        colBackground: Appearance.colors.colLayer2
        onClicked: Qt.openUrlExternally(`file://${IslandEvents.downloadLogPath}`)
        contentItem: RowLayout {
            spacing: 5
            MaterialSymbol {
                Layout.leftMargin: 10
                text: "history"
                iconSize: 15
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                Layout.rightMargin: 12
                text: Translation.tr("Open log")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
            }
        }
    }
}
