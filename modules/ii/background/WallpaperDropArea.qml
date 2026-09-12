import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

DropArea {
    id: root
    keys: ["text/uri-list"]

    property var currentUrls: []

    onEntered: (drag) => {
        drag.accepted = drag.hasUrls
        root.currentUrls = drag.hasUrls ? drag.urls : []
    }

    onExited: {
        root.currentUrls = []
    }

    onDropped: (drop) => {
        if (!drop.hasUrls) {
            drop.accepted = false
            root.currentUrls = []
            return
        }

        if (drop.urls.length === 1) {
            const path = CF.FileUtils.trimFileProtocol(decodeURIComponent(drop.urls[0].toString()))
            const validExt = /\.(png|jpe?g|webp|bmp|gif)$/i.test(path)
            if (validExt) {
                Wallpapers.select(path, Appearance.m3colors.darkmode)
            } else {
                const globalPos = root.mapToGlobal(drop.x, drop.y)
                DropShelf.show(drop.urls, globalPos.x, globalPos.y)
            }
        } else {
            const globalPos = root.mapToGlobal(drop.x, drop.y)
            DropShelf.show(drop.urls, globalPos.x, globalPos.y)
        }
        drop.accept()
        root.currentUrls = []
    }

    Rectangle {
        id: dropOverlay
        anchors.fill: parent
        visible: root.containsDrag
        color: CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

        property bool isSingleImage: root.currentUrls.length === 1
            && /\.(png|jpe?g|webp|bmp|gif)$/i.test(
                CF.FileUtils.trimFileProtocol(root.currentUrls[0].toString())
            )

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: dropOverlay.isSingleImage ? "wallpaper" : "stacks"
                iconSize: 64
                color: Appearance.colors.colOnPrimary
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: dropOverlay.isSingleImage
                    ? Translation.tr("Drop to set as wallpaper")
                    : Translation.tr("Drop to add to shelf")
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnPrimary
            }
        }
    }
}