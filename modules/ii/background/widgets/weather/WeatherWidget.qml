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

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x2": return root.snapWidth2
            case "2x3": return root.snapWidth3
            default:    return root.snapWidth3 // "1x3"
        }
    }
    property real widgetHeight: (root.sizeMode === "2x2" || root.sizeMode === "2x3") ? root.doubleHeight : root.cardHeight
    readonly property bool isCompact: root.sizeMode !== "1x3" && root.sizeMode !== "2x3"

    function modeForWidth(value) {
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        if (value < mid1) return "1x1"
        if (value < mid2) return "1x2"
        return "1x3"
    }

    readonly property real heightEnterFraction: 0.2
    readonly property real heightEnterDelta: (root.doubleHeight - root.cardHeight) * root.heightEnterFraction

    function modeForDrag(dx, dy, startWidth) {
        if (dy > root.heightEnterDelta) {
            if (root.sizeMode === "1x2" || root.sizeMode === "2x2") return "2x2"
            if (root.sizeMode === "1x3" || root.sizeMode === "2x3") return "2x3"
        }
        return root.modeForWidth(startWidth + dx)
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

        FastBlurred {
            anchors.fill: parent
            blurSource: root.wallpaperItem
            cardRadius: card.radius
            tint: Appearance.colors.colLayer1
            tintOpacity: 0.55
            trackX: root.x  
            trackY: root.y
            visible: Config.options.background.widgets.blurWidgets 
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                if (root.sizeMode === "2x2") return twoByTwoContent
                if (root.sizeMode === "2x3") return twoByThreeContent
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
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.fillHeight: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    Layout.leftMargin: 10
                    radius: (Appearance.rounding?.verylarge ?? 30) - 6
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        MaterialShapeWrappedMaterialSymbol {
                            Layout.topMargin: 6
                            Layout.alignment: Qt.AlignHCenter
                            shape: MaterialShape.Shape.Cookie12Sided
                            color: Appearance.colors.colPrimary
                            colSymbol: Appearance.colors.colOnPrimary
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            iconSize: 26
                            fill: 1
                            padding: 10
                            implicitWidth: 50
                            implicitHeight: 50
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    Layout.rightMargin: 14
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.data?.city ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.data?.description ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.65
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: -2
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Appearance.rounding?.large ?? 14
                            color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    iconSize: 16
                                    text: "humidity_mid"
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: Weather.data?.humidity ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Appearance.rounding?.large ?? 14
                            color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    iconSize: 16
                                    text: "rainy"
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: Weather.data?.cr ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2x2
        Component {
            id: twoByTwoContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 24
                        fill: 1
                        padding: 10
                        implicitWidth: 48
                        implicitHeight: 48
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -2

                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: 30
                            font.weight: Font.Bold
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.data?.description ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                        
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.normal
                        text: "location_on"
                        color: Appearance.colors.colPrimary
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data?.city ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }

                // Metrics Grid
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            MaterialSymbol {
                                iconSize: 16
                                text: "humidity_mid"
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: "Humidity"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.humidity ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            MaterialSymbol {
                                iconSize: 16
                                text: "rainy"
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: "Rain"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.cr ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                        
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            MaterialSymbol {
                                iconSize: 16
                                text: "air"
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: "Wind"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.wind ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            MaterialSymbol {
                                iconSize: 16
                                text: "visibility"
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: "Visibility"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.visib ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
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

                GridLayout {
                    Layout.topMargin: -6
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                iconSize: 16
                                text: "humidity_mid"
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Weather.data?.humidity ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                iconSize: 16
                                text: "rainy"
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Weather.data?.cr ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                iconSize: 16
                                text: "air"
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Weather.data?.wind ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding?.large ?? 14
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                iconSize: 16
                                text: "visibility"
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Weather.data?.visib ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
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
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font {
                                pixelSize: 42
                                weight: Font.Bold
                            }
                            color: Appearance.colors.colPrimary
                        }


                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.smaller
                                text: "location_on"
                                color: Appearance.colors.colPrimary
                                opacity: 0.7
                            }
                            StyledText {
                                text: Weather.data?.city ?? "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.7
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -16
                        spacing: 2

                        StyledText {
                            text: Weather.data?.description ?? ""
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        
                        StyledText {
                            text: "Feels like " + (Weather.data?.tempFeelsLike ?? "--")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.55
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -10
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 26
                        fill: 1
                        padding: 11
                        implicitWidth: 52
                        implicitHeight: 52
                    }
                }

                // Metrics Grid 
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "humidity_mid"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Humidity"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.humidity ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "air"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Wind"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.wind ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "rainy"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Rain Chance"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.cr ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "visibility"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Visibility"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.visib ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "wb_twilight"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Sunrise"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.sunrise ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.large ?? 18
                        color: Appearance.colors.colSurfaceVariant ?? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            MaterialSymbol {
                                iconSize: 20
                                text: "nights_stay"
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Sunset"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: Weather.data?.sunset ?? "--"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurfaceVariant ?? Appearance.colors.colOnPrimaryContainer
                                }
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
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: { root.configEntry.sizeMode = root.sizeMode }
        }
    }
}
