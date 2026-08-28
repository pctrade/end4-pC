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
    readonly property real doubleHeight: root.cardHeight * 2 + root.cardSpacing

    readonly property real snapWidth1: root.singleWidth
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2

    property string sizeMode: root.configEntry.sizeMode ?? "1x3"
    property bool expanded: root.configEntry.expanded ?? false

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            default:    return root.snapWidth3
        }
    }
    property real widgetHeight: (root.sizeMode === "1x3" && root.expanded) ? root.doubleHeight : root.cardHeight
    readonly property bool isCompact: root.sizeMode !== "1x3"
    property real lastDy: 0

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

    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight
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
                if (root.expanded) return twoByThreeContent
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
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

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
                        spacing: -2

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
                        padding: 10
                        implicitWidth: 50
                        implicitHeight: 50
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 5
                    spacing: 16

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

                    ColumnLayout{
                        Layout.topMargin: -5
                        Layout.rightMargin: 5
                        spacing: 1
                        RowLayout {
                            spacing: 4
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
                            spacing: 4
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

        // 2x3
        Component {
            id: twoByThreeContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

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
                        spacing: -2

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
                        padding: 10
                        implicitWidth: 50
                        implicitHeight: 50
                    }
                }

                Item {
                    width: parent.width
                    height: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 48
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.2; color: Appearance.colors.colOnPrimaryContainer }
                            GradientStop { position: 0.8; color: Appearance.colors.colOnPrimaryContainer }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        opacity: 0.15
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "humidity_mid"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.humidity ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Humidity"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.9)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "air"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.wind ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Wind"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colSecondary, 0.7)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "visibility"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.visib ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Visibility"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.9)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "thermostat"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.tempFeelsLike ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Feels like"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colTertiary, 0.7)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "rainy"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.precip ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Precipitation"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 20
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.9)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                iconSize: 20
                                text: "speed"
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.data?.press ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Pressure"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.6
                            }
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
            onResizedXY: (dx, dy, startWidth) => { root.lastDy = dy }
            onResizeFinished: {
                root.configEntry.sizeMode = root.sizeMode
                if (root.sizeMode === "1x3") {
                    var threshold = (root.doubleHeight - root.cardHeight) / 2
                    if (root.expanded && root.lastDy < -threshold) {
                        root.expanded = false
                    } else if (!root.expanded && root.lastDy > threshold) {
                        root.expanded = true
                    }
                    root.configEntry.expanded = root.expanded
                }
                root.lastDy = 0
            }
        }
    }
}
