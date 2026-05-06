import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    implicitHeight: Appearance.sizes.barHeight
    width: parent.width
    readonly property real barPadding: 0
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + formattedName + ".qml");
    }

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0

    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        color: Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 && !root.isMaterial ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Left
        Item {
            anchors.left: parent.left
            anchors.leftMargin: Config.options.bar.cornerStyle === 1 ? 4 : 10
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: leftRow.implicitWidth

            RowLayout {
                id: leftRow
                anchors.fill: parent
                spacing: root.isMaterial ? 4 : 2

                Repeater {
                    model: Config.options.bar.layouts.leftLayout
                    delegate: root.isMaterial ? leftNoGroupDelegate : leftBarGroupDelegate
                }

                Component {
                    id: leftBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.leftLayout.length
                        Loader { Layout.fillHeight: true; source: root.getWidgetUrl(modelData) }
                    }
                }
                Component {
                    id: leftNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        Layout.alignment: Qt.AlignVCenter
                        source: root.getWidgetUrl(modelData)
                    }
                }
            }
        }

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            width: middleRow.implicitWidth
            height: parent.height

            RowLayout {
                id: middleRow
                anchors.fill: parent
                spacing: root.isMaterial ? 4 : 2

                Repeater {
                    model: Config.options.bar.layouts.middleLayout
                    delegate: root.isMaterial ? middleNoGroupDelegate : middleBarGroupDelegate
                }

                Component {
                    id: middleBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.middleLayout.length
                        Loader { Layout.fillHeight: true; source: root.getWidgetUrl(modelData) }
                    }
                }
                Component {
                    id: middleNoGroupDelegate
                    Loader { 
                        Layout.fillHeight: false;
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData) 
                    }
                }
            }
        }

        // Right
        Item {
            anchors.right: parent.right
            anchors.rightMargin: Config.options.bar.cornerStyle === 1 ? 4 : 10
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: rightRow.implicitWidth

            RowLayout {
                id: rightRow
                anchors.fill: parent
                spacing: root.isMaterial ? 4 : 2

                Repeater {
                    model: Config.options.bar.layouts.rightLayout
                    delegate: root.isMaterial ? rightNoGroupDelegate : rightBarGroupDelegate
                }

                Component {
                    id: rightBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.rightLayout.length
                        Loader { Layout.fillHeight: true; source: root.getWidgetUrl(modelData) }
                    }
                }
                Component {
                    id: rightNoGroupDelegate
                    Loader { 
                        Layout.fillHeight: false;
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData) 
                    }
                }
            }
        }
    }
}