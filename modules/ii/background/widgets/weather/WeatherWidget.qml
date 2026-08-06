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
                    padding: 6
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
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                    radius: Appearance.rounding.verylarge ?? 30
                    color: Appearance.colors.colPrimary

                    Rectangle {
                        width: parent.radius
                        height: parent.height
                        anchors.right: parent.right
                        color: parent.color
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            iconSize: 46
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimary
                            opacity: 0.7
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 14
                    Layout.leftMargin: 12
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.data?.city ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.data?.description ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "humidity_mid"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.55
                        }
                        StyledText {
                            text: Weather.data?.humidity ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 10
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            color: Appearance.colors.colOutlineVariant
                        }
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "air"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.55
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
            Item {
                anchors.fill: parent

                Item {
                    anchors.fill: parent
                    clip: true

                    Rectangle {
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                        width: 160
                        height: 160
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -60
                        anchors.topMargin: -70
                    }
                    Rectangle {
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                        width: 110
                        height: 110
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -35
                        anchors.topMargin: -45
                    }
                    Rectangle {
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        width: 60
                        height: 60
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -10
                        anchors.topMargin: -20

                        MaterialSymbol {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 8
                            anchors.horizontalCenterOffset: -2
                            iconSize: Appearance.font.pixelSize.huge
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.normal
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                        }
                        StyledText {
                            text: Weather.data?.description ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        text: Weather.data?.temp ?? "--°"
                        font {
                            pixelSize: 42
                            weight: Font.Light
                        }
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -12
                        spacing: 14

                        RowLayout {
                            spacing: 2
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
                            spacing: 2
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
                            spacing: 2
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
                            spacing: 2
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

                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.85
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            onResized: (newWidth) => { root.sizeMode = root.modeForWidth(newWidth) }
            onResizeFinished: { root.configEntry.sizeMode = root.sizeMode }
        }
    }
}
