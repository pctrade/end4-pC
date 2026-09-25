import QtQuick
import qs.modules.common
import qs.modules.common.functions

// History as a smooth line, newest at the right edge. Values are 0–1.
//
// Unlike the generic Graph it never stretches a short history across the width (that's what drew the diagonal
// to the corner): with fewer samples than `points`, the line simply starts later. Curves pass through the
// midpoints between samples, the fill fades downward, `threshold` draws a faint dashed line where the alert
// kicks in, and a dot marks the current value. Repaints only when a new sample arrives.
Canvas {
    id: spark
    property var values: []
    property int points: 30
    property color color: Appearance.colors.colPrimary
    property real threshold: -1
    property real lineWidth: 2
    property bool showDot: true

    onValuesChanged: spark.requestPaint()
    onColorChanged: spark.requestPaint()
    onWidthChanged: spark.requestPaint()
    onHeightChanged: spark.requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = spark.width
        const h = spark.height
        const pad = spark.lineWidth + (spark.showDot ? 2 : 0)
        const values = Array.from(spark.values ?? []).slice(-spark.points)

        const yOf = v => pad + (1 - Math.max(0, Math.min(1, v))) * (h - pad * 2)

        if (spark.threshold > 0) {
            ctx.strokeStyle = ColorUtils.transparentize(spark.color, 0.7)
            ctx.lineWidth = 1
            ctx.setLineDash([3, 4])
            ctx.beginPath()
            ctx.moveTo(0, yOf(spark.threshold))
            ctx.lineTo(w, yOf(spark.threshold))
            ctx.stroke()
            ctx.setLineDash([])
        }

        if (values.length < 2) return

        const dx = (w - pad) / Math.max(1, spark.points - 1)
        const pts = values.map((v, i) => ({ x: w - pad - (values.length - 1 - i) * dx, y: yOf(v) }))

        const trace = () => {
            ctx.moveTo(pts[0].x, pts[0].y)
            for (let i = 1; i < pts.length - 1; i++) {
                const mx = (pts[i].x + pts[i + 1].x) / 2
                const my = (pts[i].y + pts[i + 1].y) / 2
                ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my)
            }
            ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
        }

        const gradient = ctx.createLinearGradient(0, 0, 0, h)
        gradient.addColorStop(0, ColorUtils.transparentize(spark.color, 0.62))
        gradient.addColorStop(1, ColorUtils.transparentize(spark.color, 1))
        ctx.beginPath()
        trace()
        ctx.lineTo(pts[pts.length - 1].x, h)
        ctx.lineTo(pts[0].x, h)
        ctx.closePath()
        ctx.fillStyle = gradient
        ctx.fill()

        ctx.beginPath()
        trace()
        ctx.strokeStyle = spark.color
        ctx.lineWidth = spark.lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        if (spark.showDot) {
            const last = pts[pts.length - 1]
            ctx.beginPath()
            ctx.arc(last.x, last.y, spark.lineWidth + 1, 0, Math.PI * 2)
            ctx.fillStyle = spark.color
            ctx.fill()
        }
    }
}
