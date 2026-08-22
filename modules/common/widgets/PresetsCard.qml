import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property string imageSource: ""
    property string title: ""
    property string description: ""
    property var onApply: () => {}
    property var onRemove: () => {}
    property var onRename: (newName) => {}
    property bool isEditing: false

    function startEditing() {
        editInput.text = root.title
        root.isEditing = true
        Qt.callLater(() => {
            editInput.forceActiveFocus()
            editInput.selectAll()
        })
    }

    function confirmEdit() {
        const trimmed = editInput.text.trim()
        if (trimmed.length > 0 && trimmed !== root.title) {
            root.onRename(trimmed)
        }
        root.isEditing = false
    }

    function cancelEdit() {
        root.isEditing = false
    }

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
        RowLayout {
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

            ColumnLayout {
                visible: !root.isEditing
                Layout.fillWidth: true
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

            Rectangle {
                visible: root.isEditing
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer2
                border.width: editInput.activeFocus ? 2 : 1
                border.color: editInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                Behavior on border.color {
                    ColorAnimation { 
                        duration: Appearance.animation.elementMoveFast.duration 
                    }
                }

                StyledTextInput {
                    id: editInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    font.pixelSize: Appearance.font.pixelSize.small

                    Keys.onReturnPressed: root.confirmEdit()
                    Keys.onEnterPressed: root.confirmEdit()
                    Keys.onEscapePressed: root.cancelEdit()

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                    }
                }
            }

            RippleButton {
                id: editBtn
                visible: !root.isEditing
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 12
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: height / 2
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "edit"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }
                onClicked: root.startEditing()
            }

            RowLayout {
                visible: root.isEditing
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 12
                spacing: 4

                RippleButton {
                    id: confirmBtn
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "check"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    onClicked: root.confirmEdit()
                }

                RippleButton {
                    id: cancelBtn
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: height / 2
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "close"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                    onClicked: root.cancelEdit()
                }
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

            Item { 
                Layout.fillWidth: true
            }

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