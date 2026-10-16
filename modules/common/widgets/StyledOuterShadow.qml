import QtQuick
import QtQuick.Effects
import qs.modules.common

Item {
    id: root

    required property var target
    property real blurSize: 0.9 * Appearance.sizes.elevationMargin
    property real spreadSize: 1
    property vector2d shadowOffset: Qt.vector2d(0.0, 1.0)
    property color shadowColor: Appearance.colors.colShadow
    readonly property real reach: Math.ceil(root.blurSize + root.spreadSize + Math.abs(root.shadowOffset.x) + Math.abs(root.shadowOffset.y)) + 2

    anchors.fill: parent
    anchors.margins: -root.reach

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cutout
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        RectangularShadow {
            anchors.fill: parent
            anchors.margins: root.reach
            radius: root.target.radius
            blur: root.blurSize
            offset: root.shadowOffset
            spread: root.spreadSize
            color: root.shadowColor
        }
    }

    Item {
        id: cutout
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.reach
            radius: root.target.radius
            color: "white"
        }
    }
}
