import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Scope {
    id: root
    property real frameThickness: Config.options.bar.frameThickness
    property color frameColor: Appearance.getColorFromName(Config.options.bar.frameColor)
    readonly property bool centerOnly: Config.options.bar.layouts.leftLayout.length === 0 && Config.options.bar.layouts.rightLayout.length === 0
    readonly property bool hideBarSideFrame: Config.options.bar.cornerStyle === 0
    readonly property string barPosition: {
        if (Config.options.bar.vertical)
            return Config.options.bar.bottom ? "right" : "left"
        return Config.options.bar.bottom ? "bottom" : "top"
    }

    function frameVisibleFor(side) {
        if (!Config.options.bar.showFrame) return false
        if (Config.options.bar.cornerStyle === 0 && side === root.barPosition) {
            return root.centerOnly || !Config.options.bar.showBackground
        }
        return true
    }

    function edgeNeedsInput(side) {
        if (!frameVisibleFor(side)) return false
        const dockWants = Config.options.dock.enable && Config.options.dock.hoverToReveal && Config.options.dock.position === side
        const barWants = Config.options.bar.autoHide.enable && root.barPosition === side
        return dockWants || barWants
    }

    component FrameHoverArea: MouseArea {
        required property string side
        required property string screenName
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root.edgeNeedsInput(side)
        onContainsMouseChanged: GlobalStates.setFrameHover(screenName, side, containsMouse)
    }

    component FrameCornerWindow: PanelWindow {
        id: cornerPanelWindow
        property var corner

        visible: Config.options.bar.showFrame 
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "quickshell:screenframe-corner"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: cornerWidget.isTopLeft || cornerWidget.isTopRight
            left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
            bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
            right: cornerWidget.isTopRight || cornerWidget.isBottomRight
        }
        margins {
            left: cornerWidget.isLeft ? root.frameThickness : 0
            right: cornerWidget.isRight ? root.frameThickness : 0
            top: cornerWidget.isTop ? root.frameThickness : 0
            bottom: cornerWidget.isBottom ? root.frameThickness : 0
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            implicitSize: Math.max(0, Appearance.rounding.screenRounding - root.frameThickness)
            color: root.frameColor
        }
    }

    Variants {
        model: Quickshell.screens

        Item {
            id: frameGroup
            required property var modelData

            PanelWindow { // top
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("top") ? root.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: root.frameThickness
                anchors { top: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput("top") ? topRect : null }

                Rectangle { id: topRect; anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("top") }

                FrameHoverArea { side: "top"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // bottom
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("bottom") ? root.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: root.frameThickness
                anchors { bottom: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput("bottom") ? bottomRect : null }

                Rectangle { id: bottomRect; anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("bottom") }

                FrameHoverArea { side: "bottom"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // left
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("left") ? root.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: root.frameThickness
                anchors { left: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput("left") ? leftRect : null }

                Rectangle { id: leftRect; anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("left") }

                FrameHoverArea { side: "left"; screenName: frameGroup.modelData.name }
            }

            PanelWindow { // right
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor("right") ? root.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: root.frameThickness
                anchors { right: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput("right") ? rightRect : null }

                Rectangle { id: rightRect; anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("right") }

                FrameHoverArea { side: "right"; screenName: frameGroup.modelData.name }
            }

            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopRight }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomRight }
        }
    }
}