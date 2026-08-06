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

            Image {
                id: sourceImage
                anchors.fill: parent
                source: backdrop.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: false
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
