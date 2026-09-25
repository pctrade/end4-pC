import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

// A brand mark from assets/island/apps, painted in one color (the app's accent)
Item {
    id: brand
    property string source: ""
    property real size: 14
    property color color: Appearance.colors.colOnLayer0
    implicitWidth: brand.size
    implicitHeight: brand.size
    visible: brand.source !== ""

    Image {
        id: brandImage
        anchors.fill: parent
        source: brand.source
        sourceSize.width: brand.size * 2
        sourceSize.height: brand.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: brandImage
        color: brand.color
    }
}
