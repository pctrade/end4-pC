pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    required property Item group
    signal dismissed

    readonly property var colorOptions: ["transparent", "layer0", "layer1", "layer2", "surfaceContainer", "primary", "primaryContainer", "secondary", "secondaryContainer", "tertiary", "tertiaryContainer", "errorContainer", "onError", "onLayer0"]
    readonly property real padding: Appearance.sizes.elevationMargin
    readonly property real bounceRoom: 24
    readonly property bool barVertical: root.barConfig.vertical
    readonly property bool barAtEnd: root.barConfig.bottom
    readonly property real awaySign: root.barAtEnd ? -1 : 1
    property bool closing: false

    function close() {
        if (root.closing) return;
        root.closing = true;
        openAnim.stop();
        closeAnim.start();
    }
    readonly property string widgetTitle: {
        const spaced = root.group.widgetName.replace(/([A-Z])/g, " $1");
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    Component.onCompleted: GlobalStates.barStyleEditorOpen = true
    Component.onDestruction: GlobalStates.barStyleEditorOpen = false

    color: "transparent"
    visible: true
    mask: Region {
        item: inputArea
    }
    implicitWidth: popupBackground.implicitWidth + root.padding * 2 + (root.barVertical ? root.bounceRoom : 0)
    implicitHeight: popupBackground.implicitHeight + root.padding * 2 + (root.barVertical ? 0 : root.bounceRoom)

    anchor {
        window: root.group.QsWindow.window
        item: root.group
        gravity: root.barConfig.vertical
            ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
            : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
        edges: root.barConfig.vertical
            ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
            : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
    }

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    Item {
        id: inputArea
        anchors.fill: body
    }

    Item {
        id: body
        anchors {
            fill: parent
            margins: root.padding
            topMargin: root.padding + (!root.barVertical && root.barAtEnd ? root.bounceRoom : 0)
            bottomMargin: root.padding + (!root.barVertical && !root.barAtEnd ? root.bounceRoom : 0)
            leftMargin: root.padding + (root.barVertical && root.barAtEnd ? root.bounceRoom : 0)
            rightMargin: root.padding + (root.barVertical && !root.barAtEnd ? root.bounceRoom : 0)
        }
        opacity: 0
        transform: Scale {
            id: bodyScale
            origin.x: root.barVertical ? (root.barAtEnd ? body.width : 0) : body.width / 2
            origin.y: root.barVertical ? body.height / 2 : (root.barAtEnd ? body.height : 0)
            xScale: root.barVertical ? 0.4 : 0.8
            yScale: root.barVertical ? 0.8 : 0.4
        }

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            WindowGlass {
                anchors.fill: parent
                glassEnabled: (parent?.color.a ?? 0) > 0
                cardRadius: parent?.radius ?? 0
                tint: parent?.color ?? 'transparent'
            }
            anchors.fill: parent
            implicitWidth: 340
            implicitHeight: content.implicitHeight + 32
            color: Config.options.appearance.uiBackground === "oled" ? "#000000" : Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.large

            ColumnLayout {
                id: content
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 12
                opacity: 0
                transform: Translate {
                    id: contentShift
                    x: root.barVertical ? -16 * root.awaySign : 0
                    y: root.barVertical ? 0 : -16 * root.awaySign
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "palette"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: root.widgetTitle
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            text: Translation.tr("Style for %1 mode").arg(root.group.borderlessMode)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                ContentSubsectionLabel {
                    text: Translation.tr("Background")
                }
                ColorSelectionArray {
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    showLabel: false
                    showTooltip: true
                    itemSpacing: 2
                    options: root.colorOptions
                    currentValue: root.group.style.color ?? ""
                    onSelected: newValue => root.group.setStyle("color", newValue)
                }

                ContentSubsectionLabel {
                    text: Translation.tr("Border")
                }
                ColorSelectionArray {
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    showLabel: false
                    showTooltip: true
                    itemSpacing: 2
                    options: root.colorOptions
                    currentValue: root.group.style.borderColor ?? ""
                    onSelected: newValue => root.group.setStyle("borderColor", newValue)
                }

                ConfigSlider {
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    buttonIcon: "rounded_corner"
                    text: Translation.tr("Radius")
                    textWidth: 90
                    usePercentTooltip: false
                    from: 0
                    to: 30
                    stepSize: 1
                    value: root.group.currentRadius
                    onMoved: root.group.previewStyle("radius", Math.round(value))
                    onPressedChanged: if (!pressed) root.group.commitPreview()
                }
                ConfigSlider {
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    buttonIcon: "padding"
                    text: Translation.tr("Padding")
                    textWidth: 90
                    usePercentTooltip: false
                    from: 0
                    to: 15
                    stepSize: 1
                    value: root.group.padding
                    onMoved: root.group.previewStyle("padding", Math.round(value))
                    onPressedChanged: if (!pressed) root.group.commitPreview()
                }
                ConfigSlider {
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    buttonIcon: "border_style"
                    text: Translation.tr("Border width")
                    textWidth: 90
                    usePercentTooltip: false
                    from: 0
                    to: 4
                    stepSize: 1
                    value: root.group.currentBorderWidth
                    onMoved: root.group.previewStyle("borderWidth", Math.round(value))
                    onPressedChanged: if (!pressed) root.group.commitPreview()
                }

                DialogButton {
                    Layout.alignment: Qt.AlignRight
                    buttonText: Translation.tr("Reset")
                    enabled: Object.keys(root.group.style).length > 0
                    onClicked: root.group.resetStyle()
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
                    target: content
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
        onFinished: root.dismissed()
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
            target: content
            property: "opacity"
            to: 0
            duration: 120
        }
    }
}
