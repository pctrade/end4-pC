import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string label
    required property string iconText
    required property var iconShape
    required property real value
    required property string sublabel
    property color sublabelColor: Appearance.colors.colOnLayer1
    property int cardWidth: 170

    width: cardWidth
    height: 72
    radius: Appearance.rounding.normal
    color: Appearance.colors.colSurfaceContainerHigh

    function usageColor(v) {
        if (v > 0.9) return Appearance.colors.colError
        if (v > 0.6) return Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    Row {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        MaterialShapeWrappedMaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            shape: root.iconShape
            text: root.iconText
            iconSize: Appearance.font.pixelSize.large
            implicitSize: 32
            color: Qt.alpha(root.usageColor(root.value), 0.2)
            colSymbol: root.usageColor(root.value)
        }

        Column {
            width: parent.width - 32 - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            RowLayout {
                width: parent.width
                StyledText {
                    text: root.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                StyledText {
                    text: `${Math.round(root.value * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    color: root.usageColor(root.value)
                }
            }

            StyledProgressBar {
                width: parent.width
                value: root.value
                highlightColor: root.usageColor(root.value)
                valueBarHeight: 6
            }

            StyledText {
                text: root.sublabel
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.sublabelColor
                font.features: { "tnum": 1 }
            }
        }
    }
}