import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

GroupButton {
    id: root
    bounce: false
    property string buttonIcon
    property string buttonIconSource
    property bool leftmost: false
    property bool rightmost: false

    property bool isDragging: false
    property color colText: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer

    leftRadius: (toggled || leftmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    rightRadius: (toggled || rightmost) ? (height / 2) : Appearance.rounding.unsharpenmore

    horizontalPadding: 12
    verticalPadding: 8 

    colBackground: Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    contentItem: RowLayout {
        spacing: 4 * (root.buttonText?.length > 0)

        Loader {
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
                    implicitWidth: Appearance.font.pixelSize.larger
                    implicitHeight: Appearance.font.pixelSize.larger

                    CustomIcon {
                        anchors.centerIn: parent
                        width: Appearance.font.pixelSize.larger
                        height: Appearance.font.pixelSize.larger
                        source: root.buttonIconSource
                        colorize: true
                        color: root.colText

                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }

            Component {
                id: materialSymbolComponent

                Item {
                    implicitWidth: materialSymbol.implicitWidth

                    MaterialSymbol {
                        id: materialSymbol
                        anchors.centerIn: parent
                        text: root.buttonIcon
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.colText

                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }
        }

        Item {
            implicitWidth: root.buttonText?.length > 0 ? textItem.implicitWidth : 0
            implicitHeight: textMetrics.height
            TextMetrics {
                id: textMetrics
                font.family: Appearance.font.family.main
                text: "Abc"
            }
            StyledText {
                id: textItem
                anchors.centerIn: parent
                color: root.colText
                text: root.buttonText

                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }
}
