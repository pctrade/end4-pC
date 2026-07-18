import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "weather"
    hoverEnabled: true

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real cardHeight: 120

    readonly property real snapWidth1: root.singleWidth
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2

    property string sizeMode: root.configEntry.sizeMode ?? "1x3"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            default:    return root.snapWidth3
        }
    }
    readonly property bool isCompact: root.sizeMode !== "1x3"

    function modeForWidth(value) {
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        if (value < mid1) return "1x1"
        if (value < mid2) return "1x2"
        return "1x3"
    }

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                return oneByThreeContent
            }
        }

        // 1x1 
        Component {
            id: oneByOneContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: -4

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignRight
                    shape: MaterialShape.Shape.Cookie12Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: 18
                    fill: 1
                    padding: Appearance.spacing.small
                    implicitWidth: 34
                    implicitHeight: 34
                }

                Item { Layout.fillHeight: true }

                StyledText {
                    text: Weather.data?.temp ?? "--°"
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.data?.city ?? "--"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    ColumnLayout {
                        spacing: -4
                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: Appearance.font.pixelSize.hugeass
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: Weather.data?.description ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.topMargin: -19
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 18
                        fill: 1
                        padding: Appearance.spacing.small
                        implicitWidth: 42
                        implicitHeight: 42
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.spacing.unsharpen
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "humidity_mid"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.humidity ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "rainy"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.cr ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "air"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.wind ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }
                }
            }
        }

        // 1x3
        Component {
            id: oneByThreeContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        Layout.alignment: Qt.AlignTop
                        text: Weather.data?.temp ?? "--°"
                        font {
                            pixelSize: 40
                            weight: Font.Bold
                        }
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Appearance.spacing.unsharpen

                        StyledText {
                            text: Weather.data?.description ?? ""
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.topMargin: -5
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 24
                        fill: 1
                        padding: Appearance.spacing.normal
                        implicitWidth: 50
                        implicitHeight: 50
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.spacing.small
                    spacing: Appearance.spacing.large

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "humidity_mid"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.humidity ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "rainy"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.cr ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "air"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.wind ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.unsharpen
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "visibility"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.visib ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout{
                        Layout.topMargin: -5
                        Layout.rightMargin: Appearance.spacing.small
                        spacing: 1
                        RowLayout {
                            spacing: Appearance.spacing.verysmall
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.smaller
                                text: "wb_twilight"
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                            }
                            StyledText {
                                text: Weather.data?.sunrise ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                            }
                        }

                        RowLayout {
                            spacing: Appearance.spacing.verysmall
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.smaller
                                text: "nights_stay"
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                            }
                            StyledText {
                                text: Weather.data?.sunset ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: resizeHandle
            width: 16
            height: 16
            radius: Appearance.rounding.unsharpenslight
            color: Appearance.colors.colOnPrimaryContainer
            anchors {
                right: card.right
                bottom: card.bottom
                margins: Appearance.spacing.verysmall
            }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.5 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked

            Behavior on opacity {
                NumberAnimation { duration: Appearance.animation.elementMoveFaster.duration }
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property real startWidth: 0
                property real startX: 0

                onPressed: (mouse) => {
                    startWidth = root.widgetWidth
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalX = mapToItem(null, mouse.x, mouse.y).x
                    var dx = globalX - startX
                    root.sizeMode = root.modeForWidth(startWidth + dx)
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
