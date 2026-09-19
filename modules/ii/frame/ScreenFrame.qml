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
            implicitSize: 22 // fix me >> variable
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("top") }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("bottom") }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("left") }
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
                mask: Region {}

                Rectangle { anchors.fill: parent; color: root.frameColor; visible: root.frameVisibleFor("right") }
            }

            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.TopRight }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomLeft }
            FrameCornerWindow { screen: frameGroup.modelData; corner: RoundCorner.CornerEnum.BottomRight }
        }
    }
}