import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A small bento card: an icon in a cookie, a value and what it is
BentoTile {
    id: root
    property string icon
    property string value
    property string label
    property color colAccent: Appearance.colors.colSecondaryContainer
    property color colOnAccent: Appearance.colors.colOnSecondaryContainer
    // 0 to 1 draws a gauge around the icon, below 0 none
    property real gauge: -1
    // Turns the icon, for a direction
    property real iconRotation: 0
    implicitHeight: 64

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 10
        }
        spacing: 8

        Item {
            implicitWidth: 40
            implicitHeight: 40
            CircularProgress {
                anchors.centerIn: parent
                visible: root.gauge >= 0
                implicitSize: 40
                lineWidth: 3
                value: Math.max(0, root.gauge)
                colPrimary: root.colOnAccent
                colSecondary: root.colAccent
            }
            MaterialShapeWrappedMaterialSymbol {
                anchors.centerIn: parent
                rotation: root.iconRotation
                shape: MaterialShape.Shape.Cookie7Sided
                color: root.colAccent
                colSymbol: root.colOnAccent
                text: root.icon
                fill: 1
                iconSize: root.gauge >= 0 ? 14 : 16
                padding: root.gauge >= 0 ? 6 : 7
                implicitWidth: root.gauge >= 0 ? 28 : 36
                implicitHeight: root.gauge >= 0 ? 28 : 36
                Behavior on rotation {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText {
                Layout.fillWidth: true
                text: root.value
                elide: Text.ElideRight
                color: Appearance.colors.colOnSurface
                font {
                    family: "Google Sans Flex"
                    pixelSize: Appearance.font.pixelSize.large
                    weight: 800
                    variableAxes: ({ "wght": 800 })
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }
}
