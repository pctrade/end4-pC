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
    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 20 // An icon is circle ish, a column isn't, hence the extra padding

    implicitWidth: Appearance.sizes.osdWidth + 4 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: "transparent"
        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout { 
            id: valueRow
            Layout.margins: Appearance.spacing.normal
            anchors.fill: parent
            spacing: Appearance.spacing.normal

            StyledSlider {
                id: valueProgressBar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: root.valueIndicatorRightPadding
                Layout.leftMargin: root.valueIndicatorLeftPadding
                configuration: StyledSlider.Configuration.M
                stopIndicatorValues: []
                value: root.value

               MaterialSymbol {
                    property bool handlePassed: valueProgressBar.value >= 0.15
                    anchors {
                        verticalCenter: valueProgressBar.verticalCenter
                        left: handlePassed ? valueProgressBar.left : valueProgressBar.handle.left
                        leftMargin: Appearance.spacing.small
                    }
                    color: handlePassed ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
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
                    Behavior on anchors.leftMargin {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                StyledText { 
                    id: valueText
                    property bool nearFull: valueProgressBar.value >= 0.85
                    anchors {
                        verticalCenter: valueProgressBar.verticalCenter
                        right: nearFull ? valueProgressBar.handle.right : valueProgressBar.right
                        rightMargin: nearFull ? 14 : 10
                    }
                    color: nearFull ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.features: { "tnum": 1 }
                    font.letterSpacing: 0.2
                    text: Math.round(root.value * 100)

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                    Behavior on anchors.rightMargin {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
