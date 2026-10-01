import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Weather in two columns: now and sun path left, 24 h curve and conditions right.
RowLayout {
    id: xw
    required property Item di
    spacing: 20
    implicitWidth: xw.wantedWidth
    readonly property real wantedWidth: 532

    Component.onCompleted: Weather.requestForecast()

    readonly property bool hasData: (Weather.data?.temp ?? "") !== ""
    readonly property int tempNow: parseInt(Weather.data?.temp ?? "0") || 0
    readonly property int feelsNow: parseInt(Weather.data?.tempFeelsLike ?? "0") || 0
    readonly property real nowTs: DateTime.clock.date.getTime() / 1000
    readonly property string hourFormat: DateTime.use12HourFormat ? "h AP" : "HH:mm"

    readonly property var steps: {
        const first = { dt: 0, temp: xw.tempNow, wCode: Weather.data?.wCode ?? 800, night: Weather.data?.night, pop: 0, isNow: true }
        return [first].concat(Weather.forecast ?? [])
    }
    readonly property int low: Math.min(...xw.steps.map(s => s.temp))
    readonly property int high: Math.max(...xw.steps.map(s => s.temp))

    function timeOf(ts) {
        return Qt.locale().toString(new Date(ts * 1000), xw.hourFormat)
    }
    function capitalized(text) {
        const s = (text ?? "").toString()
        return s.charAt(0).toUpperCase() + s.slice(1)
    }
    function uvLevel(uv) {
        if (uv < 3) return Translation.tr("Low")
        if (uv < 6) return Translation.tr("Moderate")
        if (uv < 8) return Translation.tr("High")
        if (uv < 11) return Translation.tr("Very high")
        return Translation.tr("Extreme")
    }
    function compass(deg) {
        const points = Translation.tr("N NE E SE S SW W NW").split(" ")
        return points[Math.round(((deg % 360) + 360) % 360 / 45) % 8] ?? ""
    }
    function windText() {
        const speed = Weather.data?.windSpeed ?? 0
        return Weather.useUSCS ? `${Math.round(speed)} mph` : `${Math.round(speed * 3.6)} km/h`
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string value: ""
        property string label: ""
        // 0..1 fills the chip's background from the left as it comes in; -1 = no fill
        property real meter: -1
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        radius: 12
        color: Appearance.colors.colLayer1
        clip: true

        DiSpring {
            id: meterFill
            stiffness: 70
            dampingRatio: 0.9
            epsilon: 0.002
        }
        Timer {
            interval: 420
            running: chip.meter >= 0
            onTriggered: meterFill.target = 1
        }
        Rectangle {
            visible: chip.meter >= 0
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: chip.width * Math.max(0, Math.min(1, chip.meter)) * meterFill.value
            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.86)
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 8
            }
            spacing: 8

            MaterialSymbol {
                text: chip.icon
                iconSize: 18
                fill: 1
                color: Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1
                StyledText {
                    Layout.fillWidth: true
                    text: chip.value
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: chip.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
        }
    }

    ColumnLayout {
        // Children filling the width would otherwise make this column fill the row too
        Layout.fillWidth: false
        Layout.preferredWidth: 180
        Layout.maximumWidth: 180
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            id: cityRow
            spacing: 4
            DiCascade { target: cityRow; index: 0 }

            MaterialSymbol {
                text: "location_on"
                iconSize: 15
                fill: 1
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
            StyledText {
                Layout.maximumWidth: 160
                text: Weather.data?.city ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                opacity: 0.75
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: nowRow
            Layout.topMargin: 6
            spacing: 10
            DiCascade { target: nowRow; index: 1 }

            MaterialSymbol {
                text: IslandEvents.weatherSymbol(Weather.data?.wCode ?? 800, Weather.data?.night)
                iconSize: 50
                fill: 1
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: xw.hasData ? `${xw.tempNow}°` : "–"
                font.pixelSize: 46
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
        }

        ColumnLayout {
            id: nowText
            Layout.fillWidth: true
            spacing: 1
            DiCascade { target: nowText; index: 2 }

            StyledText {
                Layout.fillWidth: true
                text: xw.capitalized(Weather.data?.description)
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: `${Translation.tr("Feels like")} ${xw.feelsNow}° · ${Translation.tr("Low %1 · High %2").arg(xw.low + "°").arg(xw.high + "°")}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            id: sunArc
            Layout.fillWidth: true
            implicitHeight: 84
            DiCascade { target: sunArc; index: 3 }

            readonly property real rise: Weather.data?.sunriseTs ?? 0
            readonly property real set: Weather.data?.sunsetTs ?? 0
            readonly property bool known: sunArc.rise > 0 && sunArc.set > sunArc.rise
            readonly property bool isDay: xw.nowTs >= sunArc.rise && xw.nowTs < sunArc.set
            // After sunset the next sunrise is about a day after today's; before sunrise the last sunset was yesterday's
            readonly property real nextRise: xw.nowTs < sunArc.rise ? sunArc.rise : sunArc.rise + 86400
            readonly property real lastSet: xw.nowTs < sunArc.rise ? sunArc.set - 86400 : sunArc.set
            readonly property real phase: !sunArc.known ? 0
                : sunArc.isDay ? (xw.nowTs - sunArc.rise) / (sunArc.set - sunArc.rise)
                : Math.max(0, Math.min(1, (xw.nowTs - sunArc.lastSet) / (sunArc.nextRise - sunArc.lastSet)))
            readonly property real shown: sunArc.phase * arcReveal.value
            readonly property color tint: sunArc.isDay ? Appearance.colors.colPrimary : Appearance.colors.colTertiary

            readonly property real cx: arcCanvas.width / 2
            readonly property real cy: arcCanvas.height - 3
            readonly property real rx: arcCanvas.width / 2 - 10
            readonly property real ry: arcCanvas.height - 14
            function pointAt(t) {
                return Qt.point(sunArc.cx - sunArc.rx * Math.cos(t * Math.PI), sunArc.cy - sunArc.ry * Math.sin(t * Math.PI))
            }

            DiSpring {
                id: arcReveal
                stiffness: 55
                dampingRatio: 1
                epsilon: 0.002
            }
            Timer {
                interval: 260
                running: true
                onTriggered: arcReveal.target = 1
            }

            onShownChanged: arcCanvas.requestPaint()
            onTintChanged: arcCanvas.requestPaint()

            Canvas {
                id: arcCanvas
                width: parent.width
                height: 58
                readonly property color lineColor: Appearance.colors.colOnLayer0
                onLineColorChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const trace = (from, to) => {
                        ctx.beginPath()
                        for (let i = 0; i <= 48; i++) {
                            const p = sunArc.pointAt(from + (to - from) * i / 48)
                            if (i === 0) ctx.moveTo(p.x, p.y)
                            else ctx.lineTo(p.x, p.y)
                        }
                    }

                    ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, sunArc.cy)
                    ctx.lineTo(width, sunArc.cy)
                    ctx.stroke()

                    ctx.setLineDash([3, 4])
                    ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.25)
                    ctx.lineWidth = 1.5
                    trace(0, 1)
                    ctx.stroke()
                    ctx.setLineDash([])
                    if (sunArc.shown <= 0.001) return

                    const tint = sunArc.tint
                    trace(0, sunArc.shown)
                    const tip = sunArc.pointAt(sunArc.shown)
                    ctx.lineTo(tip.x, sunArc.cy)
                    ctx.lineTo(sunArc.pointAt(0).x, sunArc.cy)
                    ctx.closePath()
                    const fill = ctx.createLinearGradient(0, sunArc.cy - sunArc.ry, 0, sunArc.cy)
                    fill.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0.22))
                    fill.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0.02))
                    ctx.fillStyle = fill
                    ctx.fill()

                    trace(0, sunArc.shown)
                    ctx.strokeStyle = tint
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }

            Item {
                id: body
                readonly property point at: sunArc.pointAt(sunArc.shown)
                visible: sunArc.known
                x: body.at.x - width / 2
                y: body.at.y - height / 2
                width: 22
                height: 22
                scale: 0.4 + 0.6 * arcReveal.value
                opacity: Math.min(1, arcReveal.value * 3)

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: xw.di.surfaceColor
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: ColorUtils.transparentize(sunArc.tint, 0.78)
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: sunArc.isDay ? "light_mode" : "dark_mode"
                    iconSize: 15
                    fill: 1
                    color: sunArc.tint
                    rotation: sunArc.isDay ? (1 - arcReveal.value) * -90 : 0
                }
            }

            StyledText {
                anchors.horizontalCenter: arcCanvas.horizontalCenter
                y: arcCanvas.height - height - 4
                visible: sunArc.known
                text: sunArc.isDay
                    ? Translation.tr("Sunset in %1").arg(xw.di.formatDuration(sunArc.set - xw.nowTs))
                    : Translation.tr("Sunrise in %1").arg(xw.di.formatDuration(sunArc.nextRise - xw.nowTs))
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }

            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: 4
                visible: sunArc.known

                MaterialSymbol {
                    text: sunArc.isDay ? "wb_twilight" : "nights_stay"
                    iconSize: 14
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.55
                }
                StyledText {
                    Layout.fillWidth: true
                    text: xw.timeOf(sunArc.isDay ? sunArc.rise : sunArc.lastSet)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
                StyledText {
                    text: xw.timeOf(sunArc.isDay ? sunArc.set : sunArc.nextRise)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
                MaterialSymbol {
                    text: sunArc.isDay ? "nights_stay" : "wb_twilight"
                    iconSize: 14
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.55
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        spacing: 6

        SectionLabel {
            id: hoursLabel
            text: Translation.tr("Next hours")
            DiCascade { target: hoursLabel; index: 0 }
        }

        Item {
            id: strip
            Layout.fillWidth: true
            implicitHeight: 100

            readonly property var steps: xw.steps
            readonly property real colW: strip.width / Math.max(1, strip.steps.length)
            readonly property real curveTop: 58
            readonly property real curveBottom: 82
            function yFor(temp) {
                const span = Math.max(1, xw.high - xw.low)
                return strip.curveBottom - (temp - xw.low) / span * (strip.curveBottom - strip.curveTop)
            }

            onStepsChanged: curve.requestPaint()
            onWidthChanged: curve.requestPaint()

            readonly property real drawnX: curveReveal.value * strip.width
            onDrawnXChanged: curve.requestPaint()
            DiSpring {
                id: curveReveal
                stiffness: 38
                dampingRatio: 1
                epsilon: 0.001
            }
            Timer {
                interval: 140
                running: true
                onTriggered: curveReveal.target = 1
            }

            StyledText {
                anchors.centerIn: parent
                visible: (Weather.forecast ?? []).length === 0
                text: Translation.tr("Loading forecast…")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.5
            }

            Canvas {
                id: curve
                anchors.fill: parent
                visible: strip.steps.length > 1
                readonly property color lineColor: Appearance.colors.colPrimary
                onLineColorChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const pts = strip.steps.map((s, i) => [(i + 0.5) * strip.colW, strip.yFor(s.temp)])
                    if (pts.length < 2 || strip.drawnX <= 0) return
                    ctx.save()
                    ctx.beginPath()
                    ctx.rect(0, 0, strip.drawnX, height)
                    ctx.clip()
                    const path = () => {
                        ctx.beginPath()
                        ctx.moveTo(pts[0][0], pts[0][1])
                        for (let i = 1; i < pts.length - 1; i++) {
                            const mx = (pts[i][0] + pts[i + 1][0]) / 2
                            const my = (pts[i][1] + pts[i + 1][1]) / 2
                            ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my)
                        }
                        ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1])
                    }

                    path()
                    ctx.lineTo(pts[pts.length - 1][0], strip.curveBottom + 6)
                    ctx.lineTo(pts[0][0], strip.curveBottom + 6)
                    ctx.closePath()
                    const fill = ctx.createLinearGradient(0, strip.curveTop, 0, strip.curveBottom + 6)
                    fill.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.18))
                    fill.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
                    ctx.fillStyle = fill
                    ctx.fill()

                    path()
                    ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.7)
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.stroke()
                    ctx.restore()
                }
            }

            Repeater {
                model: strip.steps.length

                Item {
                    id: hour
                    required property int index
                    readonly property var modelData: strip.steps[hour.index] ?? ({})
                    x: hour.index * strip.colW
                    width: strip.colW
                    height: strip.height
                    DiCascade { target: hour; index: hour.index + 1; step: 28 }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hour.modelData.isNow ? Translation.tr("Now") : xw.timeOf(hour.modelData.dt)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: hour.modelData.isNow ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                        opacity: hour.modelData.isNow ? 0.9 : 0.55
                    }
                    MaterialSymbol {
                        y: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: IslandEvents.weatherSymbol(hour.modelData.wCode, hour.modelData.night)
                        iconSize: 20
                        fill: 1
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.85
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: strip.yFor(hour.modelData.temp) - 19
                        text: `${hour.modelData.temp}°`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                    }
                    Rectangle {
                        x: (parent.width - width) / 2
                        y: strip.yFor(hour.modelData.temp) - height / 2
                        scale: Math.max(0, Math.min(1, (strip.drawnX - hour.x - hour.width / 2) / 14))
                        width: hour.modelData.isNow ? 8 : 6
                        height: width
                        radius: width / 2
                        color: Appearance.colors.colPrimary
                        border.width: hour.modelData.isNow ? 2 : 0
                        border.color: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        visible: hour.modelData.pop >= 0.2
                        text: `${Math.round(hour.modelData.pop * 100)}%`
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            columns: 2
            rowSpacing: 6
            columnSpacing: 6

            Chip {
                id: uvChip
                DiCascade { target: uvChip; index: 4 }
                icon: "light_mode"
                value: Weather.uvNow >= 0 ? `${Math.round(Weather.uvNow)} · ${xw.uvLevel(Weather.uvNow)}` : "–"
                meter: Weather.uvNow >= 0 ? Weather.uvNow / 11 : -1
                label: Weather.uvMax >= 0 ? Translation.tr("UV · peak %1").arg(Math.round(Weather.uvMax)) : Translation.tr("UV index")
            }
            Chip {
                id: humidityChip
                DiCascade { target: humidityChip; index: 5 }
                icon: "water_drop"
                value: Weather.data?.humidity ?? "–"
                meter: (parseInt(Weather.data?.humidity ?? "") || 0) / 100
                label: Translation.tr("Humidity")
            }
            Chip {
                id: windChip
                DiCascade { target: windChip; index: 6 }
                icon: "air"
                value: xw.windText()
                label: `${Translation.tr("Wind")} · ${xw.compass(Weather.data?.windDir ?? 0)}`
            }
            Chip {
                id: pressureChip
                DiCascade { target: pressureChip; index: 7 }
                icon: "compress"
                value: Weather.data?.press ?? "–"
                label: Translation.tr("Pressure")
            }
        }
    }
}
