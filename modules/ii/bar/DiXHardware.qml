import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A hardware moment, expanded: the same headline, a small picture of the screens for monitors and docks,
// and the actions (the current screen layout is highlighted)
ColumnLayout {
    id: xhw
    required property Item di
    spacing: 12
    implicitWidth: 360
    readonly property real wantedWidth: 360

    readonly property var payload: IslandHardware.payload
    readonly property color accent: IslandEvents.toneColor(xhw.payload.tone)
    readonly property bool screens: ["monitor", "dock"].includes(xhw.payload.kind)
    readonly property string layout: xhw.payload.layout ?? "extend"
    readonly property var hero: ({ key: "hardware-icon", item: headerIcon })

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        MaterialShapeWrappedMaterialSymbol {
            id: headerIcon
            wrappedShape: MaterialShape.Shape.Cookie9Sided
            color: ColorUtils.transparentize(xhw.accent, 0.78)
            colSymbol: xhw.accent
            text: xhw.payload.icon ?? "memory"
            iconSize: 18
            fill: 1
            padding: 7
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2

            StyledText {
                Layout.fillWidth: true
                text: xhw.payload.title ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: xhw.payload.subtitle ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                wrapMode: Text.Wrap
            }
        }
        StyledText {
            visible: (xhw.payload.value ?? "") !== ""
            text: xhw.payload.value ?? ""
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: xhw.accent
        }
    }

    Item {
        id: diagram
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        visible: xhw.screens

        Rectangle {
            id: laptopScreen
            width: 92
            height: 58
            radius: 6
            x: xhw.layout === "mirror" ? diagram.width / 2 - width / 2 - 14 : diagram.width / 2 - width - 10
            y: xhw.layout === "mirror" ? 26 : 22
            color: ColorUtils.transparentize(Appearance.colors.colPrimary, xhw.layout === "only" ? 1 : 0.82)
            border.width: 1.5
            border.color: xhw.layout === "only" ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.75) : Appearance.colors.colPrimary
            opacity: xhw.layout === "only" ? 0.55 : 1

            Behavior on x {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
            Behavior on y {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.short }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: xhw.layout === "only" ? "desktop_access_disabled" : "laptop"
                iconSize: 18
                color: Appearance.colors.colOnLayer0
                opacity: 0.8
            }
        }

        Rectangle {
            id: externalScreen
            width: 118
            height: 72
            radius: 6
            x: xhw.layout === "mirror" ? diagram.width / 2 - width / 2 + 14
                : xhw.layout === "only" ? diagram.width / 2 - width / 2 + 24 : diagram.width / 2 + 10
            y: xhw.layout === "mirror" ? 4 : 10
            z: 1
            color: Qt.tint(Appearance.colors.colLayer1, ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78))
            border.width: 1.5
            border.color: Appearance.colors.colPrimary

            Behavior on x {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
            Behavior on y {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: xhw.layout === "mirror" ? "screen_share" : "desktop_windows"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: text !== ""
                    text: xhw.payload.resolution ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.75
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        text: xhw.payload.status ?? ""
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: xhw.accent
        wrapMode: Text.Wrap
    }

    Flow {
        Layout.fillWidth: true
        visible: (xhw.payload.actions ?? []).length > 0
        spacing: 6

        Repeater {
            model: xhw.payload.actions ?? []
            delegate: Rectangle {
                id: actionButton
                required property var modelData
                required property int index
                readonly property bool current: xhw.screens && actionButton.modelData.id === xhw.layout
                readonly property bool primary: actionButton.current || (!xhw.screens && actionButton.index === 0)
                implicitWidth: actionRow.implicitWidth + 22
                implicitHeight: 32
                radius: 16
                color: actionButton.primary ? (actionMouse.containsMouse ? Qt.darker(xhw.accent, 1.1) : xhw.accent)
                    : (actionMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)
                scale: actionMouse.pressed ? 0.94 : 1

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.short }
                }
                Behavior on scale {
                    NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutBack }
                }

                RowLayout {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: actionButton.modelData.icon ?? ""
                        iconSize: 16
                        fill: 1
                        color: actionButton.primary ? (ColorUtils.isDark(xhw.accent) ? "white" : "black") : xhw.accent
                    }
                    StyledText {
                        text: actionButton.modelData.label ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: actionButton.primary ? Font.DemiBold : Font.Normal
                        color: actionButton.primary ? (ColorUtils.isDark(xhw.accent) ? "white" : "black") : Appearance.colors.colOnLayer1
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandHardware.runAction(actionButton.modelData.id)
                }
            }
        }
    }
}
