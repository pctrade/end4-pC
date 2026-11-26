import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: root

    property string text: ""
    property string description: ""
    property string buttonIcon: ""
    property var model: []
    property string textRole: "displayName"
    property var currentValue: undefined

    property real fieldWidth: 220
    property bool fixedWidth: false
    property bool searchable: false

    readonly property var comboBox: root.searchable ? searchComboBox : comboBox

    signal selected(var newValue)

    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    OptionalMaterialSymbol {
        icon: root.buttonIcon
        iconSize: Appearance.font.pixelSize.larger
        opacity: root.enabled ? 1 : 0.4
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.description.length > 0
            text: root.description
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
            opacity: root.enabled ? 1 : 0.4
        }
    }

    StyledComboBox {
        id: comboBox
        visible: !root.searchable
        Layout.fillWidth: !root.fixedWidth
        Layout.preferredWidth: root.fieldWidth
        Layout.alignment: Qt.AlignVCenter
        enabled: root.enabled
        textRole: root.textRole
        model: root.model

        currentIndex: {
            const index = root.model.findIndex(item => item.value === root.currentValue);
            return index !== -1 ? index : 0;
        }

        onActivated: index => {
            root.selected(comboBox.model[index].value);
        }
    }

    StyledComboBoxSearch {
        id: searchComboBox
        visible: root.searchable
        Layout.fillWidth: !root.fixedWidth
        Layout.preferredWidth: root.fieldWidth
        Layout.alignment: Qt.AlignVCenter
        enabled: root.enabled
        textRole: root.textRole
        model: root.model

        currentIndex: {
            const index = root.model.findIndex(item => item.value === root.currentValue);
            return index !== -1 ? index : 0;
        }

        onActivated: index => {
            root.selected(searchComboBox.model[index].value);
        }
    }
}
