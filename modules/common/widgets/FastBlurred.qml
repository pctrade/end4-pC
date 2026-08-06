import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property Item target
    property real blurRadius: 32
    property bool blurEnabled: true
    property bool transparentBorder: true

    FastBlur {
        anchors.fill: parent
        visible: root.blurEnabled
        source: root.target
        radius: root.blurRadius
        transparentBorder: root.transparentBorder
    }
}

// someday maybe i will add it Niri