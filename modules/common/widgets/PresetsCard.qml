import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common
import qs.modules.common.functions

Rectangle {
    id: root

    property string imageSource: ""
    property string title: ""
    property string description: ""
    property var onApply: () => {}
    property var onRemove: () => {}

    implicitWidth: 293 
    implicitHeight: contentColumn.implicitHeight + 14
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: "transparent"

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 0
        }
        spacing: 6

        // Header
        RowLayout{
            Layout.leftMargin: 10
            Layout.topMargin: 6
            spacing: 10
            MaterialShapeWrappedMaterialSymbol {
                id: avatarShape
                shape: MaterialShape.Shape.Circle 
                text: root.title.length > 0 ? root.title.charAt(0).toUpperCase() : "?"
                iconSize: Appearance.font.pixelSize.normal
                implicitSize: 36
                font: Appearance.font.family.main
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout{
                spacing: -4
                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                // Description
                StyledText {
                    Layout.fillWidth: true
                    visible: root.description.length > 0
                    text: root.description
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
            MaterialSymbol {
                Layout.alignment: Qt.AlignRight // im a placeholder someday I will do something =P
                Layout.rightMargin: 12
                font.pixelSize: Appearance.font.pixelSize.huge
                text: "more_vert"
            }
        }

        // Wall
        Rectangle {
            id: imageRect
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            implicitHeight: 130
            radius: 0
            color: Appearance.colors.colLayer2
            clip: true

            StyledImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.imageSource
                cache: false
                antialiasing: true
                sourceSize.width: imageRect.width * 2
                sourceSize.height: imageRect.height * 2
                visible: root.imageSource !== ""
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: imageRect.width
                        height: imageRect.height
                        radius: imageRect.radius
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.imageSource === ""
                text: "wallpaper"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colSubtext
            }
        }

        // Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 8
            Layout.bottomMargin: -4
            spacing: 8

            Item { Layout.fillWidth: true }

            GroupButton {
                id: removeBtn
                bounce: false
                toggled: false
                leftRadius: height / 2
                rightRadius: height / 2
                Layout.fillWidth: false
                Layout.fillHeight: false
                implicitHeight: 36
                horizontalPadding: 14
                verticalPadding: 8
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimaryContainerHover, 0.8)
                colBackgroundActive: Appearance.colors.colPrimaryContainerActive
                contentItem: StyledText {
                    text: "Remove"
                    color: Appearance.colors.colPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.onRemove()
            }

            GroupButton {
                id: applyBtn
                bounce: false
                toggled: false
                leftRadius: height / 2
                rightRadius: height / 2
                Layout.fillWidth: false
                Layout.fillHeight: false
                implicitHeight: 36
                horizontalPadding: 14
                verticalPadding: 8
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colBackgroundActive: Appearance.colors.colPrimaryContainerActive
                contentItem: StyledText {
                    text: "Apply"
                    color: Appearance.colors.colOnPrimaryContainer
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.onApply()
            }
        }
    }
}