import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Password counterpart to ConfigInput: same left label/description, but the field
// is masked like the lockscreen's password box (LockSurface.qml's ToolbarTextField),
// with an optional show/hide reveal toggle (set revealButton: false to omit it).
RowLayout {
    id: root
    property string text: ""
    property string description: ""
    property string buttonIcon: ""
    property alias placeholderText: inputField.placeholderText
    property alias value: inputField.text
    property alias inputField: inputField
    property bool revealButton: true
    property bool revealed: false
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

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        TextField {
            id: inputField
            Layout.preferredWidth: root.fieldWidth
            enabled: root.enabled
            padding: 10
            topPadding: 6
            bottomPadding: 6
            selectByMouse: true
            echoMode: root.revealed ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
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

        RippleButton {
            visible: root.revealButton
            enabled: root.enabled
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            onClicked: root.revealed = !root.revealed

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.larger
                text: root.revealed ? "visibility_off" : "visibility"
                color: Appearance.colors.colOnLayer1
            }
        }
    }
}
