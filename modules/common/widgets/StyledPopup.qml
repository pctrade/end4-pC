import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property bool popupEnabled: true
    property bool popupShadowEnabled: true
    property bool popupHovered: false
    property real popupBackgroundMargin: 0
    property real popupContentMargin: 8
    property color popupColor: Appearance.colors.colLayer1Base
    property real popupRadius: Appearance.rounding.normal + 4
    property real popupBorderWidth: 1
    readonly property bool targetHovered: !!(root.hoverTarget && root.hoverTarget.containsMouse)
    property bool shouldShow: root.popupEnabled && root.targetHovered && Config.options.bar.tooltips.enable && !GlobalStates.barStyleEditorOpen
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
        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                0, (root.hoverTarget.height - popupBackground.implicitHeight) / 2
            ).y ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxTop = popupWindow.screen.height - popupBackground.implicitHeight - margin - 15
            return Math.max(margin, Math.min(base, maxTop))
        }

        mask: Region {
            item: inputArea
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (root.barEdge === "right") return 0
                if (root.barEdge === "left") return root.barThickness
                return centerOffsetX 
            }
            top: {
                if (root.barEdge === "bottom") return 0
                if (root.barEdge === "top") return root.barThickness
                return centerOffsetY
            }
            right: root.barEdge === "right" ? root.barThickness : 0
            bottom: root.barEdge === "bottom" ? root.barThickness : 0
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        Component.onCompleted: GlobalFocusGrab.addPersistent(popupWindow)
        Component.onDestruction: {
            GlobalFocusGrab.removePersistent(popupWindow)
            root.popupHovered = false
        }

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

        Item {
            id: inputArea
            anchors.fill: body
        }

        Item {
            id: body
            HoverHandler { onHoveredChanged: root.popupHovered = hovered }
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left) + (root.barEdge === "right" ? root.bounceRoom : 0)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right) + (root.barEdge === "left" ? root.bounceRoom : 0)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top) + (root.barEdge === "bottom" ? root.bounceRoom : 0)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom) + (root.barEdge === "top" ? root.bounceRoom : 0)
            }
            opacity: 0
            transform: Scale {
                id: bodyScale
                origin.x: root.barEdge === "left" ? 0 : root.barEdge === "right" ? body.width : body.width / 2
                origin.y: root.barEdge === "top" ? 0 : root.barEdge === "bottom" ? body.height : body.height / 2
                xScale: root.barVertical ? 0.4 : 0.8
                yScale: root.barVertical ? 0.8 : 0.4
            }

            StyledRectangularShadow {
                target: popupBackground
                visible: root.popupShadowEnabled
            }

            Rectangle {
                id: popupBackground
                readonly property real margin: root.popupContentMargin

                anchors.fill: parent

                // Use local reference instead of crossing LazyLoader scope boundary
                implicitWidth: (popupWindow.innerContent?.implicitWidth ?? 0) + margin * 2
                implicitHeight: (popupWindow.innerContent?.implicitHeight ?? 0) + margin * 2

                color: root.popupColor
                radius: root.popupRadius
                border.width: root.popupBorderWidth
                border.color: Appearance.colors.colLayer0Border

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
                to: 0.4
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                target: bodyScale
                property: root.barVertical ? "yScale" : "xScale"
                to: 0.85
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
