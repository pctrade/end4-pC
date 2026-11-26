import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string controlKey: ""
    property string title: ""
    property string icon: "auto_awesome"
    property var tileShape: MaterialShape.Shape.SoftBurst
    property var override: null

    readonly property var control: override ?? SettingsQuickControls.controls[controlKey] ?? null
    readonly property var currentValue: control ? control.get() : null
    readonly property bool inactive: ColorSchemes.current !== ""

    readonly property var allOptions: control?.options ?? []
    readonly property var firstRow: allOptions.slice(0, Math.ceil(allOptions.length / 2))
    readonly property var secondRow: allOptions.slice(Math.ceil(allOptions.length / 2))

    tint: Appearance.colors.colSecondaryContainer

    component Pill: RippleButton {
        id: pill
        property var card: null
        property var option: ({})

        readonly property bool selected: card.currentValue === option.value

        implicitHeight: 40
        horizontalPadding: 16
        buttonRadius: 14
        colBackground: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.12)
        colBackgroundHover: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.22)
        colRipple: Qt.rgba(1, 1, 1, 0.3)
        downAction: () => {
            const value = option.value;
            const control = card.control;
            Qt.callLater(() => control.set(value));
        }

        contentItem: RowLayout {
            spacing: 6

            Item { Layout.fillWidth: true }

            MaterialSymbol {
                text: pill.option.icon
                iconSize: 18
                fill: pill.selected ? 1 : 0
                color: pill.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                text: pill.option.displayName
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: pill.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
            }

            Item { Layout.fillWidth: true }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            radius: 18
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    shape: root.tileShape
                    text: root.icon
                    iconSize: 26
                    fill: 1
                    padding: 11
                    color: Appearance.colors.colSecondary
                    colSymbol: Appearance.colors.colOnSecondary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("How colors are made from your wallpaper")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                        opacity: 0.75
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: "transparent"
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.firstRow

                        delegate: Pill {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            card: root
                            option: modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.secondRow

                        delegate: Pill {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            card: root
                            option: modelData
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
