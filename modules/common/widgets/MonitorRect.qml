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
    property var previewPositions: ({})
    property bool hasOverlap: false

    signal positionCommitted(int index, int x, int y)
    signal monitorClicked(int index)
    // Landing (snapped) and hand (raw) positions of the drag.
    signal positionDragging(int index, int x, int y, int rawX, int rawY)

    property bool isDragging: false
    property int snappedX: 0
    property int snappedY: 0
    property real snapThreshold: 12
    // Manual grab, no drag.target: drag.target would write x/y directly and
    // destroy the bindings below, after which the rectangle stops following
    // the model and stays wherever the mouse let go.
    property real pressSceneX: 0
    property real pressSceneY: 0
    // Logical position at press — same expression as the x/y binding. The
    // cursor delta converts with pressScale, the fit frozen at press time,
    // so the live view can zoom without feeding back into the drag.
    property real pressLogX: 0
    property real pressLogY: 0
    property real pressScale: 1
    readonly property real dragThresholdPx: 4

    property int logW: monitorConfig?.logicalWidth(monitor) ?? 0
    property int logH: monitorConfig?.logicalHeight(monitor) ?? 0

    // One expression for resting and for dragging: during a drag
    // previewPositions holds the raw hand position, everything on the canvas
    // goes through this one live fit, and the ghost border below previews the
    // landing spot the overlap test and the commit will use.
    x: (previewPositions[monitor.name]?.x ?? monitor.x) * scaleFactor + canvasOffset.x
    y: (previewPositions[monitor.name]?.y ?? monitor.y) * scaleFactor + canvasOffset.y
    width:  logW * scaleFactor
    height: logH * scaleFactor

    radius: Appearance.rounding.small
    z: isDragging ? 100 : isSelected ? 2 : 1

    color: {
        if (monitor.disabled)             return Appearance.colors.colLayer2
        if (isDragging && hasOverlap)     return Qt.alpha(Appearance.m3colors.m3error, 0.5)
        if (isDragging)                   return Qt.alpha(Appearance.colors.colPrimaryContainer, 0.7)
        if (isSelected)                   return Appearance.colors.colPrimaryContainer
        if (hoverArea.containsMouse)      return Appearance.colors.colSecondaryContainerHover
        return Appearance.colors.colSecondaryContainer
    }

    border.color: (isDragging && hasOverlap) ? Appearance.m3colors.m3error
        : (isDragging || isSelected) ? Appearance.colors.colPrimary
        : Appearance.colors.colLayer0Border
    border.width: (isDragging || isSelected) ? 2 : 1

    Behavior on x { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }

    // Landing preview: where the drop will go (snapped, normalized) when it
    // is allowed. Coincides with the hand when nothing snaps.
    Rectangle {
        visible: root.isDragging && !root.hasOverlap
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
            text: monitor?.name ?? ""
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
        // Frozen press fit: how far a snap reaches must not depend on the
        // zoom, or the landing would depend on the view instead of the cursor.
        const thresh = snapThreshold / pressScale
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
        preventStealing: true

        onPressed: (mouse) => {
            root.pressSceneX = root.x + mouse.x
            root.pressSceneY = root.y + mouse.y
            root.pressLogX = root.previewPositions[monitor.name]?.x ?? monitor.x
            root.pressLogY = root.previewPositions[monitor.name]?.y ?? monitor.y
            root.pressScale = root.scaleFactor
            root.snappedX = monitor.x
            root.snappedY = monitor.y
            root.isDragging = false
        }

        onPositionChanged: (mouse) => {
            if (!hoverArea.pressed) return
            // Cursor in canvas space, taken off the rectangle itself, so it is
            // right whatever the fit is doing.
            const sceneX = root.x + mouse.x
            const sceneY = root.y + mouse.y
            const moved = Math.abs(sceneX - root.pressSceneX) >= root.dragThresholdPx
                || Math.abs(sceneY - root.pressSceneY) >= root.dragThresholdPx
            if (!root.isDragging && !moved) return
            // Delta from the grab point, converted with the fit frozen at
            // press: the live view zooms, the position being previewed does
            // not move under the cursor.
            const realX = Math.round(root.pressLogX + (sceneX - root.pressSceneX) / root.pressScale)
            const realY = Math.round(root.pressLogY + (sceneY - root.pressSceneY) / root.pressScale)
            const snapped = root.snapPosition(realX, realY)
            root.snappedX = snapped.x
            root.snappedY = snapped.y
            // isDragging first, so the position Behaviour is already off when
            // previewPositions moves the rectangle.
            root.isDragging = true
            root.positionDragging(root.monitorIndex, root.snappedX, root.snappedY, realX, realY)
        }

        onReleased: {
            root.isDragging = false
            if (root.snappedX === monitor.x && root.snappedY === monitor.y) {
                root.monitorClicked(root.monitorIndex)
                return
            }
            root.positionCommitted(root.monitorIndex, root.snappedX, root.snappedY)
        }

        onCanceled: root.isDragging = false
    }
}