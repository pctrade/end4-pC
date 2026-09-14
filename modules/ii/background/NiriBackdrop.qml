pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

Variants {
    id: wallpaperBackdropRoot
    model: Quickshell.screens

    Loader {
        id: loader
        required property var modelData
        active: WM.compositor === "niri"

        sourceComponent: PanelWindow {
            id: backdrop
            screen: loader.modelData

            property string wallpaperPath: Config.options.background.wallpaperPath

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: sourceImage
                anchors.fill: parent
                clip: true
                visible: false
                layer.enabled: true

                readonly property bool wallpaperIsVideo: backdrop.wallpaperPath.endsWith(".mp4")
                    || backdrop.wallpaperPath.endsWith(".webm")
                    || backdrop.wallpaperPath.endsWith(".mkv")
                    || backdrop.wallpaperPath.endsWith(".avi")
                    || backdrop.wallpaperPath.endsWith(".mov")

                Image {
                    source: backdrop.wallpaperPath
                    fillMode: sourceImage.wallpaperIsVideo ? Image.PreserveAspectCrop : Image.Stretch
                    asynchronous: true
                    cache: true
                    smooth: true

                    readonly property real baseScale: {
                        if (sourceImage.wallpaperIsVideo) return 1.0;
                        if (sourceSize.width <= 0 || sourceSize.height <= 0 || sourceImage.width <= 0 || sourceImage.height <= 0) return 1.0;
                        return Math.max(sourceImage.width / sourceSize.width, sourceImage.height / sourceSize.height) * (Config.options.background.wallpaperScale ?? 1.0);
                    }
                    width:  (!sourceImage.wallpaperIsVideo && sourceSize.width  > 0) ? Math.ceil(sourceSize.width  * baseScale) : sourceImage.width
                    height: (!sourceImage.wallpaperIsVideo && sourceSize.height > 0) ? Math.ceil(sourceSize.height * baseScale) : sourceImage.height

                    x: sourceImage.wallpaperIsVideo ? 0 : Math.round((sourceImage.width  - width)  * (Config.options.background.wallpaperOffsetX ?? 0.5))
                    y: sourceImage.wallpaperIsVideo ? 0 : Math.round((sourceImage.height - height) * (Config.options.background.wallpaperOffsetY ?? 0.5))
                }
            }

            FastBlur {
                anchors.fill: parent
                source: sourceImage
                radius: 48 // fixme variable
                transparentBorder: false
            }
        }
    }
}
