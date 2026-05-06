#pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool hovered: false
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : root.isMaterial ? (rowLoader.item?.implicitWidth ?? 0) : (rowLoader.item?.implicitWidth ?? 0) + 6
    implicitHeight: vertical ? (colLoader.item?.implicitHeight ?? 0) + 6 : Appearance.sizes.barHeight
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onPressed: {
        if (mouse.button === Qt.RightButton) {
            Weather.getData();
            Quickshell.execDetached(["notify-send",
                Translation.tr("Weather"),
                Translation.tr("Refreshing (manually triggered)"),
                "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    // Horizontal layout
    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? rowMaterial : rowDefault

        Component {
            id: rowDefault
            RowLayout {
                MaterialSymbol {
                    fill: 0
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    Layout.alignment: Qt.AlignVCenter
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: Weather.data?.temp ?? "--°"
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Component {
            id: rowMaterial
            Rectangle {
                id: pill
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.full
                implicitHeight: 30
                implicitWidth: pillRow.implicitWidth + 4 + 4 

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 6

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colPrimary
                        text: Weather.data?.temp ?? "--°"
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 5
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 0
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    // Vertical layout
    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? colMaterial : colDefault

        Component {
            id: colDefault
            ColumnLayout {
                spacing: 4
                MaterialSymbol {
                    fill: 0
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Component {
            id: colMaterial
            Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.full
                implicitWidth: 30
                implicitHeight: pillCol.implicitHeight + 8

                ColumnLayout {
                    id: pillCol
                    anchors.centerIn: parent
                    spacing: 3

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colPrimary
                        text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 3
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        Layout.alignment: Qt.AlignHCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 0
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}