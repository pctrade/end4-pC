import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Pinned system island: one metric at a time, scroll to move through them
Item {
    id: sys
    required property Item di
    anchors.fill: parent

    readonly property var metrics: [
        { icon: "memory", label: "CPU", text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`, history: ResourceUsage.cpuUsageHistory, alert: ResourceUsage.cpuUsage >= 0.9 },
        { icon: "developer_board", label: Translation.tr("Memory"), text: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`, history: ResourceUsage.memoryUsageHistory, alert: ResourceUsage.memoryUsedPercentage >= 0.9 },
        { icon: "thermostat", label: Translation.tr("Temperature"), text: `${Math.round(ResourceUsage.cpuTemp)}°C`, history: [], alert: ResourceUsage.cpuTemp >= 85 },
        { icon: "hard_drive", label: Translation.tr("Disk"), text: `${Math.round(ResourceUsage.diskUsedPercentage * 100)}%`, history: ResourceUsage.diskUsageHistory, alert: ResourceUsage.diskUsedPercentage >= 0.9 },
        { icon: "swap_horiz", label: "Swap", text: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%`, history: ResourceUsage.swapUsageHistory, alert: false },
        { icon: "network_check", label: Translation.tr("Network"), text: `↓ ${IslandEvents.formatBytes(IslandEvents.downloadRate, true)}`, history: [], alert: false }
    ]
    readonly property int index: ((sys.di.systemMetric % sys.metrics.length) + sys.metrics.length) % sys.metrics.length
    readonly property var metric: sys.metrics[sys.index]
    readonly property color accent: sys.metric.alert ? Appearance.colors.colError : Appearance.colors.colPrimary

    // Metric changes slide in from the direction of the scroll
    property int lastIndex: sys.index
    property real slide: 0

    onIndexChanged: {
        sys.slide = (sys.index > sys.lastIndex ? 1 : -1) * 12
        sys.lastIndex = sys.index
        slideAnim.restart()
    }

    NumberAnimation {
        id: slideAnim
        target: sys
        property: "slide"
        to: 0
        duration: IslandMotion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 14
        }
        spacing: 7
        opacity: 1 - Math.min(1, Math.abs(sys.slide) / 14)
        transform: Translate { y: sys.slide }

        MaterialSymbol {
            text: sys.metric.icon
            iconSize: 17
            fill: 1
            color: sys.accent
        }

        StyledText {
            text: sys.metric.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }

        Graph {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            visible: sys.metric.history.length > 1
            values: sys.metric.history.slice(-24)
            points: 24
            color: sys.accent
            fillOpacity: 0.25
        }

        Item {
            Layout.fillWidth: true
            visible: sys.metric.history.length <= 1
        }

        StyledText {
            text: sys.metric.text
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: sys.metric.alert ? Appearance.colors.colError : Appearance.colors.colOnLayer0
        }
    }

    // Position among the metrics
    Column {
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Repeater {
            model: sys.metrics.length
            delegate: Rectangle {
                required property int index
                width: 2
                height: index === sys.index ? 6 : 2
                radius: 1
                color: index === sys.index ? sys.accent : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)

                Behavior on height {
                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
