import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property bool vertical: false
    property real downloadBytesPerSecond: 0
    property real uploadBytesPerSecond: 0
    property real downloadedBytes: 0
    property real uploadedBytes: 0
    property real previousReceivedBytes: -1
    property real previousTransmittedBytes: -1
    property double previousSampleTime: 0

    implicitWidth: vertical ? 36 : speedColumn.implicitWidth + 8
    implicitHeight: vertical ? speedColumn.implicitHeight + 6 : 32

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    function formatRate(rate, compact) {
        const units = compact
            ? ["B", "K", "M", "G"]
            : ["B/s", "KB/s", "MB/s", "GB/s"]
        let value = Math.max(0, Number(rate) || 0)
        let unitIndex = 0

        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024
            unitIndex++
        }

        const precision = unitIndex > 0 && value < 100 ? 1 : 0
        return `${value.toFixed(precision)}${compact ? "" : " "}${units[unitIndex]}`
    }

    function updateRate(contents) {
        let receivedBytes = 0
        let transmittedBytes = 0
        const lines = contents.split("\n")

        for (const line of lines) {
            const separator = line.indexOf(":")
            if (separator < 0) continue

            const interfaceName = line.slice(0, separator).trim()
            if (!interfaceName || interfaceName === "lo") continue

            const fields = line.slice(separator + 1).trim().split(/\s+/)
            if (fields.length < 9) continue

            const received = Number(fields[0])
            const transmitted = Number(fields[8])
            if (!Number.isFinite(received) || !Number.isFinite(transmitted)) continue

            receivedBytes += received
            transmittedBytes += transmitted
        }

        const sampleTime = Date.now()
        if (previousSampleTime > 0 && sampleTime > previousSampleTime) {
            const elapsedMilliseconds = sampleTime - previousSampleTime
            const receivedDelta = receivedBytes >= previousReceivedBytes
                ? receivedBytes - previousReceivedBytes
                : 0
            const transmittedDelta = transmittedBytes >= previousTransmittedBytes
                ? transmittedBytes - previousTransmittedBytes
                : 0

            downloadBytesPerSecond = receivedDelta * 1000 / elapsedMilliseconds
            uploadBytesPerSecond = transmittedDelta * 1000 / elapsedMilliseconds
            downloadedBytes += receivedDelta
            uploadedBytes += transmittedDelta
        }

        previousReceivedBytes = receivedBytes
        previousTransmittedBytes = transmittedBytes
        previousSampleTime = sampleTime
    }

    FileView {
        id: networkStats
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.updateRate(text())
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: networkStats.reload()
    }

    TextMetrics {
        id: regularRateMetrics
        text: "999.9 MB/s"
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.Medium
    }

    component SpeedLine: RowLayout {
        id: speedLine

        required property string iconName
        required property real rate
        required property color accentColor

        readonly property string rateText: root.formatRate(rate, root.vertical)

        spacing: root.vertical ? 1 : 3

        MaterialSymbol {
            text: speedLine.iconName
            iconSize: root.vertical
                ? Appearance.font.pixelSize.smallest
                : Appearance.font.pixelSize.smaller
            color: speedLine.accentColor
            opacity: speedLine.rate > 0 ? 1 : 0.45

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        StyledText {
            Layout.preferredWidth: root.vertical ? -1 : regularRateMetrics.width
            horizontalAlignment: Text.AlignRight
            text: speedLine.rateText
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    ColumnLayout {
        id: speedColumn
        anchors.centerIn: parent
        spacing: -3

        SpeedLine {
            iconName: "arrow_upward"
            rate: root.uploadBytesPerSecond
            accentColor: Appearance.colors.colTertiary
        }

        SpeedLine {
            iconName: "arrow_downward"
            rate: root.downloadBytesPerSecond
            accentColor: Appearance.colors.colPrimary
        }
    }

    NetworkSpeedPopup {
        hoverTarget: root
        downloadSpeed: root.downloadBytesPerSecond
        uploadSpeed: root.uploadBytesPerSecond
        downloadedBytes: root.downloadedBytes
        uploadedBytes: root.uploadedBytes
    }
}
