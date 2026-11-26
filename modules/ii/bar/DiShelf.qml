import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: shelf
    required property Item di
    anchors.fill: parent

    readonly property var items: DropShelf.items
    readonly property var preview: shelf.items.slice(-3)
    readonly property string latest: shelf.items.length > 0 ? shelf.items[shelf.items.length - 1] : ""

    Drag.active: dragArea.drag.active && shelf.items.length > 0

    Binding {
        target: shelf.di
        property: "dragging"
        value: true
        when: dragArea.drag.active
        restoreMode: Binding.RestoreValue
    }
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": shelf.items.map(p => `file://${p}`).join("\r\n") })

    Item {
        id: stack
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        readonly property real spread: shelf.di.hoverRevealed ? 13 : 7
        readonly property real fan: shelf.di.hoverRevealed ? 15 : 9
        width: 22 + Math.max(0, shelf.preview.length - 1) * stack.spread
        height: 24

        Behavior on width {
            NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: shelf.items.length === 0
            text: "inbox"
            iconSize: 18
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
        }

        Repeater {
            model: shelf.preview
            delegate: Rectangle {
                required property string modelData
                required property int index
                x: index * stack.spread
                width: 22
                height: 24
                radius: 5
                rotation: (index - (shelf.preview.length - 1) / 2) * stack.fan

                Behavior on x {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                }
                Behavior on rotation {
                    NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colLayer0
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: DropShelf.isImage(modelData)
                    source: visible ? `file://${modelData}` : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 48
                    sourceSize.height: 48
                    asynchronous: true
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !DropShelf.isImage(modelData)
                    text: DropShelf.iconFor(modelData)
                    iconSize: 14
                    fill: 1
                    color: Appearance.colors.colPrimary
                }

                NumberAnimation on scale {
                    from: 0.3
                    to: 1
                    duration: IslandMotion.long
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    RowLayout {
        anchors {
            left: stack.right
            leftMargin: 9
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: shelf.items.length === 0 ? Translation.tr("Empty drawer")
                : shelf.di.hoverRevealed ? DropShelf.fileName(shelf.latest) : Translation.tr("Drawer")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideMiddle
        }

        Rectangle {
            visible: shelf.items.length > 0
            implicitWidth: Math.max(18, countText.implicitWidth + 8)
            implicitHeight: 18
            radius: 9
            color: Appearance.colors.colPrimary

            StyledText {
                id: countText
                anchors.centerIn: parent
                text: shelf.items.length
                font.features: { "tnum": 1 }
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                color: Appearance.colors.colOnPrimary
            }
        }
    }

    Item { id: dragProxy }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: dragProxy
        onReleased: {
            dragProxy.x = 0
            dragProxy.y = 0
        }
        onClicked: shelf.di.toggleExpanded()
    }
}
