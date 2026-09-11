import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    
    property bool colorize: false
    property bool smooth: true
    property color color
    property string source: ""
    property string iconFolder: Qt.resolvedUrl(Quickshell.shellPath("assets/icons"))  // The folder to check first
    width: 30
    height: 30
    
    IconImage {
        id: iconImage
        anchors.fill: parent
        source: {
            if (!root.source)
                return ""

            // Allow full URLs / absolute paths to pass through unchanged.
            if (root.source.includes(":/") || root.source.startsWith("/"))
                return root.source

            const name = root.source.endsWith(".svg") ? root.source : `${root.source}.svg`
            if (iconFolder)
                return iconFolder + "/" + name
            return name
        }
        implicitSize: root.height
        backer.smooth: root.smooth
        backer.sourceSize: Qt.size(
            Math.max(1, Math.ceil(root.width * Screen.devicePixelRatio)),
            Math.max(1, Math.ceil(root.height * Screen.devicePixelRatio))
        )
    }

    Loader {
        active: root.colorize
        anchors.fill: iconImage
        sourceComponent: ColorOverlay {
            source: iconImage
            color: root.color
        }
    }
}
