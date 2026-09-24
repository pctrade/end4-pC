import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects

// The streaming service's own mark, in its colour: Simple Icons (assets/island/apps, square) for most, and the
// Disney+ wordmark (Wikimedia Commons, public domain — wide, painted white so it reads on the dark pill).
Item {
    id: mark
    property string service: ""
    property real size: 18

    readonly property var brands: ({
        netflix:       { name: "Netflix", color: "#E50914", icon: "netflix" },
        disneyplus:    { name: "Disney+", color: "#FFFFFF", icon: "disneyplus", aspect: 1.84 },
        primevideo:    { name: "Prime Video", color: "#00A8E1", icon: "primevideo" },
        max:           { name: "Max", color: "#4C6BFF", icon: "max" },
        appletv:       { name: "Apple TV", color: "#FFFFFF", icon: "appletv" },
        crunchyroll:   { name: "Crunchyroll", color: "#F47521", icon: "crunchyroll" },
        paramountplus: { name: "Paramount+", color: "#2B7BFF", icon: "paramountplus" }
    })
    readonly property var brand: mark.brands[mark.service] ?? null
    readonly property color color: mark.brand?.color ?? Appearance.colors.colOnLayer0

    readonly property real aspect: mark.brand?.aspect ?? 1
    implicitWidth: mark.size * mark.aspect
    implicitHeight: mark.size
    visible: mark.brand !== null

    Image {
        id: markImage
        anchors.fill: parent
        source: mark.brand ? Quickshell.shellPath(`assets/island/apps/${mark.brand.icon}.svg`) : ""
        sourceSize.width: mark.size * mark.aspect * 2
        sourceSize.height: mark.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: markImage
        color: mark.color
    }
}
