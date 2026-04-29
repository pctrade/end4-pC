import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string iconName
    required property double percentage
    property bool vertical: false
    property int warningThreshold: 100
    property bool shown: true
    clip: !vertical
    visible: vertical ? true : width > 0 && height > 0
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth)
    implicitHeight: vertical ? resourceProgress.implicitHeight : Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold

    Component {
        id: outlineStyle
        ClippedOutlineCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: vertical ? 20 : 20
            colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: vertical ? 13 : Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }
    }

    Component {
        id: filledStyle
        ClippedFilledCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: 20
            colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            accountForLightBleeding: !root.warning
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: vertical ? Font.Medium : Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: vertical ? 13 : Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    // Layout vertical — solo círculo centrado
    Loader {
        id: resourceProgress
        visible: root.vertical
        anchors.centerIn: parent
        sourceComponent: Config.options.bar.resources.style === "filled" ? filledStyle : outlineStyle
    }

    // Layout horizontal — círculo + texto + animación
    RowLayout {
        id: resourceRowLayout
        visible: !root.vertical
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors.verticalCenter: parent.verticalCenter

        Loader {
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: Config.options.bar.resources.style === "filled" ? filledStyle : outlineStyle
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullPercentageTextMetrics.width
            implicitHeight: percentageText.implicitHeight
            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: `${Math.round(root.percentage * 100).toString()}`
            }
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: vertical ? root.visible : (resourceRowLayout.x >= 0 && root.width > 0 && root.visible)
    }

    Behavior on implicitWidth {
        enabled: !root.vertical
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}