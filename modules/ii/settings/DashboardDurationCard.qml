import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string controlKey: ""
    property string title: ""
    property string icon: "timer"
    property var tileShape: MaterialShape.Shape.Clover4Leaf
    property var override: null

    readonly property var control: override ?? SettingsQuickControls.controls[controlKey] ?? null
    readonly property int seconds: control ? Number(control.get()) : 0
    readonly property var units: [
        { label: Translation.tr("sec"), value: 1 },
        { label: Translation.tr("min"), value: 60 },
        { label: Translation.tr("h"), value: 3600 }
    ]

    property int displayValue: 0
    property int unit: 60

    tint: Appearance.colors.colTertiaryContainer

    function toDisplay(total) {
        if (total <= 0) return [0, 60];
        if (total % 3600 === 0) return [total / 3600, 3600];
        if (total % 60 === 0) return [total / 60, 60];
        return [total, 1];
    }

    function sync() {
        const display = toDisplay(seconds);
        displayValue = display[0];
        unit = display[1];
    }

    function commit(value, newUnit) {
        const total = Math.max(0, Math.round(value)) * newUnit;
        Qt.callLater(() => control.set(total));
    }

    onSecondsChanged: sync()
    Component.onCompleted: sync()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 24
                fill: 1
                padding: 10
                color: Appearance.colors.colTertiary
                colSymbol: Appearance.colors.colOnTertiary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnTertiaryContainer
                elide: Text.ElideRight
            }

            StyledText {
                text: root.displayValue === 0 ? Translation.tr("Off") : root.displayValue
                font.pixelSize: 28
                font.weight: Font.Light
                color: Appearance.colors.colOnTertiaryContainer
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [-1]

                delegate: RippleButton {
                    required property int modelData

                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: 20
                    colBackground: Qt.rgba(1, 1, 1, 0.14)
                    colBackgroundHover: Qt.rgba(1, 1, 1, 0.26)
                    colRipple: Qt.rgba(1, 1, 1, 0.35)
                    downAction: () => root.commit(root.displayValue + modelData, root.unit)
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "remove"
                            iconSize: 22
                            color: Appearance.colors.colOnTertiaryContainer
                        }
                    }
                }
            }

            Repeater {
                model: root.units

                delegate: RippleButton {
                    id: unitButton
                    required property var modelData

                    readonly property bool selected: root.unit === modelData.value

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    buttonRadius: 14
                    colBackground: selected ? Appearance.colors.colTertiary : Qt.rgba(1, 1, 1, 0.12)
                    colBackgroundHover: selected ? Appearance.colors.colTertiary : Qt.rgba(1, 1, 1, 0.22)
                    colRipple: Qt.rgba(1, 1, 1, 0.3)
                    downAction: () => {
                        root.unit = modelData.value;
                        root.commit(root.displayValue, modelData.value);
                    }
                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: unitButton.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: unitButton.selected ? Appearance.colors.colOnTertiary : Appearance.colors.colOnTertiaryContainer
                    }
                }
            }

            Repeater {
                model: [1]

                delegate: RippleButton {
                    required property int modelData

                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: 20
                    colBackground: Qt.rgba(1, 1, 1, 0.14)
                    colBackgroundHover: Qt.rgba(1, 1, 1, 0.26)
                    colRipple: Qt.rgba(1, 1, 1, 0.35)
                    downAction: () => root.commit(root.displayValue + modelData, root.unit)
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: 22
                            color: Appearance.colors.colOnTertiaryContainer
                        }
                    }
                }
            }
        }
    }
}
