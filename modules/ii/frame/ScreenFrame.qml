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

    function barPosition(config) {
        if (config.vertical)
            return config.bottom ? "right" : "left"
        return config.bottom ? "bottom" : "top"
    }

    function frameVisibleFor(config, side) {
        if (!config.showFrame) return false
        const centerOnly = config.layouts.leftLayout.length === 0 && config.layouts.rightLayout.length === 0
        if (config.cornerStyle === 0 && side === root.barPosition(config)) {
            return centerOnly || !config.showBackground
        }
        return true
    }

    function edgeNeedsInput(config, side) {
        if (!frameVisibleFor(config, side)) return false
        const dockWants = Config.options.dock.enable && Config.options.dock.hoverToReveal && Config.options.dock.position === side
        const barWants = config.autoHide.enable && root.barPosition(config) === side
        return dockWants || barWants
    }

    component FrameHoverArea: MouseArea {
        required property string side
        required property string screenName
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        required property var barConfig
        enabled: root.edgeNeedsInput(barConfig, side)
        onContainsMouseChanged: GlobalStates.setFrameHover(screenName, side, containsMouse)
    }

    component FrameCornerWindow: PanelWindow {
        id: cornerPanelWindow
        property var corner
        required property var barConfig
        readonly property real frameThickness: barConfig.frameThickness
        readonly property color frameColor: Appearance.getColorFromName(barConfig.frameColor)

        visible: barConfig.showFrame
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
            left: cornerWidget.isLeft ? cornerPanelWindow.frameThickness : 0
            right: cornerWidget.isRight ? cornerPanelWindow.frameThickness : 0
            top: cornerWidget.isTop ? cornerPanelWindow.frameThickness : 0
            bottom: cornerWidget.isBottom ? cornerPanelWindow.frameThickness : 0
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            implicitSize: Math.max(0, Appearance.rounding.screenRounding - cornerPanelWindow.frameThickness)
            color: cornerPanelWindow.frameColor
        }
    }

    Variants {
        model: Quickshell.screens

        Item {
            id: frameGroup
            required property var modelData
            readonly property var barConfig: Config.barForScreen(modelData.name)
            readonly property real frameThickness: barConfig.frameThickness
            readonly property color frameColor: Appearance.getColorFromName(barConfig.frameColor)

            PanelWindow { // top
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor(frameGroup.barConfig, "top") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: frameGroup.frameThickness
                anchors { top: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput(frameGroup.barConfig, "top") ? topRect : null }

                Rectangle { id: topRect; anchors.fill: parent; color: frameGroup.frameColor; visible: root.frameVisibleFor(frameGroup.barConfig, "top") }

                FrameHoverArea { side: "top"; screenName: frameGroup.modelData.name; barConfig: frameGroup.barConfig }
            }

            PanelWindow { // bottom
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor(frameGroup.barConfig, "bottom") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: frameGroup.frameThickness
                anchors { bottom: true; left: true; right: true }
                mask: Region { item: root.edgeNeedsInput(frameGroup.barConfig, "bottom") ? bottomRect : null }

                Rectangle { id: bottomRect; anchors.fill: parent; color: frameGroup.frameColor; visible: root.frameVisibleFor(frameGroup.barConfig, "bottom") }

                FrameHoverArea { side: "bottom"; screenName: frameGroup.modelData.name; barConfig: frameGroup.barConfig }
            }

            PanelWindow { // left
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor(frameGroup.barConfig, "left") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: frameGroup.frameThickness
                anchors { left: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput(frameGroup.barConfig, "left") ? leftRect : null }

                Rectangle { id: leftRect; anchors.fill: parent; color: frameGroup.frameColor; visible: root.frameVisibleFor(frameGroup.barConfig, "left") }

                FrameHoverArea { side: "left"; screenName: frameGroup.modelData.name; barConfig: frameGroup.barConfig }
            }

            PanelWindow { // right
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: root.frameVisibleFor(frameGroup.barConfig, "right") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: frameGroup.frameThickness
                anchors { right: true; top: true; bottom: true }
                mask: Region { item: root.edgeNeedsInput(frameGroup.barConfig, "right") ? rightRect : null }

                Rectangle { id: rightRect; anchors.fill: parent; color: frameGroup.frameColor; visible: root.frameVisibleFor(frameGroup.barConfig, "right") }

                FrameHoverArea { side: "right"; screenName: frameGroup.modelData.name; barConfig: frameGroup.barConfig }
            }

            FrameCornerWindow { screen: frameGroup.modelData; barConfig: frameGroup.barConfig; corner: RoundCorner.CornerEnum.TopLeft }
            FrameCornerWindow { screen: frameGroup.modelData; barConfig: frameGroup.barConfig; corner: RoundCorner.CornerEnum.TopRight }
            FrameCornerWindow { screen: frameGroup.modelData; barConfig: frameGroup.barConfig; corner: RoundCorner.CornerEnum.BottomLeft }
            FrameCornerWindow { screen: frameGroup.modelData; barConfig: frameGroup.barConfig; corner: RoundCorner.CornerEnum.BottomRight }
        }
    }
}
