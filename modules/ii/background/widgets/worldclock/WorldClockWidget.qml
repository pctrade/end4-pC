import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "worldClock"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    readonly property int clockCount: Math.min(Math.max(root.configEntry.clockCount ?? 4, 1), 4)
    readonly property real fourByOneWidth: root.clockCount * 132 + (root.clockCount - 1) * 12

    property real widgetWidth:  sizeMode === "2x2" ? 276 : root.fourByOneWidth
    property real widgetHeight: sizeMode === "2x2" ? 252 : 120

    readonly property real widthToggleFraction: 0.3
    readonly property real widthToggleDelta: (root.fourByOneWidth - 276) * root.widthToggleFraction

    function modeForDrag(dx) {
        if (root.sizeMode === "2x2" && dx > root.widthToggleDelta) return "4x1"
        if (root.sizeMode === "4x1" && dx < -root.widthToggleDelta) return "2x2"
        return root.sizeMode
    }

    Behavior on widgetWidth  { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
    Behavior on widgetHeight { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight

    property string localCityName: Weather.data?.city ?? "..."
    property string localTime: DateTime.time
    property string localDate: Qt.locale().toString(new Date(), "dddd, MMMM dd yyyy")
    property var worldCities: WorldClock.entries
    property bool showingSettings: false

    onShowingSettingsChanged: GlobalStates.desktopWidgetKeyboardFocus = showingSettings

    function toggleFlip() { flipAnim.start() }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width  / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 0; duration: 150; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.showingSettings = !root.showingSettings
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledDropShadow { 
            target: contentRect 
            visible: sizeMode !== "4x1"
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: sizeMode === "4x1" ? "transparent" : Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            // 2x2
            ColumnLayout {
                id: mainColumn
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: sizeMode === "2x2" && !root.showingSettings

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.hugeass
                        text: "location_on"
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2
                        StyledText {
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                            text: root.localCityName
                            elide: Text.ElideRight
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                        implicitWidth: 28; implicitHeight: 28
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "settings"
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: -4
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        font.pixelSize: 42; font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnPrimaryContainer
                        text: root.localTime
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.7
                        text: root.localDate
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    columns: 2; rowSpacing: 6; columnSpacing: 6

                    Repeater {
                        model: root.worldCities
                        delegate: Rectangle {
                            id: cityCard
                            required property var modelData
                            required property int index
                            Layout.preferredWidth: 120; Layout.preferredHeight: 54
                            radius: Appearance.rounding.normal
                            color: modelData.isDay
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            property color fg: modelData.isDay
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnLayer0
                            Behavior on color { ColorAnimation { duration: 400 } }

                            ColumnLayout {
                                anchors { fill: parent; margins: 8 }
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    StyledText {
                                        Layout.fillWidth: true
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: cityCard.fg
                                        text: cityCard.modelData.name
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: cityCard.fg; opacity: 0.6
                                        text: cityCard.modelData.offset
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 4
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Bold
                                        font.features: { "tnum": 1 }
                                        color: cityCard.fg
                                        text: cityCard.modelData.time
                                    }
                                    Item { Layout.fillWidth: true }
                                    MaterialSymbol {
                                        iconSize: Appearance.font.pixelSize.smaller
                                        text: cityCard.modelData.isDay ? "wb_sunny" : "bedtime"
                                        color: cityCard.fg
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: sizeMode === "2x2" && root.showingSettings

                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            radius: Appearance.rounding.full
                            color: "transparent"
                            implicitWidth: 28; implicitHeight: 28
                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: Appearance.font.pixelSize.normal
                                text: "arrow_back"
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleFlip()
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Flickable {
                        id: settingsFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: settingsColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: settingsColumn
                            width: settingsFlick.width
                            spacing: 10

                            ConfigSpinBox {
                                icon: "numbers"
                                text: Translation.tr("Clocks")
                                value: Config.options.background.widgets.worldClock.clockCount
                                from: 1
                                to: 4
                                stepSize: 1
                                onValueChanged: {
                                    Config.options.background.widgets.worldClock.clockCount = value;
                                }
                            }

                            StyledComboBoxSearch {
                                model: WorldClock.comboModel
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                                textRole: "label"
                                currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[0])
                                onActivated: (idx) => WorldClock.setTimezone(0, WorldClock.comboModel[idx].tz)
                            }
                            StyledComboBoxSearch {
                                model: WorldClock.comboModel; textRole: "label"
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                                currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[1])
                                onActivated: (idx) => WorldClock.setTimezone(1, WorldClock.comboModel[idx].tz)
                            }
                            StyledComboBoxSearch {
                                model: WorldClock.comboModel; textRole: "label"
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                                currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[2])
                                onActivated: (idx) => WorldClock.setTimezone(2, WorldClock.comboModel[idx].tz)
                            }
                            StyledComboBoxSearch {
                                model: WorldClock.comboModel; textRole: "label"
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                                currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[3])
                                onActivated: (idx) => WorldClock.setTimezone(3, WorldClock.comboModel[idx].tz)
                            }
                        }
                    }
                }
            }

            // 4x1
            RowLayout {
                anchors { fill: parent; margins: 0 }
                spacing: 12
                visible: sizeMode === "4x1"

                Repeater {
                    model: Math.min(root.worldCities.length, root.clockCount)
                    delegate: AndroidClock {
                        required property int index
                        property var cityData: root.worldCities[index] ?? null

                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 120
                        radius: Appearance.rounding?.verylarge ?? 30

                        backgroundColor: cityData?.isDay ?? true
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colPrimaryContainer
                        handColor: cityData?.isDay ?? true
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer0
                        centerDotColor: cityData?.isDay ?? true
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer0
                        label:       cityData?.name ?? ""
                        labelColor:  Qt.rgba(
                            (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).r,
                            (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).g,
                            (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).b,
                            0.75)
                        labelSpacing: 6
                        autoTime:    false
                        hourAngle: {
                            if (!cityData?.time) return 0
                            const p = cityData.time.split(":")
                            return (parseInt(p[0]) % 12) * 30 + parseInt(p[1]) * 0.5
                        }
                        minuteAngle: {
                            if (!cityData?.time) return 0
                            const p = cityData.time.split(":")
                            return parseInt(p[1]) * 6
                        }
                    }
                }
            }

            ResizeHandler {
                anchorItem: contentRect
                hoverActive: root.containsMouse
                locked: Config.options.background.widgetsLocked || root.showingSettings
                currentWidth: root.widgetWidth
                onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx) }
                onResizeFinished: { root.configEntry.sizeMode = root.sizeMode }
            }
        }
    }
}
