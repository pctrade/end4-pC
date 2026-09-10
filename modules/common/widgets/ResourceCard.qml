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
    property color sublabelColor: Appearance.colors.colOnSurfaceVariant
    property int cardWidth: 150 

    signal clicked()
    property bool clickable: false

    width: cardWidth
    height: 96 
    radius: 16 
    
    color: root.clickable && cardMouseArea.containsMouse ? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colSurfaceContainerLow

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    function usageColor(v) {
        if (v > 0.9) return Appearance.colors.colError
        if (v > 0.6) return Appearance.colors.colTertiary || Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -4
            spacing: 0

            MaterialShapeWrappedMaterialSymbol {
                shape: root.iconShape
                text: root.iconText
                iconSize: Appearance.font.pixelSize.huge
                implicitSize: 28
                color: "transparent" // I know that you are going to give me color one day =P
                colSymbol: root.usageColor(root.value)
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: `${Math.round(root.value * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.large || 18
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnSurface
                Layout.alignment: Qt.AlignVCenter
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            StyledText {
                text: root.sublabel
                font.pixelSize: Appearance.font.pixelSize.smallest || 10
                color: root.sublabelColor
                font.features: { "tnum": 1 }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true
            value: root.value
            highlightColor: root.usageColor(root.value)
            valueBarHeight: 6 

        }
    }

    border.width: root.value > 0.9 ? 1.5 : 0
    border.color: root.value > 0.9 ? Appearance.colors.colError : "transparent"
}