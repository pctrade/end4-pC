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
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property bool centerOnly: !root.isMaterial
        && Config.options.bar.layouts.leftLayout.length === 0
        && Config.options.bar.layouts.rightLayout.length === 0
    readonly property real centerPillY: centerPill.y
    readonly property real centerPillHeight: centerPill.height

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("../bar/" + formattedName + ".qml");
    }

    function getMirroredForIndex(layout, idx) {
        const prevCount = layout.slice(0, idx).filter(w => w === "visualizer").length
        return prevCount % 2 === 1
    }

    property var screen: root.QsWindow.window?.screen

    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        color: (Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 && !root.isMaterial && !root.centerOnly)
            ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!root.centerOnly && Config.options.bar.cornerStyle === 1) ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    // centerOnly
    Rectangle {
        id: centerPill
        visible: root.centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: middleCol.implicitHeight + 10
        width: parent.width - (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        color: Appearance.colors.colLayer0
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomRightRadius: Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomLeftRadius:  Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Top
        Item {
            anchors.top: parent.top
            anchors.topMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isMaterial ? topMaterialPill.implicitHeight : topCol.implicitHeight

            Rectangle {
                id: topMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: topMaterialCol.implicitWidth
                implicitHeight: topMaterialCol.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                ColumnLayout {
                    id: topMaterialCol
                    anchors.centerIn: parent
                    spacing: -6

                    Repeater {
                        model: Config.options.bar.layouts.leftLayout
                        delegate: topMaterialGroupDelegate
                    }

                    Component {
                        id: topMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            totalCount: Config.options.bar.layouts.leftLayout.length
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.leftLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                visible: !root.isMaterial
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
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.leftLayout, index)
                            }
                        }
                    }
                }
            }
        }

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            width: parent.width
            height: root.isMaterial ? centerMaterialPill.implicitHeight : middleCol.implicitHeight

            Rectangle {
                id: centerMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: centerMaterialCol.implicitWidth
                implicitHeight: centerMaterialCol.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                ColumnLayout {
                    id: centerMaterialCol
                    anchors.centerIn: parent
                    spacing: -6

                    Repeater {
                        model: Config.options.bar.layouts.middleLayout
                        delegate: centerMaterialGroupDelegate
                    }

                    Component {
                        id: centerMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            totalCount: Config.options.bar.layouts.middleLayout.length
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.middleLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: middleCol
                anchors.fill: parent
                visible: !root.isMaterial
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
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.middleLayout, index)
                            }
                        }
                    }
                }
            }
        }

        // Bottom
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isMaterial ? bottomMaterialPill.implicitHeight : bottomCol.implicitHeight

            Rectangle {
                id: bottomMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: bottomMaterialCol.implicitWidth
                implicitHeight: bottomMaterialCol.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                ColumnLayout {
                    id: bottomMaterialCol
                    anchors.centerIn: parent
                    spacing: -6

                    Repeater {
                        model: Config.options.bar.layouts.rightLayout
                        delegate: bottomMaterialGroupDelegate
                    }

                    Component {
                        id: bottomMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            totalCount: Config.options.bar.layouts.rightLayout.length
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.rightLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: bottomCol
                anchors.fill: parent
                visible: !root.isMaterial
                spacing: 2

                Repeater {
                    model: Config.options.bar.layouts.rightLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        totalCount: Config.options.bar.layouts.rightLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(Config.options.bar.layouts.rightLayout, index)
                            }
                        }
                    }
                }
            }
        }
    }
}
