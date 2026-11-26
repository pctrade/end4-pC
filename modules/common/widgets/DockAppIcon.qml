import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    property string iconSource: ""
    property int windowCount: 0
    property bool active: false
    property real iconSize: DockStyle.iconSize
    property bool monochrome: Config.options.dock.monochromeIcons

    Loader {
        id: iconImageLoader
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        sourceComponent: IconImage {
            source: root.iconSource
            implicitSize: root.iconSize
        }
    }

    Loader {
        active: root.monochrome
        anchors.fill: iconImageLoader
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false
                anchors.fill: parent
                source: iconImageLoader
                desaturation: 0.8
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
            }
        }
    }

    GridLayout {
        columns: DockStyle.vertical ? 1 : -1
        rowSpacing: DockStyle.dotSpacing
        columnSpacing: DockStyle.dotSpacing
        anchors {
            top: DockStyle.vertical ? undefined : iconImageLoader.bottom
            topMargin: DockStyle.vertical ? 0 : DockStyle.dotsGap
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: !DockStyle.vertical ? 0
                : (root.iconSize / 2 + DockStyle.dotsSideGap + DockStyle.dotHeight / 2) * (DockStyle.position === "left" ? -1 : 1)
            verticalCenter: DockStyle.vertical ? parent.verticalCenter : undefined
        }
        Repeater {
            model: Math.min(root.windowCount, 3)
            delegate: Rectangle {
                readonly property real longSide: root.windowCount <= 3 ? DockStyle.dotWidth : DockStyle.dotHeight
                radius: Appearance.rounding.full
                implicitWidth: DockStyle.vertical ? DockStyle.dotHeight : longSide
                implicitHeight: DockStyle.vertical ? longSide : DockStyle.dotHeight
                color: root.active ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
            }
        }
    }
}
