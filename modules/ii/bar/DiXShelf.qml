import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The drawer: files dropped on the island, in a thumbnail grid with per-tile actions and drag-out.
ColumnLayout {
    id: xshelf
    required property Item di
    spacing: 10
    implicitWidth: xshelf.wantedWidth
    readonly property real wantedWidth: xshelf.empty ? 372 : 532

    readonly property bool empty: DropShelf.items.length === 0
    readonly property var ordered: [...DropShelf.items].reverse()
    readonly property var pdfs: DropShelf.items.filter(p => DropShelf.isPdf(p))
    readonly property int columns: 5
    readonly property int tileHeight: 92
    // 234 of view minus the header row and the spacing
    readonly property real gridMax: 192

    property var info: ({})
    property bool infoReady: false

    readonly property real totalBytes: {
        let sum = 0
        for (const p of DropShelf.items) {
            const i = xshelf.info[p]
            if (i && !i.dir) sum += i.size
        }
        return sum
    }

    readonly property string folder: {
        const dirs = [...new Set(DropShelf.items.map(p => p.substring(0, p.lastIndexOf("/"))))]
        return dirs.length === 1 && dirs[0] !== "" ? dirs[0] : DropShelf.storeDir
    }

    function formatBytes(bytes) {
        if (bytes < 1024) return `${bytes} B`
        const units = ["KB", "MB", "GB", "TB"]
        let v = bytes / 1024
        let u = 0
        while (v >= 1024 && u < units.length - 1) {
            v /= 1024
            u++
        }
        const num = v < 10 ? v.toFixed(1).replace(".", Qt.locale().decimalPoint) : Math.round(v).toString()
        return `${num} ${units[u]}`
    }

    function extension(path) {
        const name = DropShelf.fileName(path)
        const dot = name.lastIndexOf(".")
        return dot > 0 && name.length - dot <= 6 ? name.substring(dot + 1).toUpperCase() : ""
    }

    function refreshInfo() {
        if (DropShelf.items.length === 0) {
            xshelf.info = ({})
            xshelf.infoReady = true
            return
        }
        if (statProc.running) {
            statProc.again = true
            return
        }
        statProc.command = ["stat", "-L", "-c", "%s\t%F\t%n", "--", ...DropShelf.items]
        statProc.running = true
    }

    Component.onCompleted: xshelf.refreshInfo()

    Connections {
        target: DropShelf
        function onItemsChanged() {
            Qt.callLater(xshelf.refreshInfo)
        }
    }

    Process {
        id: statProc
        property bool again: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const line of text.split("\n")) {
                    const a = line.indexOf("\t")
                    const b = a < 0 ? -1 : line.indexOf("\t", a + 1)
                    if (b < 0) continue
                    out[line.substring(b + 1)] = {
                        size: parseInt(line.substring(0, a)) || 0,
                        dir: line.substring(a + 1, b) === "directory"
                    }
                }
                xshelf.info = out
                xshelf.infoReady = true
            }
        }
        onExited: {
            if (statProc.again) {
                statProc.again = false
                Qt.callLater(xshelf.refreshInfo)
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        property string tip
        property bool danger: false
        property var onTap
        implicitWidth: chip.label !== "" ? chipRow.implicitWidth + 24 : 32
        implicitHeight: 32
        radius: 16
        color: chip.danger ? (chipMouse.containsMouse ? Appearance.colors.colErrorContainerHover : Appearance.colors.colErrorContainer)
            : chipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: chip.icon
                iconSize: 16
                fill: 1
                color: chip.danger ? Appearance.m3colors.m3onErrorContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                visible: chip.label !== ""
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: chip.danger ? Appearance.m3colors.m3onErrorContainer : Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.onTap()
        }
        StyledToolTip {
            text: chip.tip
            extraVisibleCondition: false
            alternativeVisibleCondition: chipMouse.containsMouse && chip.tip !== ""
        }
    }

    component TileButton: Rectangle {
        id: tileButton
        property string icon
        property var onTap
        width: 20
        height: 20
        radius: 10
        color: tileButtonMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.8) : Qt.rgba(0, 0, 0, 0.6)

        MaterialSymbol {
            anchors.centerIn: parent
            text: tileButton.icon
            iconSize: 13
            color: "white"
        }

        MouseArea {
            id: tileButtonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileButton.onTap()
        }
    }

    component Tile: Rectangle {
        id: tile
        required property string path
        required property Item di
        property int order: 0
        readonly property var meta: xshelf.info[tile.path]
        readonly property bool missing: xshelf.infoReady && tile.meta === undefined
        readonly property bool isImage: DropShelf.isImage(tile.path)
        readonly property bool hovered: tileHover.hovered && !tileMouse.drag.active
        height: xshelf.tileHeight
        radius: 12
        color: tile.hovered ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        DiCascade { target: tile; index: 1 + Math.min(tile.order, 12); step: 25; pressed: tileMouse.pressed }

        HoverHandler {
            id: tileHover
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
            x: 6
            y: 6
            width: tile.width - 12
            height: 52
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
                id: preview
                anchors.fill: parent
                visible: tile.isImage && preview.status === Image.Ready
                source: tile.isImage ? `file://${tile.path}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 200
                asynchronous: true
                cache: true
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !preview.visible
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: tile.missing ? "link_off" : tile.meta?.dir ? "folder" : DropShelf.iconFor(tile.path)
                    iconSize: 24
                    fill: 1
                    color: tile.missing ? Appearance.colors.colError : Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: text !== "" && !tile.meta?.dir
                    text: xshelf.extension(tile.path)
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                }
            }

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
            id: nameText
            anchors {
                left: parent.left
                right: parent.right
                top: thumb.bottom
                topMargin: 5
                leftMargin: 7
                rightMargin: 7
            }
            horizontalAlignment: Text.AlignHCenter
            text: DropShelf.fileName(tile.path)
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideMiddle
        }

        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                top: nameText.bottom
                topMargin: 1
            }
            horizontalAlignment: Text.AlignHCenter
            text: tile.missing ? Translation.tr("Missing")
                : tile.meta === undefined ? " "
                : tile.meta.dir ? Translation.tr("Folder")
                : xshelf.formatBytes(tile.meta.size)
            font.pixelSize: 9
            font.features: { "tnum": 1 }
            color: tile.missing ? Appearance.colors.colError : Appearance.colors.colOnLayer1
            opacity: tile.missing ? 0.9 : 0.55
        }

        Item { id: tileDragProxy }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: tileDragProxy
            onReleased: {
                tileDragProxy.x = 0
                tileDragProxy.y = 0
            }
            onDoubleClicked: Qt.openUrlExternally(`file://${tile.path}`)
        }

        TileButton {
            anchors {
                right: thumb.right
                top: thumb.top
                margins: 4
            }
            opacity: tile.hovered ? 1 : 0
            visible: opacity > 0
            icon: "close"
            onTap: () => DropShelf.remove(tile.path)
            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.micro }
            }
        }

        Row {
            anchors {
                horizontalCenter: thumb.horizontalCenter
                bottom: thumb.bottom
                bottomMargin: 4
            }
            spacing: 4
            opacity: tile.hovered && !tile.missing ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.micro }
            }

            TileButton {
                icon: "open_in_new"
                onTap: () => Qt.openUrlExternally(`file://${tile.path}`)
            }
            TileButton {
                icon: DropShelf.isPdf(tile.path) ? "compress" : DropShelf.isArchive(tile.path) ? "unarchive" : "folder_zip"
                onTap: () => {
                    if (DropShelf.isPdf(tile.path)) DropShelf.compressPdf(tile.path)
                    else if (DropShelf.isArchive(tile.path)) DropShelf.extract(tile.path)
                    else DropShelf.zipItems([tile.path])
                }
            }
            TileButton {
                icon: "folder_open"
                onTap: () => Quickshell.execDetached(["dolphin", "--select", tile.path])
            }
        }
    }

    RowLayout {
        id: header
        visible: !xshelf.empty
        Layout.fillWidth: true
        spacing: 6

        DiCascade { target: header; index: 0 }

        MaterialSymbol {
            Layout.rightMargin: 2
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
                    : xshelf.empty ? Translation.tr("Empty")
                    : `${DropShelf.items.length} ${DropShelf.items.length === 1 ? Translation.tr("file") : Translation.tr("files")}`
                        + (xshelf.totalBytes > 0 ? ` · ${xshelf.formatBytes(xshelf.totalBytes)}` : "")
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: DropShelf.toolStatus !== "" ? Appearance.m3colors.m3success : Appearance.colors.colOnLayer0
                opacity: DropShelf.toolStatus !== "" ? 1 : 0.6
                elide: Text.ElideRight
            }
        }
        Chip {
            visible: xshelf.pdfs.length >= 2
            icon: "merge"
            tip: Translation.tr("Merge PDFs")
            onTap: () => DropShelf.mergePdfs(xshelf.pdfs)
        }
        Chip {
            visible: DropShelf.items.length >= 2
            icon: "folder_zip"
            tip: Translation.tr("Zip all")
            onTap: () => DropShelf.zipItems(DropShelf.items)
        }
        Chip {
            visible: !xshelf.empty
            icon: "content_copy"
            tip: Translation.tr("Copy all")
            onTap: () => DropShelf.copyAll()
        }
        Chip {
            visible: !xshelf.empty
            icon: "folder_open"
            label: Translation.tr("Open folder")
            onTap: () => Qt.openUrlExternally(`file://${xshelf.folder}`)
        }
        Chip {
            id: clearChip
            property bool armed: false
            visible: !xshelf.empty
            icon: clearChip.armed ? "warning" : "delete_sweep"
            label: clearChip.armed ? Translation.tr("Confirm") : Translation.tr("Clear all")
            danger: clearChip.armed
            onTap: () => {
                if (clearChip.armed) {
                    clearChip.armed = false
                    DropShelf.clear()
                } else {
                    clearChip.armed = true
                    disarm.restart()
                }
            }
            Timer {
                id: disarm
                interval: 2600
                onTriggered: clearChip.armed = false
            }
        }
    }

    ColumnLayout {
        visible: xshelf.empty
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        spacing: 4

        Item {
            id: emptyIcon
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            implicitWidth: 48
            implicitHeight: 48
            DiCascade { target: emptyIcon; index: 0 }
            MaterialShapeWrappedMaterialSymbol {
                anchors.centerIn: parent
                wrappedShape: MaterialShape.Shape.Cookie9Sided
                color: Appearance.colors.colSecondaryContainer
                colSymbol: Appearance.colors.colOnSecondaryContainer
                text: "move_to_inbox"
                iconSize: 22
                padding: 12
            }
        }
        StyledText {
            id: emptyTitle
            // Filling the width lets this column span the view: a column is never wider than its widest child.
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Drawer is empty")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            DiCascade { target: emptyTitle; index: 1 }
        }
        StyledText {
            id: emptyHint
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Translation.tr("Drag files onto the island to keep them here")
                + (DropShelf.expireDays > 0 ? `\n${Translation.tr("they stay for %1 days").arg(DropShelf.expireDays)}` : "")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.55
            DiCascade { target: emptyHint; index: 2 }
        }
    }

    Flickable {
        id: gridFlick
        visible: !xshelf.empty
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(grid.implicitHeight, xshelf.gridMax)
        clip: true
        contentHeight: grid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: gridFlick.contentHeight > gridFlick.height + 1

        readonly property real fade: 18 / Math.max(1, gridFlick.height)
        layer.enabled: gridFlick.interactive
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: gridFlick.width
                height: gridFlick.height
                gradient: Gradient {
                    GradientStop { position: 0; color: gridFlick.atYBeginning ? "black" : "transparent" }
                    GradientStop { position: gridFlick.fade; color: "black" }
                    GradientStop { position: 1 - gridFlick.fade; color: "black" }
                    GradientStop { position: 1; color: gridFlick.atYEnd ? "black" : "transparent" }
                }
            }
        }

        Grid {
            id: grid
            width: gridFlick.width
            columns: xshelf.columns
            spacing: 8

            Repeater {
                model: xshelf.ordered.length
                delegate: Tile {
                    required property int index
                    width: Math.floor((grid.width - (xshelf.columns - 1) * grid.spacing) / xshelf.columns)
                    path: xshelf.ordered[index] ?? ""
                    di: xshelf.di
                    order: index
                }
            }
        }
    }
}
