import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var pinData: null
    property int pinIndex: 0
    property bool isDragging: false
    property bool isHandleHovered: false

    readonly property string pinId: pinData?.id ?? ""
    readonly property string pinContent: pinData?.content ?? ""
    readonly property string pinImage: pinData?.image ?? ""
    readonly property var pinCreatedAt: pinData?.createdAt ?? 0

    width: ListView.view ? ListView.view.width : parent.width
    implicitHeight: cardBackground.implicitHeight

    // Feedback state for copy action
    property bool copiedFeedback: false

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.copiedFeedback = false
    }

    Rectangle {
        id: cardBackground
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.isDragging ? 2 : 0
            rightMargin: root.isDragging ? 2 : 0
        }
        implicitHeight: Math.max(48, contentLayout.implicitHeight + 20)
        radius: Appearance.rounding.normal
        color: root.isDragging ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        border.width: root.isDragging ? 2 : 1
        border.color: root.isDragging
            ? Appearance.colors.colPrimary
            : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.7)

        Behavior on anchors.leftMargin { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on anchors.rightMargin { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        // Dedicated vertical drag strip on the left with 6-dot drag indicator
        Item {
            id: dragStrip
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: 26

            MaterialSymbol {
                anchors.centerIn: parent
                text: "drag_indicator"
                iconSize: 18
                color: root.isDragging ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                opacity: root.isDragging ? 1.0 : (root.isHandleHovered ? 0.9 : 0.4)
                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            }
        }

        // Delete "X" button top right
        RippleButton {
            id: deleteButton
            anchors {
                top: parent.top
                right: parent.right
                margins: 8
            }
            z: 10
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.2)
            colBackgroundHover: Appearance.colors.colErrorContainer
            colRipple: Appearance.colors.colError

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 15
                color: deleteButton.hovered ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                horizontalAlignment: Text.AlignHCenter
            }

            StyledToolTip {
                extraVisibleCondition: deleteButton.hovered
                text: Translation.tr("Delete")
            }

            onClicked: {
                Pinboard.deletePin(root.pinId)
            }
        }

        ColumnLayout {
            id: contentLayout
            anchors {
                top: parent.top
                left: dragStrip.right
                right: parent.right
                margins: 10
                leftMargin: 2
            }
            spacing: 8

            // Image section (if item contains an image)
            Rectangle {
                id: imageContainer
                visible: root.pinImage.length > 0
                Layout.fillWidth: true
                // Scale height proportionally to the image's natural aspect ratio.
                implicitHeight: {
                    if (!visible) return 0;
                    const iw = displayImage.implicitWidth;
                    const ih = displayImage.implicitHeight;
                    if (iw > 0 && ih > 0) {
                        const scaled = (width * ih) / iw;
                        return Math.min(600, Math.max(90, scaled));
                    }
                    return 160;
                }
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                clip: true

                StyledImage {
                    id: displayImage
                    anchors.fill: parent
                    source: root.pinImage ? ("file://" + FileUtils.trimFileProtocol(root.pinImage)) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                }

                MouseArea {
                    id: imageMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        Quickshell.execDetached(["xdg-open", FileUtils.trimFileProtocol(root.pinImage)])
                    }
                    StyledToolTip {
                        extraVisibleCondition: imageMouseArea.containsMouse
                        text: Translation.tr("Click to open image")
                    }
                }
            }

            // Text section (if item contains text)
            StyledText {
                id: noteText
                visible: root.pinContent.length > 0
                Layout.fillWidth: true
                Layout.rightMargin: (root.pinImage.length > 0) ? 0 : 28
                text: root.pinContent
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
            }

            // Footer row: timestamp & actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: {
                        if (!root.pinCreatedAt) return ""
                        const d = new Date(root.pinCreatedAt)
                        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + " · " + d.toLocaleDateString()
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                Item {
                    Layout.fillWidth: true
                }

                // "Copied!" feedback text
                StyledText {
                    visible: root.copiedFeedback
                    text: Translation.tr("Copied!")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary
                }

                // Copy button
                RippleButton {
                    id: copyButton
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.copiedFeedback ? "check" : "content_copy"
                        iconSize: 15
                        color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledToolTip {
                        extraVisibleCondition: copyButton.hovered
                        text: Translation.tr("Copy to clipboard")
                    }

                    onClicked: {
                        if (root.pinContent.length > 0) {
                            Quickshell.execDetached(["bash", "-c", `printf '%s' '${StringUtils.shellSingleQuoteEscape(root.pinContent)}' | wl-copy`])
                            root.copiedFeedback = true
                            copiedTimer.restart()
                        } else if (root.pinImage.length > 0) {
                            Quickshell.execDetached(["bash", "-c", `wl-copy -t image/png < '${StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(root.pinImage))}'`])
                            root.copiedFeedback = true
                            copiedTimer.restart()
                        }
                    }
                }

                // Open in default viewer button (if image exists)
                RippleButton {
                    id: openButton
                    visible: root.pinImage.length > 0
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        iconSize: 15
                        color: Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledToolTip {
                        extraVisibleCondition: openButton.hovered
                        text: Translation.tr("Open with default app")
                    }

                    onClicked: {
                        Quickshell.execDetached(["xdg-open", FileUtils.trimFileProtocol(root.pinImage)])
                    }
                }
            }
        }
    }
}
