import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var monitor
    required property int monitorIndex
    required property var monitorConfig
    required property real scaleFactor
    required property point canvasOffset
    required property var allMonitors
    property bool isSelected: false

    signal positionCommitted(int index, int x, int y)
    signal monitorClicked(int index)

    property bool isDragging: false
    property real dragX: 0
    property real dragY: 0
    property int snappedX: 0
    property int snappedY: 0
    property real snapThreshold: 12

    property int logW: monitorConfig.logicalWidth(monitor)
    property int logH: monitorConfig.logicalHeight(monitor)

    x: isDragging ? dragX : monitor.x * scaleFactor + canvasOffset.x
    y: isDragging ? dragY : monitor.y * scaleFactor + canvasOffset.y
    width:  logW * scaleFactor
    height: logH * scaleFactor

    radius: Appearance.rounding.small
    z: isDragging ? 100 : isSelected ? 2 : 1

    color: {
        if (monitor.disabled)        return Appearance.colors.colLayer2
        if (isDragging)              return Qt.alpha(Appearance.colors.colPrimaryContainer, 0.7)
        if (isSelected)              return Appearance.colors.colPrimaryContainer
        if (hoverArea.containsMouse) return Appearance.colors.colSecondaryContainerHover
        return Appearance.colors.colSecondaryContainer
    }
    border.color: (isDragging || isSelected)
        ? Appearance.colors.colPrimary
        : Appearance.colors.colLayer0Border
    border.width: (isDragging || isSelected) ? 2 : 1

    Behavior on x { enabled: !isDragging; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !isDragging; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        visible: root.isDragging
        x: root.snappedX * root.scaleFactor + root.canvasOffset.x - root.x
        y: root.snappedY * root.scaleFactor + root.canvasOffset.y - root.y
        width: root.width
        height: root.height
        radius: root.radius
        color: "transparent"
        border.color: Appearance.colors.colPrimary
        border.width: 2
        opacity: 0.6
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor.disabled ? "desktop_access_disabled" : "desktop_windows"
            iconSize: Math.min(20, Math.min(root.width * 0.25, root.height * 0.25))
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colPrimary
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor.name
            font.pixelSize: Math.max(9, Math.min(13, root.width * 0.1))
            font.weight: Font.Medium
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnSecondaryContainer
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.width - 8)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${root.logW}x${root.logH}`
            font.pixelSize: Math.max(8, Math.min(10, root.width * 0.08))
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
        }
    }

    function snapPosition(px, py) {
        let sx = px, sy = py
        const thresh = snapThreshold / scaleFactor
        for (let i = 0; i < allMonitors.length; i++) {
            if (i === monitorIndex) continue
            const other = allMonitors[i]
            if (other.disabled) continue
            const ow = monitorConfig.logicalWidth(other)
            const oh = monitorConfig.logicalHeight(other)
            if (Math.abs(px - other.x) < thresh)                 sx = other.x
            if (Math.abs(px - (other.x + ow)) < thresh)          sx = other.x + ow
            if (Math.abs((px + logW) - other.x) < thresh)        sx = other.x - logW
            if (Math.abs((px + logW) - (other.x + ow)) < thresh) sx = other.x + ow - logW
            if (Math.abs(py - other.y) < thresh)                 sy = other.y
            if (Math.abs(py - (other.y + oh)) < thresh)          sy = other.y + oh
            if (Math.abs((py + logH) - other.y) < thresh)        sy = other.y - logH
            if (Math.abs((py + logH) - (other.y + oh)) < thresh) sy = other.y + oh - logH
        }
        return Qt.point(sx, sy)
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !monitor.disabled
        cursorShape: monitor.disabled ? Qt.ArrowCursor
            : (root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.threshold: 4  

        onPressed: {
            root.dragX = monitor.x * root.scaleFactor + root.canvasOffset.x
            root.dragY = monitor.y * root.scaleFactor + root.canvasOffset.y
            root.snappedX = monitor.x
            root.snappedY = monitor.y
            root.isDragging = true
        }

        onPositionChanged: {
            if (!root.isDragging) return
            root.dragX = root.x
            root.dragY = root.y
            const realX = Math.round((root.x - root.canvasOffset.x) / root.scaleFactor)
            const realY = Math.round((root.y - root.canvasOffset.y) / root.scaleFactor)
            const snapped = root.snapPosition(realX, realY)
            root.snappedX = snapped.x
            root.snappedY = snapped.y
        }

        onReleased: {
            root.isDragging = false
            if (root.snappedX === monitor.x && root.snappedY === monitor.y) {
                root.monitorClicked(root.monitorIndex)
                return
            }
            root.positionCommitted(root.monitorIndex, root.snappedX, root.snappedY)
        }
    }
}