import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property color backgroundColor: Appearance.colors.colPrimary
    property color handColor:       Appearance.colors.colOnPrimary
    property color centerDotColor:  Appearance.colors.colOnPrimary
    property string label:          ""
    property color labelColor:      Qt.rgba(
        Appearance.colors.colOnPrimary.r,
        Appearance.colors.colOnPrimary.g,
        Appearance.colors.colOnPrimary.b,
        0.75)
    property real labelSpacing: 12
    property real radius: Appearance.rounding.large

    property real hourAngle:   0
    property real minuteAngle: 0

    property bool autoTime: true

    Timer {
        interval: 1000
        running:  root.autoTime
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            const h   = now.getHours() % 12
            const m   = now.getMinutes()
            const s   = now.getSeconds()
            root.minuteAngle = m * 6 + s * 0.1
            root.hourAngle   = h * 30 + m * 0.5
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color:  root.backgroundColor
        radius: root.radius

        Behavior on color { ColorAnimation { duration: 400 } }
    }

    Canvas {
        id: clockCanvas
        anchors.fill: parent

        property real cx: width  / 2
        property real cy: height / 2
        property real r:  Math.min(width, height) * 0.36

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx = clockCanvas.cx
            const cy = clockCanvas.cy
            const r  = clockCanvas.r

            const hRad = (root.hourAngle   - 90) * Math.PI / 180
            const mRad = (root.minuteAngle - 90) * Math.PI / 180

            ctx.save()
            ctx.strokeStyle = root.handColor.toString()
            ctx.lineWidth   = Math.max(3, r * 0.095)
            ctx.lineCap     = "round"
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(
                cx + Math.cos(hRad) * r * 0.55,
                cy + Math.sin(hRad) * r * 0.55
            )
            ctx.stroke()
            ctx.restore()

            ctx.save()
            ctx.strokeStyle = root.handColor.toString()
            ctx.lineWidth   = Math.max(2, r * 0.045)
            ctx.lineCap     = "round"
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(
                cx + Math.cos(mRad) * r * 0.82,
                cy + Math.sin(mRad) * r * 0.82
            )
            ctx.stroke()
            ctx.restore()

            const dotR = Math.max(4, r * 0.055)
            ctx.beginPath()
            ctx.arc(cx, cy, dotR, 0, Math.PI * 2)
            ctx.fillStyle = root.centerDotColor.toString()
            ctx.fill()

            if (root.label !== "") {
                const dotBottom = cy + dotR + root.labelSpacing
                ctx.font         = `${Math.max(11, r * 0.2)}px sans-serif`
                ctx.fillStyle    = root.labelColor.toString()
                ctx.textAlign    = "center"
                ctx.textBaseline = "top"
                ctx.fillText(root.label, cx, dotBottom)
            }
        }

        Connections {
            target: root
            function onHourAngleChanged()      { clockCanvas.requestPaint() }
            function onMinuteAngleChanged()    { clockCanvas.requestPaint() }
            function onLabelChanged()          { clockCanvas.requestPaint() }
            function onHandColorChanged()      { clockCanvas.requestPaint() }
            function onCenterDotColorChanged() { clockCanvas.requestPaint() }
            function onLabelColorChanged()     { clockCanvas.requestPaint() }
        }

        Connections {
            target: Appearance.colors
            function onColPrimaryChanged()        { clockCanvas.requestPaint() }
            function onColOnPrimaryChanged()      { clockCanvas.requestPaint() }
        }

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
    }
}
