import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var monitorConfig
    property real padding: 20
    property int selectedIndex: 0 

    implicitHeight: 220

    property var bounds: {
        let minX = Infinity, minY = Infinity
        let maxX = -Infinity, maxY = -Infinity
        const mons = monitorConfig.monitors
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i]
            if (m.disabled) continue
            const w = monitorConfig.logicalWidth(m)
            const h = monitorConfig.logicalHeight(m)
            minX = Math.min(minX, m.x)
            minY = Math.min(minY, m.y)
            maxX = Math.max(maxX, m.x + w)
            maxY = Math.max(maxY, m.y + h)
        }
        if (minX === Infinity) return { minX: 0, minY: 0, width: 1920, height: 1080 }
        return { minX, minY, width: maxX - minX, height: maxY - minY }
    }

    property real scaleFactor: {
        if (bounds.width === 0 || bounds.height === 0) return 0.1
        const scaleX = (canvas.width  - padding * 2) / bounds.width
        const scaleY = (canvas.height - padding * 2) / bounds.height
        return Math.min(scaleX, scaleY)
    }

    property point offset: Qt.point(
        (canvas.width  - bounds.width  * scaleFactor) / 2 - bounds.minX * scaleFactor,
        (canvas.height - bounds.height * scaleFactor) / 2 - bounds.minY * scaleFactor
    )

    function commitPosition(idx, newX, newY) {
        let m = monitorConfig.monitors.slice()
        m[idx] = Object.assign({}, m[idx], { x: newX, y: newY })
        let minX = Infinity, minY = Infinity
        for (let i = 0; i < m.length; i++) {
            if (m[i].disabled) continue
            minX = Math.min(minX, m[i].x)
            minY = Math.min(minY, m[i].y)
        }
        if (minX < 0 || minY < 0) {
            const offX = minX < 0 ? -minX : 0
            const offY = minY < 0 ? -minY : 0
            for (let i = 0; i < m.length; i++) {
                m[i] = Object.assign({}, m[i], {
                    x: m[i].x + offX,
                    y: m[i].y + offY
                })
            }
        }
        monitorConfig.monitors = m
        for (let i = 0; i < m.length; i++) {
            monitorConfig.applyMonitor(m[i])
        }
        monitorConfig.save()
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Item {
            id: canvas
            anchors.fill: parent

            Repeater {
                model: root.monitorConfig.monitors.length
                delegate: MonitorRect {
                    required property int index
                    monitor: root.monitorConfig.monitors[index]
                    monitorIndex: index
                    monitorConfig: root.monitorConfig
                    scaleFactor: root.scaleFactor
                    canvasOffset: root.offset
                    allMonitors: root.monitorConfig.monitors
                    isSelected: index === root.selectedIndex

                    onMonitorClicked: (idx) => root.selectedIndex = idx
                    onPositionCommitted: (idx, x, y) => root.commitPosition(idx, x, y)
                }
            }
        }
    }
}