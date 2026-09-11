import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    property string buttonIcon
    property string buttonIconSource
    property bool buttonIconColorize: true
    property real iconSize: Appearance.font.pixelSize.larger
    colBackgroundHover: "transparent"

    Layout.fillWidth: true
    Layout.bottomMargin: 6 //Visually it works and I don't know why this should be handled by the parent.
    implicitHeight: contentItem.implicitHeight + 8 
    font.pixelSize: Appearance.font.pixelSize.small
    
    onClicked: checked = !checked

    contentItem: RowLayout {
        spacing: 10
        Loader {
            id: iconWidget
            Layout.alignment: Qt.AlignVCenter
            active: (root.buttonIconSource && root.buttonIconSource.length > 0)
                || (root.buttonIcon && root.buttonIcon.length > 0)
            visible: active
            sourceComponent: root.buttonIconSource && root.buttonIconSource.length > 0
                ? customIconComponent
                : materialSymbolComponent

            Component {
                id: customIconComponent

                Item {
                    implicitWidth: root.iconSize
                    implicitHeight: root.iconSize

                    CustomIcon {
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        source: root.buttonIconSource
                        colorize: root.buttonIconColorize
                        smooth: true
                        color: Appearance.colors.colOnSecondaryContainer
                        opacity: root.enabled ? 1 : 0.4
                    }
                }
            }

            Component {
                id: materialSymbolComponent

                OptionalMaterialSymbol {
                    id: materialSymbol
                    icon: root.buttonIcon
                    opacity: root.enabled ? 1 : 0.4
                    iconSize: root.iconSize
                }
            }
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        StyledSwitch {
            id: switchWidget
            down: root.down
            Layout.fillWidth: false
            checked: root.checked
            onClicked: root.clicked()
        }
    }
}
