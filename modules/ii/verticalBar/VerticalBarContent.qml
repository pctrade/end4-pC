import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

Item {
    id: root
    implicitWidth: Appearance.sizes.verticalBarWidth
    height: parent.height

    readonly property real barPadding: 0

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + formattedName + ".qml");
    }

    property var screen: root.QsWindow.window?.screen

    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        color: Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            height: middleCol.implicitHeight
            width: parent.width

            ColumnLayout {
                id: middleCol
                anchors.fill: parent
                spacing: 2
                Repeater {
                    model: Config.options.bar.layouts.middleLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.middleLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                        }
                    }
                }
            }
        }

        // Top 
        Item {
            anchors.top: parent.top
            anchors.topMargin: Config.options.bar.cornerStyle === 1 ? 4 : 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: topCol.implicitHeight

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                spacing: 2
                Repeater {
                    model: Config.options.bar.layouts.leftLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.leftLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                        }
                    }
                }
            }
        }

        // Bottom
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Config.options.bar.cornerStyle === 1 ? 4 : 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: bottomCol.implicitHeight

            ColumnLayout {
                id: bottomCol
                anchors.fill: parent
                spacing: 2
                Repeater {
                    model: Config.options.bar.layouts.rightLayout.slice().reverse()
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.rightLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                        }
                    }
                }
            }
        }
    }
}