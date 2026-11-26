import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    readonly property var control: SettingsQuickControls.controls["bar:Bar position"] ?? null
    readonly property int current: control ? control.get() : 0
    readonly property bool atBottom: (current & 1) !== 0
    readonly property bool vertical: (current & 2) !== 0
    readonly property real thickness: 18

    tint: Appearance.colors.colSecondaryContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Pentagon
                text: "toast"
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colSecondary
                colSymbol: Appearance.colors.colOnSecondary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Translation.tr("Bar position")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSecondaryContainer
                }
                StyledText {
                    text: Translation.tr("Where the bar lives")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                    opacity: 0.75
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: screen
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * 1.7)
                height: width / 1.7
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: 2
                border.color: Appearance.colors.colOnSecondaryContainer

                Rectangle {
                    id: mockBar
                    radius: 8
                    color: Appearance.colors.colSecondary
                    x: root.vertical ? (root.atBottom ? screen.width - width - 6 : 6) : 6
                    y: root.vertical ? 6 : (root.atBottom ? screen.height - height - 6 : 6)
                    width: root.vertical ? root.thickness : screen.width - 12
                    height: root.vertical ? screen.height - 12 : root.thickness

                    Behavior on x { SpringAnimation { spring: 3.5; damping: 0.3 } }
                    Behavior on y { SpringAnimation { spring: 3.5; damping: 0.3 } }
                    Behavior on width { SpringAnimation { spring: 3.5; damping: 0.3 } }
                    Behavior on height { SpringAnimation { spring: 3.5; damping: 0.3 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: !root.vertical

                        Repeater {
                            model: 3
                            Rectangle { width: 18; height: 5; radius: 2.5; color: Appearance.colors.colOnSecondary; opacity: 0.8 }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: root.vertical

                        Repeater {
                            model: 3
                            Rectangle { width: 5; height: 18; radius: 2.5; color: Appearance.colors.colOnSecondary; opacity: 0.8 }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.control?.options ?? []

                delegate: RippleButton {
                    id: option
                    required property var modelData

                    readonly property bool selected: root.current === modelData.value

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    buttonRadius: 20
                    colBackground: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.12)
                    colBackgroundHover: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.22)
                    colRipple: Qt.rgba(1, 1, 1, 0.3)
                    downAction: () => {
                        const value = modelData.value;
                        Qt.callLater(() => root.control.set(value));
                    }

                    contentItem: RowLayout {
                        spacing: 4
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: option.modelData.icon
                            iconSize: 16
                            color: option.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: option.modelData.displayName
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: option.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
