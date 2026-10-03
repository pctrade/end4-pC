import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    property bool mirrored: false
    property bool islandMode: false
    property bool islandExpanded: true
    property bool islandAnchorRight: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property list<real> points: GlobalStates.visualizerPoints
    property int barCount: 20
    property real dotSize: 3
    property real dotSpacing: 3
    property real maxBarHeight: (vertical
        ? Appearance.sizes.verticalBarWidth
        : Appearance.sizes.barHeight) * 0.7
    property real maxVisualizerValue: 1000
    property bool frameSmoothing: islandMode
    property list<real> smoothedPoints: []
    readonly property list<real> renderedPoints: frameSmoothing ? smoothedPoints : points
    readonly property int compactBarCount: Math.max(1, Math.round(barCount / 3))
    property real expansionProgress: islandExpanded ? 1 : 0
    readonly property int displayedBarCount: islandMode && expansionProgress <= 0.001
        ? compactBarCount : barCount

    Behavior on expansionProgress {
        enabled: root.islandMode
        NumberAnimation {
            readonly property bool simultaneous:
                Config.options.bar.dynamicIsland.animationStyle === "simultaneous"
            duration: simultaneous ? 200 : 350
            easing.type: simultaneous ? Easing.OutCubic : Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        }
    }

    FrameAnimation {
        running: root.frameSmoothing && root.isPlaying
        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            const values = new Array(root.barCount)
            for (let i = 0; i < root.barCount; i++) {
                const sourceIndex = Math.floor(i * root.points.length / root.barCount)
                const target = root.points.length > 0 ? (root.points[sourceIndex] ?? 0) : 0
                const current = root.smoothedPoints[i] ?? 0
                const speed = target > current ? 22 : 10
                values[i] = current + (target - current) * Math.min(1, dt * speed)
            }
            root.smoothedPoints = values
        }
    }

    function spectrumValue(barIndex) {
        const values = root.renderedPoints
        if (values.length === 0) return 0
        if (root.displayedBarCount === root.barCount) {
            const sourceIndex = Math.floor(barIndex * values.length / root.barCount)
            return values[sourceIndex] ?? 0
        }

        // In compact mode each bar represents a complete frequency band, so
        // reducing the number of bars does not discard either end of the spectrum.
        const start = Math.floor(barIndex * values.length / root.displayedBarCount)
        const end = Math.max(start + 1,
            Math.floor((barIndex + 1) * values.length / root.displayedBarCount))
        let total = 0
        for (let i = start; i < Math.min(end, values.length); i++)
            total += values[i] ?? 0
        return total / Math.max(1, Math.min(end, values.length) - start)
    }

    readonly property real fullHorizontalWidth: barCount * dotSize
        + (barCount - 1) * dotSpacing
        + (isMaterial && !islandMode ? 16 : 0)
    readonly property real compactHorizontalWidth: compactBarCount * dotSize
        + (compactBarCount - 1) * dotSpacing
    implicitWidth: vertical
        ? Appearance.sizes.verticalBarWidth
        : (islandMode
            ? compactHorizontalWidth
                + (fullHorizontalWidth - compactHorizontalWidth) * expansionProgress
            : fullHorizontalWidth)
    implicitHeight: vertical
        ? (isMaterial
            ? barsColumn.implicitHeight + 16
            : barCount * (dotSize + dotSpacing))
        : Appearance.sizes.barHeight
    clip: islandMode

    transform: Scale {
        xScale: !root.vertical && root.mirrored ? -1 : 1
        origin.x: root.width / 2
    }


    Row {
        id: barsRow
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.islandMode && !root.islandAnchorRight ? parent.left : undefined
        anchors.right: root.islandMode && root.islandAnchorRight ? parent.right : undefined
        anchors.horizontalCenter: root.islandMode ? undefined : parent.horizontalCenter
        spacing: root.dotSpacing

        Repeater {
            model: root.displayedBarCount
            Rectangle {
                required property int index
                width: root.dotSize
                property real pointValue: {
                    if (!root.isPlaying || root.points.length === 0) return root.dotSize
                    const v = root.spectrumValue(index)
                    return Math.max(root.dotSize, (v / root.maxVisualizerValue) * root.maxBarHeight)
                }
                height: pointValue
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.contentColor
                opacity: root.isPlaying ? 0.85 : 0.3
                Behavior on height {
                    enabled: !root.frameSmoothing
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }

    Column {
        id: barsColumn
        visible: root.vertical
        anchors.centerIn: parent
        spacing: root.dotSpacing

        Repeater {
            model: root.displayedBarCount
            Rectangle {
                required property int index
                height: root.dotSize
                property real pointValue: {
                    if (!root.isPlaying || root.points.length === 0) return root.dotSize
                    const rawIndex = root.mirrored ? (root.displayedBarCount - 1 - index) : index
                    const v = root.spectrumValue(rawIndex)
                    return Math.max(root.dotSize, (v / root.maxVisualizerValue) * root.maxBarHeight)
                }
                width: pointValue
                radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Appearance.colors.colPrimary
                opacity: root.isPlaying ? 0.85 : 0.3
                Behavior on width {
                    enabled: !root.frameSmoothing
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
}
