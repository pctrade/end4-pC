import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Text-input counterpart to ConfigSwitch: label (+ optional description) on the
// left, a lockscreen-style pill text field (see LockSurface.qml's ToolbarTextField)
// on the right. See ConfigPassword for the masked-input variant.
RowLayout {
    id: root
    property string text: ""
    property string description: ""
    property string buttonIcon: ""
    property alias placeholderText: inputField.placeholderText
    property alias value: inputField.text
    property alias inputField: inputField
    property real fieldWidth: 180

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

    TextField {
        id: inputField
        Layout.preferredWidth: root.fieldWidth
        Layout.alignment: Qt.AlignVCenter
        enabled: root.enabled
        padding: 10
        topPadding: 6
        bottomPadding: 6
        selectByMouse: true
        placeholderTextColor: Appearance.colors.colSubtext
        color: Appearance.colors.colOnLayer1
        selectedTextColor: Appearance.colors.colOnSecondaryContainer
        selectionColor: Appearance.colors.colSecondaryContainer
        renderType: Text.NativeRendering
        font {
            family: Appearance.font.family.main
            pixelSize: Appearance.font.pixelSize.small
            hintingPreference: Font.PreferFullHinting
            variableAxes: Appearance.font.variableAxes.main
        }

        background: Rectangle {
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.full
        }
    }
}
