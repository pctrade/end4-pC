pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "sticker"
    hoverEnabled: true

    property string imagePath: Config.options.background.widgets.sticker.path ?? ""
    property bool dropHover: false
    property real widgetSize: Config.options.background.widgets.sticker.size ?? 200
    property real widgetRotation: Config.options.background.widgets.sticker.rotation ?? 0
    property color outlineColor: Config.options.background.widgets.sticker.outlineColor !== ""
        ? Config.options.background.widgets.sticker.outlineColor
        : "#ffffff"
    property real outlineWidth: Config.options.background.widgets.sticker.outlineWidth ?? 8

    onDoubleClicked: (mouse) => {
        if (mouse.button !== Qt.LeftButton) return
        root.widgetRotation = 0
        Config.options.background.widgets.sticker.rotation = 0
    }

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    Item {
        id: contentItem
        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize
        rotation: root.widgetRotation

        Behavior on implicitWidth {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        StyledImage {
            id: stickerImage
            anchors.fill: parent
            source: root.imagePath !== "" ? root.imagePath : ""
            fillMode: Image.PreserveAspectFit
            cache: false
            antialiasing: true
            sourceSize.width: parent.width * 2
            sourceSize.height: parent.height * 2
            visible: root.imagePath !== "" && status === Image.Ready

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 4
                spread: root.outlineWidth / 24 
                samples: 24
                color: root.outlineColor
                transparentBorder: true
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: contentItem.implicitWidth / 3
            text: root.dropHover ? "download" : "sticker"
            fill: root.dropHover ? 1 : 0
            color: root.dropHover
                ? Appearance.colors.colPrimary
                : Appearance.colors.colOnPrimaryContainer
            visible: root.imagePath === "" || stickerImage.status !== Image.Ready
            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                drag.accept(Qt.CopyAction)
                root.dropHover = true
            }
            onExited: {
                root.dropHover = false
            }
            onDropped: (drop) => {
                if (drop.hasUrls && drop.urls.length > 0) {
                    var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")
                    var ext = cleanPath.split(".").pop().toLowerCase()
                    var accepted = ["png", "svg", "webp", "gif"] 
                    if (accepted.indexOf(ext) !== -1) {
                        Config.options.background.widgets.sticker.path = cleanPath
                    }
                }
                root.dropHover = false
            }
        }

        ResizeHandler {
            anchorItem: stickerImage
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetSize
            resizeMode: "diagonal"
            rotatable: true
            currentRotation: root.widgetRotation
            z: 1
            onResized: (newValue) => {
                root.widgetSize = Math.max(60, newValue)
            }
            onResizeFinished: {
                Config.options.background.widgets.sticker.size = root.widgetSize
            }
            onRotated: (newAngle) => {
                root.widgetRotation = newAngle
            }
            onRotateFinished: {
                Config.options.background.widgets.sticker.rotation = root.widgetRotation
            }
        }
    }
}