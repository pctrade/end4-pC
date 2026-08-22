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
            const fullPathWhenSourceIsIconName = iconFolder + "/" + root.source;
            if (iconFolder && fullPathWhenSourceIsIconName) {
                return fullPathWhenSourceIsIconName
            }
            return root.source
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
