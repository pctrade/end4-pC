import QtQuick
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
    implicitHeight: contentRect.implicitHeight
    implicitWidth: contentRect.implicitWidth

    StyledDropShadow {
        target: contentRect
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        color: Appearance.colors.colPrimaryContainer
        radius: Appearance.rounding.normal
        implicitWidth: 200
        implicitHeight: 160

        Column {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 4

            Row {
                spacing: 4
                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.small
                    text: "location_on"
                    color: Appearance.colors.colOnPrimaryContainer
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    text: Weather.data?.city ?? "--"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: 16

                StyledText {
                    id: tempText
                    font {
                        pixelSize: 50
                        family: Appearance.font.family.expressive
                        weight: Font.Medium
                    }
                    color: Appearance.colors.colPrimary
                    text: Weather.data?.temp ?? "--°"
                    anchors.verticalCenter: parent.verticalCenter
                }

                MaterialShape {
                    shape: MaterialShape.Shape.Square
                    color: Appearance.colors.colPrimary
                    implicitSize: 52
                    anchors.verticalCenter: parent.verticalCenter

                    MaterialSymbol {
                        iconSize: 32
                        fill: 1
                        color: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        anchors.centerIn: parent
                    }
                }
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                text: Weather.data?.description ?? ""
            }

            Row {
                spacing: 12

                Row {
                    spacing: 4
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.small
                        text: "humidity_mid"
                        color: Appearance.colors.colOnPrimaryContainer
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        text: Weather.data?.humidity ?? "--"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.small
                        text: "air"
                        color: Appearance.colors.colOnPrimaryContainer
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        text: Weather.data?.wind ?? "--"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}