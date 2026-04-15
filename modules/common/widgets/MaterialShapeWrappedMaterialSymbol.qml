import QtQuick
import qs.modules.common
import qs.modules.common.widgets

MaterialShape {
    id: root
    property alias text: symbol.text
    property alias iconSize: symbol.iconSize
    property alias font: symbol.font
    property alias colSymbol: symbol.color
    property real padding: 6
    property var wrappedShape: MaterialShape.Shape.Clover4Leaf

    color: Appearance.colors.colSecondaryContainer
    colSymbol: Appearance.colors.colOnSecondaryContainer
    shape: root.wrappedShape
    implicitSize: Math.max(symbol.implicitWidth, symbol.implicitHeight) + padding * 2

    MaterialSymbol {
        id: symbol
        anchors.centerIn: parent
        color: root.colSymbol
    }
}