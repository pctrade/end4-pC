import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string controlKey: ""
    property string title: ""
    property string icon: "tune"
    property var tileShape: MaterialShape.Shape.Puffy
    property var override: null

    readonly property var control: override ?? SettingsQuickControls.controls[controlKey] ?? null
    readonly property var options: control?.options ?? []
    readonly property var currentValue: control ? control.get() : null

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

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }

        StyledComboBoxSearch {
            Layout.fillWidth: true
            model: root.options
            textRole: "displayName"
            splitIndicator: true
            colBackground: Qt.rgba(1, 1, 1, 0.14)
            colBackgroundHover: Qt.rgba(1, 1, 1, 0.24)
            currentIndex: {
                const index = root.options.findIndex(item => item.value === root.currentValue);
                return index !== -1 ? index : 0;
            }
            onActivated: index => {
                const value = root.options[index].value;
                Qt.callLater(() => root.control.set(value));
            }
        }
    }
}
