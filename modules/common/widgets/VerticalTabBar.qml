pragma ComponentBehavior: Bound
import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    function incrementCurrentIndex() { tabBar.incrementCurrentIndex() }
    function decrementCurrentIndex() { tabBar.decrementCurrentIndex() }
    function setCurrentIndex(index)  { tabBar.setCurrentIndex(index) }

    property real cardHeight: 30

    implicitHeight: tabButtonList.length * (cardHeight + 2)

    Repeater {
        model: root.tabButtonList
        delegate: Rectangle {
            required property int index
            required property var modelData
            property bool isCurrent: index === root.currentIndex
            property int totalCount: root.tabButtonList.length

            property int visualPosition: {
                if (isCurrent) return totalCount - 1
                const slots = Array.from({length: totalCount}, (_, i) => i).filter(i => i !== root.currentIndex)
                return slots.indexOf(index)
            }

            width: root.width
            height: 30

            y: visualPosition * (cardHeight + 2)

            z: isCurrent ? 0 : (totalCount - visualPosition)

            topLeftRadius: Appearance.rounding.normal
            topRightRadius: Appearance.rounding.normal
            bottomLeftRadius: isCurrent ? 0 : Appearance.rounding.unsharpenmore
            bottomRightRadius: isCurrent ? 0 : Appearance.rounding.unsharpenmore

            color: isCurrent
                ? Appearance.colors.colLayer1
                : Appearance.colors.colPrimaryContainer

            opacity: isCurrent ? 1 : (0.3 + ((totalCount - 1 - visualPosition) / Math.max(totalCount - 1, 1)) * 0.3)

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: 30
                height: 6
                radius: height / 2
                color: Appearance.colors.colSurfaceContainerHighest
            }
            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 6

                MaterialSymbol {
                    text: parent.parent.modelData.icon
                    iconSize: Appearance.font.pixelSize.larger
                    color: parent.parent.isCurrent
                        ? Appearance.colors.colOnLayer1
                        : Appearance.colors.colOnPrimaryContainer
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                StyledText {
                    text: parent.parent.modelData.name
                    color: parent.parent.isCurrent
                        ? Appearance.colors.colOnLayer1
                        : Appearance.colors.colOnPrimaryContainer
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.setCurrentIndex(parent.index)
            }
        }
    }

    TabBar {
        id: tabBar
        z: -1
        background: null
        Repeater {
            model: root.tabButtonList.length
            delegate: TabButton { background: null }
        }
    }
}