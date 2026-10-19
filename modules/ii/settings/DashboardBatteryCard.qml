import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar

DashboardCard {
    id: root

    readonly property var options: [
        { value: "bar", name: "Android" },
        { value: "ios", name: "iOS" },
        { value: "macos", name: "macOS" },
        { value: "windows", name: "Windows" },
        { value: "ring", name: Translation.tr("Ring") },
        { value: "icon", name: Translation.tr("Icon") },
        { value: "number", name: Translation.tr("Number") }
    ]
    readonly property string screenName: GlobalStates.dashboardBarScreen
    readonly property var batteryConfig: Config.barForScreen(root.screenName).battery
    readonly property string current: root.batteryConfig.style

    tint: Appearance.colors.colLayer1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Cookie9Sided
                text: "battery_android_6"
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Translation.tr("Battery style")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Choose how the battery looks in the bar")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: root.options

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool selected: root.current === modelData.value

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    radius: selected ? 22 : Appearance.rounding.normal
                    color: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                    Behavior on radius {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 60
                            implicitHeight: 34

                            BatteryGlyph {
                                anchors.centerIn: parent
                                style: tile.modelData.value
                                percentage: 0.78
                                isCharging: false
                                showPercentage: root.batteryConfig.showPercentage
                                showCharging: root.batteryConfig.showCharging
                                contentColor: tile.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: tile.selected ? Font.DemiBold : Font.Normal
                            color: tile.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setBarValueForScreen(root.screenName, "battery.style", tile.modelData.value)
                    }
                }
            }
        }
    }
}
