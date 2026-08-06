import QtQuick
import Quickshell.Hyprland
import qs.services

Loader {
    id: root

    property string name: ""
    property string description: ""
    signal pressed()
    signal released()

    active: WM.compositor === "hyprland"

    sourceComponent: GlobalShortcut {
        name: root.name
        description: root.description
        onPressed: root.pressed()
        onReleased: root.released()
    }
}
