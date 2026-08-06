import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: shelfRoot
    visible: GlobalStates.dropShelfOpen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:dropshelf"
    color: "transparent"

    anchors { top: true; left: true }
    margins {
        left: Math.max(20, GlobalStates.dropShelfX - implicitWidth / 2)
        top: Math.max(20, GlobalStates.dropShelfY - implicitHeight - 30)
    }

    implicitWidth: 360
    implicitHeight: contentColumn.implicitHeight + 24

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]

        onEntered: (drag) => {
            drag.accepted = drag.hasUrls
        }

        onDropped: (drop) => {
            if (!drop.hasUrls) {
                drop.accepted = false
                return
            }
            DropShelf.addItems(drop.urls)
            drop.accept()
        }
    }

    StyledRectangularShadow {
        target: shelfBg
    }

    Rectangle {
        id: shelfBg
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Carousel {
                id: shelfCarousel
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                showCurrentIndicator: false
                model: DropShelf.items
                largeItemWidthRatio: 0.42
                mediumItemWidthRatio: 0.28
                smallItemWidthRatio: 0.12

                delegate: Loader {
                    id: shelfItemLoader
                    property string entryPath: modelData
                    property real fixedWidth
                    property real fixedHeight
                    sourceComponent: /\.(png|jpe?g|webp|bmp|gif)$/i.test(shelfItemLoader.entryPath)
                        ? imageDelegate
                        : fileDelegate

                    Component {
                        id: imageDelegate
                        Item {
                            anchors.fill: parent
                            StyledImage {
                                id: shelfImg
                                anchors.fill: parent
                                source: "file://" + shelfItemLoader.entryPath
                                fillMode: Image.PreserveAspectCrop
                                cache: true
                                asynchronous: true

                                Drag.active: dragArea.drag.active
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/uri-list": "file://" + shelfItemLoader.entryPath }
                                Drag.supportedActions: Qt.CopyAction

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: parent
                                    cursorShape: Qt.OpenHandCursor
                                    onPressed: parent.grabToImage(() => {})
                                    onReleased: {
                                        if (parent.Drag.active) {
                                            parent.Drag.drop()
                                        }
                                        parent.x = 0
                                        parent.y = 0
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: fileDelegate
                        Item {
                            anchors.fill: parent
                            Rectangle {
                                id: fileBg
                                anchors.fill: parent
                                color: Appearance.colors.colSurfaceContainerHighest

                                Drag.active: fileDragArea.drag.active
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/uri-list": "file://" + shelfItemLoader.entryPath }
                                Drag.supportedActions: Qt.CopyAction

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: shelfItemLoader.entryPath.endsWith("/") ? "folder" : "draft"
                                        iconSize: 32
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: 90
                                        elide: Text.ElideMiddle
                                        text: shelfItemLoader.entryPath.split("/").pop()
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer1
                                    }
                                }

                                MouseArea {
                                    id: fileDragArea
                                    anchors.fill: parent
                                    drag.target: parent
                                    cursorShape: Qt.OpenHandCursor
                                    onReleased: {
                                        if (parent.Drag.active) {
                                            parent.Drag.drop()
                                        }
                                        parent.x = 0
                                        parent.y = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("%1 elements").arg(DropShelf.items.length)
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: DropShelf.copyAll()
                    contentItem: RowLayout {
                        anchors.fill: parent
                        spacing: 6
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Translation.tr("Copy")
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    implicitHeight: 40
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: DropShelf.clear()
                    contentItem: RowLayout {
                        anchors.fill: parent
                        spacing: 6
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Translation.tr("Clear")
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
                RippleButton {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    implicitHeight: 40
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: DropShelf.hide()
                    contentItem: RowLayout {
                        anchors.fill: parent
                        spacing: 6
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Translation.tr("Close")
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }
    }
}