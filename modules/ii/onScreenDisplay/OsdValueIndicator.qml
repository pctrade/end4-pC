import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false
    property alias from: valueProgressBar.from
    property alias to: valueProgressBar.to

    implicitWidth: Appearance.sizes.osdWidth + 4 * Appearance.sizes.elevationMargin + 80
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer0
        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout { 
            id: valueRow
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            Rectangle {
                id: iconBg
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                width: 40
                radius: height / 2
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    id: iconSymbol
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnSecondaryContainer
                    renderType: Text.QtRendering
                    text: root.icon
                    iconSize: 25
                    rotation: 180 * (root.rotateIcon ? value : 0)

                    Behavior on iconSize {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                }
            }

            StyledSlider {
                id: valueProgressBar
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                configuration: StyledSlider.Configuration.M
                stopIndicatorValues: []
                value: root.value
            }

            Rectangle {
                id: valueTextBg
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                width: 46
                radius: height / 2
                color: Appearance.colors.colTertiaryContainer

                StyledText { 
                    id: valueText
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnTertiaryContainer
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.features: { "tnum": 1 }
                    font.letterSpacing: 0.2
                    text: Math.round(root.value * 100)
                }
            }
        }
    }
}