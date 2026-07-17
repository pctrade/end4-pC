import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Text-input counterpart to ConfigSwitch: label (+ optional description) on the
// left and a lockscreen-style pill text field on the right. Set password: true
// to mask the input with the lockscreen's animated Material shape characters.
RowLayout {
    id: root
    property string text: ""
    property string description: ""
    property string buttonIcon: ""
    property alias placeholderText: inputField.placeholderText
    property alias value: inputField.text
    property alias inputField: inputField
    property bool password: false
    property bool revealButton: password
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
            echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
            inputMethodHints: root.password ? Qt.ImhSensitiveData : Qt.ImhNone
            placeholderTextColor: Appearance.colors.colSubtext
            // Native password glyphs are transparent because PasswordChars draws the
            // animated Material shapes in their place.
            color: root.password && !root.revealed ? "transparent" : Appearance.colors.colOnLayer1
            selectedTextColor: root.password && !root.revealed ? "transparent" : Appearance.colors.colOnSecondaryContainer
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

            Loader {
                active: root.password && !root.revealed
                // Keep the Flickable-based glyph overlay purely visual so clicks reach
                // the TextField beneath it.
                enabled: false
                anchors {
                    fill: parent
                    leftMargin: inputField.padding
                    rightMargin: inputField.padding
                }
                sourceComponent: PasswordChars {
                    charSize: 16
                    length: inputField.text.length
                    selectionStart: inputField.selectionStart
                    selectionEnd: inputField.selectionEnd
                    cursorPosition: inputField.cursorPosition
                    showCursor: inputField.activeFocus
                }
            }
        }

        RippleButton {
            visible: root.password && root.revealButton
            enabled: root.enabled
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive
            onClicked: root.revealed = !root.revealed

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -2
                iconSize: Appearance.font.pixelSize.larger
                text: root.revealed ? "visibility_off" : "visibility"
                color: Appearance.colors.colOnLayer1
            }
        }
    }
}
