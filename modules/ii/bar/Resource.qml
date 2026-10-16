import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    required property string iconName
    property string label: ""
    required property double percentage
    property bool vertical: false
    property int warningThreshold: 100
    property bool shown: true
    clip: !vertical
    visible: vertical ? true : width > 0 && height > 0
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth)
    implicitHeight: vertical ? resourceProgress.implicitHeight : Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold
    readonly property real usage: Math.max(0, Math.min(1, percentage))
    property color usageColor: {
        if (root.warning) return Appearance.colors.colError
        if (root.contentColorOverridden) return root.contentColor
        const blend = Math.max(0, Math.min(1, (root.usage - 0.5) / 0.3))
        return ColorUtils.mix(Appearance.colors.colTertiary, Appearance.colors.colPrimary, blend)
    }
    readonly property Component styleComponent: {
        switch (Config.options.bar.resources.style) {
        case "filled": return filledStyle
        case "text": return textStyle
        default: return outlineStyle
        }
    }

    Behavior on usageColor {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    Component {
        id: outlineStyle
        ClippedOutlineCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: vertical ? 20 : 20
            colPrimary: root.warning ? Appearance.colors.colError : root.contentColor
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
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.contentColor
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
            colPrimary: root.warning ? Appearance.colors.colError : root.contentColor
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
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.contentColor
                }
            }
        }
    }

    Component {
        id: textStyle
        ColumnLayout {
            spacing: 1

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.label !== "" ? root.label : root.iconName.slice(0, 3).toUpperCase()
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: root.contentColor
            }

            StyledProgressBar {
                Layout.alignment: Qt.AlignHCenter
                valueBarWidth: root.vertical ? 24 : 30
                valueBarHeight: 4
                value: root.usage
                highlightColor: root.usageColor
                trackColor: ColorUtils.transparentize(root.contentColor, 0.8)
            }
        }
    }

    // Vertical
    Loader {
        id: resourceProgress
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.styleComponent
    }

    // Horizontal
    RowLayout {
        id: resourceRowLayout
        visible: !root.vertical
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors.verticalCenter: parent.verticalCenter

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: !root.vertical
            visible: active
            sourceComponent: root.styleComponent
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.options.bar.resources.showValue
            implicitWidth: visible ? fullPercentageTextMetrics.width : 0
            implicitHeight: percentageText.implicitHeight
            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: root.contentColorOverridden ? root.contentColor : Appearance.colors.colOnLayer1
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
        enabled: false
    }
}
