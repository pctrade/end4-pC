import QtQuick
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "imageCard"
    hoverEnabled: true

    property string imagePath: root.configEntry.path ?? ""
    property bool dropHover: false

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real cardHeight: 120
    readonly property real doubleHeight: root.cardHeight * 2 + root.cardSpacing

    readonly property real snapWidth1: root.singleWidth
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2

    readonly property real rowToggleDelta: (root.doubleHeight - root.cardHeight) * 0.3

    property string dragMode: ""
    readonly property string sizeMode: root.dragMode !== "" ? root.dragMode : (root.configEntry.sizeMode ?? "1x2")
    readonly property bool doubleRow: root.sizeMode === "2x2" || root.sizeMode === "2x3"

    readonly property real modeWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x2": return root.snapWidth2
            default:    return root.snapWidth3
        }
    }
    readonly property real modeHeight: root.doubleRow ? root.doubleHeight : root.cardHeight

    property real widgetWidth: root.modeWidth
    property real widgetHeight: root.modeHeight

    readonly property real imageAspect: probe.implicitHeight > 0 ? probe.implicitWidth / probe.implicitHeight : 1
    readonly property bool imageWiderThanCard: root.imageAspect >= root.modeWidth / root.modeHeight

    function modeForDrag(dx, dy, startWidth) {
        var width = startWidth + dx
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        var columns = width < mid1 ? 1 : (width < mid2 ? 2 : 3)
        var double = root.doubleRow
        if (dy > root.rowToggleDelta) double = true
        else if (dy < -root.rowToggleDelta) double = false
        if (double) return columns === 3 ? "2x3" : "2x2"
        return "1x" + columns
    }

    function acceptDrop(drop) {
        if (drop.hasUrls && drop.urls.length > 0) {
            var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")
            var ext = cleanPath.split(".").pop().toLowerCase()
            var accepted = ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif"]
            if (accepted.indexOf(ext) !== -1) root.configEntry.path = cleanPath
        }
        root.dropHover = false
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Image {
        id: probe
        source: root.imagePath
        visible: false
        asynchronous: true
        cache: false
        sourceSize.width: 64
        sourceSize.height: 64
    }

    WidgetCard {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight
        widget: root

        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"

            StyledImage {
                anchors.fill: parent
                source: root.imagePath
                visible: root.imagePath !== ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                smooth: true
                mipmap: true
                sourceSize.width: root.imageWiderThanCard ? 0 : root.modeWidth * 2
                sourceSize.height: root.imageWiderThanCard ? root.modeHeight * 2 : 0
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Math.min(card.implicitWidth, card.implicitHeight) / 3
                text: root.dropHover ? "download" : "image"
                fill: root.dropHover ? 1 : 0
                color: root.dropHover ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                visible: root.imagePath === ""
                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: (drag) => {
                    drag.accept(Qt.CopyAction)
                    root.dropHover = true
                }
                onExited: root.dropHover = false
                onDropped: (drop) => root.acceptDrop(drop)
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.dragMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: {
                root.configEntry.sizeMode = root.sizeMode
                root.dragMode = ""
            }
        }
    }
}
