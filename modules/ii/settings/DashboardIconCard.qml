import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "image"
    property var tileShape: MaterialShape.Shape.Flower

    readonly property var customConfig: Config.options.custom
    readonly property string iconRole: customConfig.iconColor
    readonly property color iconTint: Appearance.colors["col" + iconRole.charAt(0).toUpperCase() + iconRole.slice(1)] ?? Appearance.colors.colOnLayer0
    readonly property string currentName: (customConfig.distroIcon || SystemInfo.distroIcon).replace("-symbolic", "")

    tint: Appearance.colors.colPrimaryContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 24
                fill: 1
                padding: 10
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.currentName
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.12)

                CustomIcon {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: root.customConfig.distroIcon || SystemInfo.distroIcon
                    colorize: root.customConfig.colorizeIcon
                    color: root.iconTint
                    customFolder: root.customConfig.iconsPath
                }
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: picker.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            TouchpadScrollArea { flickable: flick }

            IconPickerGrid {
                id: picker
                width: flick.width
                y: Math.max(0, flick.height - height)
                customFolder: root.customConfig.iconsPath
                currentValue: root.customConfig.distroIcon
                colorize: root.customConfig.colorizeIcon
                iconColor: root.iconTint
                onSelected: name => {
                    Qt.callLater(() => { Config.options.custom.distroIcon = name; });
                }
            }
        }
    }
}
