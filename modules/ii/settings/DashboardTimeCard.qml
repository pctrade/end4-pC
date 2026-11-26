import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "schedule"
    property var tileShape: MaterialShape.Shape.Sunny

    readonly property var formatControl: SettingsQuickControls.controls["general:Format"]
    readonly property var secondsControl: SettingsQuickControls.controls["general:Second precision"]
    readonly property var dateControl: SettingsQuickControls.controls["general:Show date"]
    readonly property string currentFormat: String(formatControl.get() ?? "")
    readonly property bool showSeconds: !!secondsControl.get()
    readonly property bool showDate: !!dateControl.get()

    tint: Appearance.colors.colPrimaryContainer

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

        MaterialShape {
            shape: MaterialShape.Shape.Sunny
            implicitSize: root.height * 1.1
            color: Appearance.colors.colPrimary
            anchors.right: parent.right
            anchors.rightMargin: -implicitSize * 0.2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    shape: root.tileShape
                    text: root.icon
                    iconSize: 22
                    fill: 1
                    padding: 9
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                }

                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                visible: root.showDate
                text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.colors.colPrimary
            }

            RowLayout {
                spacing: 8

                StyledText {
                    text: DateTime.use12HourFormat ? DateTime.time.replace(/\s*[ap]\.?\s?m\.?\s*$/i, "") : DateTime.time
                    color: Appearance.colors.colOnPrimaryContainer
                    font {
                        pixelSize: 84
                        weight: Config.options.background.widgets.clock.digital.font.weight
                        family: Config.options.background.widgets.clock.digital.font.family
                        variableAxes: ({
                            "wdth": Config.options.background.widgets.clock.digital.font.width,
                            "ROND": Config.options.background.widgets.clock.digital.font.roundness
                        })
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 14
                    spacing: 0

                    StyledText {
                        visible: root.showSeconds
                        text: Qt.locale().toString(DateTime.clock.date, "ss")
                        font.pixelSize: 30
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }
                    StyledText {
                        visible: DateTime.use12HourFormat
                        text: Qt.locale().toString(DateTime.clock.date, "AP")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
}
