import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    tint: Appearance.colors.colLayer1

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.cardRadius
            }
        }

        WorldMap {
            anchors.fill: parent
            anchors.margins: 12
            dotColor: Appearance.colors.colOutlineVariant
            markerColor: Appearance.colors.colPrimary
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 14
            radius: Appearance.rounding.large
            color: Appearance.colors.colPrimaryContainer
            implicitWidth: infoRow.implicitWidth + 28
            implicitHeight: infoRow.implicitHeight + 24

            RowLayout {
                id: infoRow
                anchors.centerIn: parent
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    shape: Weather.data.wCode === 800 ? MaterialShape.Shape.Sunny : MaterialShape.Shape.Cookie12Sided
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: 28
                    fill: 1
                    padding: 10
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: Weather.data.temp || "--"
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        text: Weather.data.city + (Weather.data.description ? " · " + Weather.data.description : "")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }
                }

                Repeater {
                    model: [
                        { icon: "humidity_percentage", value: Weather.data.humidity },
                        { icon: "air", value: Weather.data.wind }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        implicitHeight: 30
                        implicitWidth: chipRow.implicitWidth + 20

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: modelData.value
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }
                }
            }
        }
    }
}
