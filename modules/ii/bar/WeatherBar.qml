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

    implicitWidth: vertical ? 32 : (contentLoader.item?.implicitWidth ?? 0) 
    implicitHeight: vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

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

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: Appearance.spacing.small

            MaterialSymbol {
                visible: !root.isMaterial
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: !root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignVCenter
                leftPadding: Appearance.spacing.small
            }

            Rectangle {
                visible: root.isMaterial
                width: 25
                height: 25
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

    Component {
        id: colContent
        ColumnLayout {
            spacing: root.isMaterial ? 2 : 0

            MaterialSymbol {
                visible: !root.isMaterial
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                visible: !root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                visible: root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
                text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Appearance.spacing.verysmall
            }

            Rectangle {
                visible: root.isMaterial
                width: 25
                height: 25
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

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}