import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xshelf
    required property Item di
    spacing: 10
    implicitWidth: 410
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 410

    readonly property var pdfs: DropShelf.items.filter(p => DropShelf.isPdf(p))

    // Newest first, split by kind
    readonly property var groups: {
        const defs = [
            ["image", Translation.tr("Images"), p => DropShelf.isImage(p)],
            ["pdf", "PDF", p => DropShelf.isPdf(p)],
            ["video", Translation.tr("Videos"), p => /\.(mp4|mkv|webm|mov|avi)$/i.test(p)],
            ["audio", Translation.tr("Audio"), p => /\.(mp3|flac|ogg|wav|m4a|opus)$/i.test(p)],
            ["other", Translation.tr("Others"), p => true]
        ]
        const items = [...DropShelf.items].reverse()
        const used = new Set()
        const out = []
        for (const [key, label, test] of defs) {
            const list = items.filter(p => !used.has(p) && test(p))
            list.forEach(p => used.add(p))
            if (list.length > 0) out.push({ key: key, label: label, items: list })
        }
        return out
    }

    component HeaderButton: Rectangle {
        id: headerButton
        property string icon
        property string label
        property var onTap
        implicitWidth: headerRow.implicitWidth + 18
        implicitHeight: 28
        radius: 14
        color: headerMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        RowLayout {
            id: headerRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                text: headerButton.icon
                iconSize: 15
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: headerButton.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerButton.onTap()
        }
    }

    component Tile: Rectangle {
        id: tile
        required property string path
        required property Item di
        property int order: 0
        // Dealt out of the drawer: each file drops in from above with a slight tilt that straightens as it
        // lands, one after another. Hovering lifts it a little, like picking a sheet off the pile.
        property real enterT: 0
        readonly property real tilt: (tile.order % 2 === 0 ? -1 : 1) * (5 + (tile.order % 3) * 2)
        width: 90
        height: 104
        radius: 12
        color: tileMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        opacity: tile.enterT
        scale: (tileMouse.drag.active ? 0.94 : 1) * (0.72 + 0.28 * tile.enterT)
        rotation: (1 - tile.enterT) * tile.tilt
        transform: Translate { y: (1 - tile.enterT) * -30 - (tileMouse.containsMouse && !tileMouse.drag.active ? 3 : 0) }

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }
        Behavior on scale {
            enabled: tile.enterT >= 1
            NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack }
        }

        SequentialAnimation {
            running: true
            PauseAnimation { duration: 40 + Math.min(tile.order, 12) * 38 }
            NumberAnimation { target: tile; property: "enterT"; to: 1; duration: IslandMotion.long; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        Drag.active: tileMouse.drag.active

        Binding {
            target: tile.di
            property: "dragging"
            value: true
            when: tileMouse.drag.active
            restoreMode: Binding.RestoreValue
        }
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": `file://${tile.path}` })

        Rectangle {
            id: thumb
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 74
            height: 58
            radius: 8
            color: Appearance.colors.colLayer3
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: thumb.width
                    height: thumb.height
                    radius: thumb.radius
                }
            }

            Image {
                anchors.fill: parent
                visible: DropShelf.isImage(tile.path)
                source: visible ? `file://${tile.path}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 160
                asynchronous: true
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !DropShelf.isImage(tile.path)
                text: DropShelf.iconFor(tile.path)
                iconSize: 30
                fill: 1
                color: Appearance.colors.colPrimary
            }

            // Days until it leaves the drawer, only when it's close
            Rectangle {
                readonly property int days: DropShelf.daysLeft(tile.path)
                visible: days >= 0 && days <= 2
                anchors {
                    left: parent.left
                    top: parent.top
                    margins: 4
                }
                width: expiryText.implicitWidth + 8
                height: 16
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.6)
                StyledText {
                    id: expiryText
                    anchors.centerIn: parent
                    text: `${parent.days}d`
                    font.pixelSize: 9
                    color: "white"
                }
            }
        }

        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                top: thumb.bottom
                topMargin: 6
                leftMargin: 6
                rightMargin: 6
            }
            horizontalAlignment: Text.AlignHCenter
            text: DropShelf.fileName(tile.path)
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideMiddle
        }

        Item { id: tileDragProxy }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: tileDragProxy
            onReleased: {
                tileDragProxy.x = 0
                tileDragProxy.y = 0
            }
            onDoubleClicked: Qt.openUrlExternally(`file://${tile.path}`)
        }

        Row {
            anchors {
                horizontalCenter: thumb.horizontalCenter
                bottom: thumb.bottom
                bottomMargin: 4
            }
            spacing: 4
            opacity: tileMouse.containsMouse || buttonsHover.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.micro }
            }

            HoverHandler {
                id: buttonsHover
            }

            Repeater {
                model: [
                    { icon: "compress", show: DropShelf.isPdf(tile.path), action: () => DropShelf.compressPdf(tile.path) },
                    { icon: "folder_zip", show: !DropShelf.isArchive(tile.path), action: () => DropShelf.zipItems([tile.path]) },
                    { icon: "unarchive", show: DropShelf.isArchive(tile.path), action: () => DropShelf.extract(tile.path) },
                    { icon: "folder_open", show: true, action: () => Quickshell.execDetached(["dolphin", "--select", tile.path]) },
                    { icon: "close", show: true, action: () => DropShelf.remove(tile.path) }
                ].filter(b => b.show)
                delegate: Rectangle {
                    required property var modelData
                    width: 20
                    height: 20
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.6)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: 13
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "inventory_2"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colPrimary
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText {
                text: Translation.tr("Drawer")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: DropShelf.toolStatus !== "" ? DropShelf.toolStatus
                    : `${DropShelf.items.length} ${DropShelf.items.length === 1 ? Translation.tr("file") : Translation.tr("files")}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: DropShelf.toolStatus !== "" ? Appearance.m3colors.m3success : Appearance.colors.colOnLayer0
                opacity: DropShelf.toolStatus !== "" ? 1 : 0.6
                elide: Text.ElideRight
            }
        }
        HeaderButton {
            visible: xshelf.pdfs.length >= 2
            icon: "merge"
            label: Translation.tr("Merge PDFs")
            onTap: () => DropShelf.mergePdfs(xshelf.pdfs)
        }
        HeaderButton {
            visible: DropShelf.items.length >= 2
            icon: "folder_zip"
            label: Translation.tr("Zip all")
            onTap: () => DropShelf.zipItems(DropShelf.items)
        }
        HeaderButton {
            visible: DropShelf.items.length > 0
            icon: "content_copy"
            label: Translation.tr("Copy all")
            onTap: () => DropShelf.copyAll()
        }
        HeaderButton {
            visible: DropShelf.items.length > 0
            icon: "delete_sweep"
            label: Translation.tr("Clear")
            onTap: () => DropShelf.clear()
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: DropShelf.items.length === 0
        text: Translation.tr("Drag files onto the island to keep them here")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
        wrapMode: Text.Wrap
    }

    Repeater {
        model: xshelf.groups

        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                text: `${modelData.label} · ${modelData.items.length}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: modelData.items
                    delegate: Tile {
                        required property string modelData
                        required property int index
                        path: modelData
                        di: xshelf.di
                        order: index
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: DropShelf.items.length > 0 && DropShelf.expireDays > 0
        text: `${Translation.tr("Files leave the drawer after")} ${DropShelf.expireDays} ${Translation.tr("days")}`
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.45
    }
}
