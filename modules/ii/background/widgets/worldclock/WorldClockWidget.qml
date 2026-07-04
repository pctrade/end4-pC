import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "worldClock"
    implicitHeight: contentRect.implicitHeight
    implicitWidth: contentRect.implicitWidth

    property string localCityName: Weather.data?.city ?? "..."
    property string localTime: DateTime.time
    property string localDate: Qt.locale().toString(new Date(), "dddd, MMMM dd yyyy")

    property var worldCities: WorldClock.entries

    StyledDropShadow {
        target: contentRect
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        color: Appearance.colors.colPrimaryContainer
        radius: Appearance.rounding.normal
        implicitWidth: mainColumn.implicitWidth + 24
        implicitHeight: mainColumn.implicitHeight + 24

        ColumnLayout {
            id: mainColumn
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 10

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
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: root.localCityName
                    }
                }

                Item {
                    Layout.fillWidth: true
                }


                Rectangle {
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSurfaceContainerLow
                    implicitWidth: toggleRow.implicitWidth + 6
                    implicitHeight: toggleRow.implicitHeight + 4

                    RowLayout {
                        id: toggleRow
                        anchors.centerIn: parent
                        spacing: 2

                        Rectangle {
                            radius: Appearance.rounding.full
                            color: !WorldClock.use24h ? Appearance.colors.colPrimary : "transparent"
                            implicitWidth: 28
                            implicitHeight: 18
                            StyledText {
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: !WorldClock.use24h ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                                text: "12h"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WorldClock.use24h = false
                            }
                        }
                        Rectangle {
                            radius: Appearance.rounding.full
                            color: WorldClock.use24h ? Appearance.colors.colPrimary : "transparent"
                            implicitWidth: 28
                            implicitHeight: 18
                            StyledText {
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: WorldClock.use24h ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                                text: "24h"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WorldClock.use24h = true
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: -4

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    font.pixelSize: 42
                    font.weight: Font.Bold
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
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: root.worldCities
                    delegate: Rectangle {
                        id: cityCard
                        required property var modelData
                        required property int index

                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 54
                        radius: Appearance.rounding.normal

                        color: cityCard.modelData.isDay
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colLayer0
                        property color fg: cityCard.modelData.isDay
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer0

                        Behavior on color {
                            ColorAnimation { duration: 400 }
                        }

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 8
                            }
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
                                    color: cityCard.fg
                                    opacity: 0.6
                                    text: cityCard.modelData.offset
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                StyledText {
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    font.features: { "tnum": 1 }
                                    color: cityCard.fg
                                    text: cityCard.modelData.time
                                }

                                Item {
                                    Layout.fillWidth: true
                                }


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
    }
}