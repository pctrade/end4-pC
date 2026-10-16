import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    readonly property bool shouldShow: root.hoverTarget && root.hoverTarget.containsMouse && Config.options.bar.tooltips.enable && !GlobalStates.barStyleEditorOpen
        && (!Config.options.bar.tooltips.clickToShow || ((root.hoverTarget.pressedButtons ?? Qt.LeftButton) & Qt.LeftButton))
    property bool closing: false
    active: root.shouldShow || root.closing
    onShouldShowChanged: if (!root.shouldShow && root.item) root.closing = true

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real barThickness: barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    readonly property real bounceRoom: 24
    readonly property bool morph: Config.options.bar.tooltips.style === "morph"
    readonly property real filletRadius: 10
    readonly property var group: root.findGroup(root.hoverTarget)

    function findGroup(item) {
        let p = item
        while (p) {
            if (p.morphEdge !== undefined) return p
            p = p.parent
        }
        return null
    }

    component Fillet: Shape {
        id: fillet
        property real r: 0
        property bool flipH: false
        property bool flipV: false
        property color fillColor: "transparent"
        width: r
        height: r
        visible: r > 0
        layer.enabled: true
        layer.samples: 4
        transform: Scale {
            origin.x: fillet.width / 2
            origin.y: fillet.height / 2
            xScale: fillet.flipH ? -1 : 1
            yScale: fillet.flipV ? -1 : 1
        }
        ShapePath {
            fillColor: fillet.fillColor
            strokeWidth: -1
            startX: fillet.r
            startY: fillet.r
            PathLine { x: 0; y: fillet.r }
            PathArc {
                x: fillet.r
                y: 0
                radiusX: fillet.r
                radiusY: fillet.r
                direction: PathArc.Counterclockwise
            }
            PathLine { x: fillet.r; y: fillet.r }
        }
    }

    component: PanelWindow {
        id: popupWindow

        // Bring contentItem reference into this scope
        property Item innerContent: root.contentItem

        color: "transparent"
        anchors.left: root.barEdge !== "right"
        anchors.right: root.barEdge === "right"
        anchors.top: root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin + (root.barVertical ? root.bounceRoom : 0)
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin + (root.barVertical ? 0 : root.bounceRoom)

        readonly property real centerOffsetX: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
            ).x ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxLeft = popupWindow.screen.width - popupBackground.implicitWidth - margin - 10
            return Math.max(margin, Math.min(base, maxLeft))
        }
        readonly property Item groupBox: root.group ? root.group.box : root.hoverTarget
        readonly property var barWin: root.hoverTarget?.QsWindow?.window ?? null
        readonly property var barLayer: {
            const levels = HyprlandData.layers[popupWindow.screen.name]?.levels
            if (!levels) return null
            const namespace = root.barVertical ? "quickshell:verticalBar" : "quickshell:bar"
            for (const level in levels) {
                const found = levels[level].find(l => l.namespace === namespace)
                if (found) return found
            }
            return null
        }
        readonly property real originX: barLayer ? barLayer.x : (!barWin ? 0 : (barWin.anchors.left ? barWin.margins.left : popupWindow.screen.width - barWin.width - barWin.margins.right))
        readonly property real originY: barLayer ? barLayer.y : (!barWin ? 0 : (barWin.anchors.top ? barWin.margins.top : popupWindow.screen.height - barWin.height - barWin.margins.bottom))
        readonly property point boxPos: groupBox ? groupBox.mapToItem(null, 0, 0) : Qt.point(0, 0)
        readonly property real boxX: originX + boxPos.x
        readonly property real boxY: originY + boxPos.y
        readonly property real boxW: groupBox ? groupBox.width : 0
        readonly property real boxH: groupBox ? groupBox.height : 0
        readonly property real cardWidth: popupBackground.implicitWidth
        readonly property real cardHeight: popupBackground.implicitHeight
        readonly property real snapRange: 10 + root.filletRadius * 2
        function clampAlong(center, size, boxStartPos, boxLength, screenLength) {
            const low = boxStartPos < snapRange ? boxStartPos : 10
            const high = screenLength - boxStartPos - boxLength < snapRange ? boxStartPos + boxLength - size : screenLength - size - 10
            return Math.max(low, Math.min(center - size / 2, high))
        }
        readonly property real cardLeft: root.barVertical
            ? (root.barEdge === "left" ? boxX + boxW : boxX - cardWidth)
            : clampAlong(boxX + boxW / 2, cardWidth, boxX, boxW, popupWindow.screen.width)
        readonly property real cardTop: !root.barVertical
            ? (root.barEdge === "top" ? boxY + boxH : boxY - cardHeight)
            : clampAlong(boxY + boxH / 2, cardHeight, boxY, boxH, popupWindow.screen.height)
        readonly property real boxStart: root.barVertical ? boxY - cardTop : boxX - cardLeft
        readonly property real boxEnd: boxStart + (root.barVertical ? boxH : boxW)
        readonly property real cardExtent: root.barVertical ? cardHeight : cardWidth
        readonly property bool startCovered: boxStart >= 0
        readonly property bool endCovered: boxEnd <= cardExtent

        function filletSpec(isStart) {
            const d = isStart ? boxStart : boxEnd - cardExtent
            const wide = isStart ? d > 0 : d < 0
            const r = Math.min(root.filletRadius, Math.abs(d))
            const edge = root.barEdge
            const sideDir = isStart ? -1 : 1
            const alongCorner = isStart ? (wide ? d : 0) : (wide ? boxEnd : cardExtent)
            let cx, cy, sx, sy
            if (!root.barVertical) {
                cx = alongCorner
                cy = edge === "top" ? 0 : cardHeight
                sx = sideDir
                sy = edge === "top" ? (wide ? -1 : 1) : (wide ? 1 : -1)
            } else {
                cy = alongCorner
                cx = edge === "left" ? 0 : cardWidth
                sy = sideDir
                sx = edge === "left" ? (wide ? -1 : 1) : (wide ? 1 : -1)
            }
            return {
                r: r,
                x: cx + (sx < 0 ? -r : 0),
                y: cy + (sy < 0 ? -r : 0),
                flipH: sx > 0,
                flipV: sy > 0
            }
        }
        function flat(corner) {
            if (!root.morph) return false
            const e = root.barEdge
            if (e === "top") return (corner === "tl" && boxStart <= 0) || (corner === "tr" && boxEnd >= cardExtent)
            if (e === "bottom") return (corner === "bl" && boxStart <= 0) || (corner === "br" && boxEnd >= cardExtent)
            if (e === "left") return (corner === "tl" && boxStart <= 0) || (corner === "bl" && boxEnd >= cardExtent)
            return (corner === "tr" && boxStart <= 0) || (corner === "br" && boxEnd >= cardExtent)
        }
        readonly property var startFillet: filletSpec(true)
        readonly property var endFillet: filletSpec(false)

        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                0, (root.hoverTarget.height - popupBackground.implicitHeight) / 2
            ).y ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxTop = popupWindow.screen.height - popupBackground.implicitHeight - margin - 15
            return Math.max(margin, Math.min(base, maxTop))
        }

        Component.onCompleted: HyprlandData.updateLayers()

        Binding {
            target: root.group
            property: "morphEdge"
            value: ({ top: "bottom", bottom: "top", left: "right", right: "left" })[root.barEdge]
            when: root.morph && root.group !== null && root.shouldShow
        }
        Binding {
            target: root.group
            property: "morphStartFlat"
            value: popupWindow.startCovered
            when: root.morph && root.group !== null && root.shouldShow
        }
        Binding {
            target: root.group
            property: "morphEndFlat"
            value: popupWindow.endCovered
            when: root.morph && root.group !== null && root.shouldShow
        }

        mask: Region {
            item: inputArea
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (root.morph && root.barEdge !== "right") return popupWindow.cardLeft - Appearance.sizes.elevationMargin
                if (root.barEdge === "right") return 0
                if (root.barEdge === "left") return root.barThickness
                return centerOffsetX 
            }
            top: {
                if (root.morph && root.barEdge !== "bottom") return popupWindow.cardTop - Appearance.sizes.elevationMargin
                if (root.barEdge === "bottom") return 0
                if (root.barEdge === "top") return root.barThickness
                return centerOffsetY
            }
            right: {
                if (root.barEdge !== "right") return 0
                if (root.morph) return popupWindow.screen.width - popupWindow.cardLeft - popupWindow.cardWidth - Appearance.sizes.elevationMargin
                return root.barThickness
            }
            bottom: {
                if (root.barEdge !== "bottom") return 0
                if (root.morph) return popupWindow.screen.height - popupWindow.cardTop - popupWindow.cardHeight - Appearance.sizes.elevationMargin
                return root.barThickness
            }
        }
        WlrLayershell.namespace: root.morph ? "quickshell:popupMorph" : "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        Connections {
            target: root
            function onShouldShowChanged() {
                if (root.shouldShow) {
                    closeAnim.stop();
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    closeAnim.restart();
                }
            }
        }

        property bool geometryTimedOut: false
        property bool groupSynced: false
        readonly property bool geometryReady: !root.morph || ((barLayer !== null || geometryTimedOut) && groupSynced)
        Timer {
            running: root.morph
            interval: 250
            onTriggered: popupWindow.geometryTimedOut = true
        }
        Timer {
            running: root.morph
            interval: 50
            onTriggered: popupWindow.groupSynced = true
        }

        Item {
            id: inputArea
            anchors.fill: body
        }

        Item {
            id: body
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left) + (root.barEdge === "right" ? root.bounceRoom : 0)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right) + (root.barEdge === "left" ? root.bounceRoom : 0)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top) + (root.barEdge === "bottom" ? root.bounceRoom : 0)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom) + (root.barEdge === "top" ? root.bounceRoom : 0)
            }
            visible: popupWindow.geometryReady
            opacity: root.morph ? 1 : 0
            transform: Scale {
                id: bodyScale
                origin.x: root.barEdge === "left" ? 0 : root.barEdge === "right" ? body.width : body.width / 2
                origin.y: root.barEdge === "top" ? 0 : root.barEdge === "bottom" ? body.height : body.height / 2
                xScale: root.morph ? (root.barVertical ? 0.01 : 1) : (root.barVertical ? 0.4 : 0.8)
                yScale: root.morph ? (root.barVertical ? 1 : 0.01) : (root.barVertical ? 0.8 : 0.4)
            }

            StyledRectangularShadow {
                target: popupBackground
                visible: !root.morph
            }

            Rectangle {
                id: popupBackground
                readonly property real margin: 8

                anchors.fill: parent

                // Use local reference instead of crossing LazyLoader scope boundary
                implicitWidth: (popupWindow.innerContent?.implicitWidth ?? 0) + margin * 2
                implicitHeight: (popupWindow.innerContent?.implicitHeight ?? 0) + margin * 2

                color: Appearance.colors.colUiPopupBackground
                radius: Appearance.rounding.large + 5
                topLeftRadius: popupWindow.flat("tl") ? 0 : radius
                topRightRadius: popupWindow.flat("tr") ? 0 : radius
                bottomLeftRadius: popupWindow.flat("bl") ? 0 : radius
                bottomRightRadius: popupWindow.flat("br") ? 0 : radius
                border.width: root.morph ? 0 : 1
                border.color: Appearance.colors.colLayer0Border

                Fillet {
                    visible: root.morph
                    r: popupWindow.startFillet.r
                    x: popupWindow.startFillet.x
                    y: popupWindow.startFillet.y
                    flipH: popupWindow.startFillet.flipH
                    flipV: popupWindow.startFillet.flipV
                    fillColor: popupBackground.color
                }
                Fillet {
                    visible: root.morph
                    r: popupWindow.endFillet.r
                    x: popupWindow.endFillet.x
                    y: popupWindow.endFillet.y
                    flipH: popupWindow.endFillet.flipH
                    flipV: popupWindow.endFillet.flipV
                    fillColor: popupBackground.color
                }

                Item {
                    id: contentHolder
                    anchors.fill: parent
                    opacity: 0
                    transform: Translate {
                        id: contentShift
                        x: root.barEdge === "left" ? -16 : root.barEdge === "right" ? 16 : 0
                        y: root.barEdge === "top" ? -16 : root.barEdge === "bottom" ? 16 : 0
                    }
                }

                // Reparent content here once the window is ready
                Component.onCompleted: {
                    if (popupWindow.innerContent) {
                        popupWindow.innerContent.parent = contentHolder
                        popupWindow.innerContent.anchors.centerIn = contentHolder
                    }
                }
            }
        }

        ParallelAnimation {
            id: openAnim
            running: true
            NumberAnimation {
                target: bodyScale
                property: root.barVertical ? "xScale" : "yScale"
                to: 1
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: bodyScale
                property: root.barVertical ? "yScale" : "xScale"
                to: 1
                duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
            NumberAnimation {
                target: body
                property: "opacity"
                to: 1
                duration: Appearance.animationCurves.expressiveEffectsDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 90
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: contentHolder
                        property: "opacity"
                        to: 1
                        duration: Appearance.animationCurves.expressiveEffectsDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                    }
                    NumberAnimation {
                        target: contentShift
                        properties: "x,y"
                        to: 0
                        duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                    }
                }
            }
        }

        ParallelAnimation {
            id: closeAnim
            onFinished: root.closing = false
            NumberAnimation {
                target: bodyScale
                property: root.barVertical ? "xScale" : "yScale"
                to: root.morph ? 0.01 : 0.4
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: bodyScale
                property: root.barVertical ? "yScale" : "xScale"
                to: root.morph ? 1 : 0.85
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: body
                property: "opacity"
                to: 0
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: contentHolder
                property: "opacity"
                to: 0
                duration: 120
            }
        }
    }
}