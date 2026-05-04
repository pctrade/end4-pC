pragma ComponentBehavior: Bound
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

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (rowLoader.item?.implicitWidth ?? 0) + 6
    implicitHeight: vertical ? (colLoader.item?.implicitHeight ?? 0) + 12 : Appearance.sizes.barHeight

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
        sourceComponent: RowLayout {
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

    // Vertical layout
    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
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

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}