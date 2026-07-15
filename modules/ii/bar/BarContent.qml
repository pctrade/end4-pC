import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
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
    readonly property real centerPillX: centerPill.x
    readonly property real centerPillWidth: centerPill.width

    readonly property bool trayHasItems: SystemTray.items.values.length > 0

    function filterLayout(layout) {
        if (trayHasItems) return layout
        return layout.filter(name => name !== "sysTray")
    }

    readonly property var effectiveLeftLayout:   filterLayout(Config.options.bar.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: filterLayout(Config.options.bar.layouts.middleLayout)
    readonly property var effectiveRightLayout:  filterLayout(Config.options.bar.layouts.rightLayout)

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + formattedName + ".qml");
    }

    function getMirroredForIndex(layout, idx) {
        const prevCount = layout.slice(0, idx).filter(w => w === "visualizer").length
        return prevCount % 2 === 1
    }

    function shouldPaintMaterialPill(name) {
        if (Config.options.bar.cornerStyle !== 3) return false;
        const blacklist = ["workspaces", "divisor", "powerButton", "docktoPanel", "leftSidebarButton", "activeWindow"];
        if (blacklist.includes(name)) {
            return false;
        }
        return true;
    }

    function getMaterialPillColor(name) {
        if (Config.options.bar.cornerStyle !== 3) return Appearance.colors.colPrimaryContainer;
        switch(name) {
            case "media":
            case "sysTray":
                return Appearance.colors.colSecondaryContainer;
            case "resources":
                return Appearance.colors.colTertiaryContainer;
            case "systemIcons":
                return Appearance.colors.colPrimary; 
            default:
                return Appearance.colors.colPrimaryContainer;
        }
    }

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0


    Rectangle {
        id: barBackground
        anchors.fill: parent
        anchors.margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        color: (!centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 && !root.isMaterial) 
            ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && Config.options.bar.cornerStyle === 1) ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    // center-only
    readonly property bool centerOnly: !root.isMaterial
        && root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0

    Rectangle {
        id: centerPill
        visible: centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: middleRow.implicitWidth + 10
        height: parent.height - (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        color: Appearance.colors.colLayer0
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Left
        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.isMaterial ? leftMaterialPill.implicitWidth : leftRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: leftMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: leftMaterialRow.implicitWidth + 10
                implicitHeight: leftMaterialRow.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: leftMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveLeftLayout
                        delegate: leftMaterialGroupDelegate
                    }

                    Component {
                        id: leftMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveLeftLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveLeftLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: leftRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveLeftLayout
                    delegate: leftBarGroupDelegate
                }

                Component {
                    id: leftBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveLeftLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveLeftLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: leftNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        Layout.alignment: Qt.AlignVCenter
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item && item.hasOwnProperty("mirrored"))
                                item.mirrored = root.getMirroredForIndex(root.effectiveLeftLayout, index)
                        }
                    }
                }
            }
        }

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            width: root.isMaterial ? centerMaterialPill.implicitWidth : middleRow.implicitWidth
            height: parent.height

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: centerMaterialRow.implicitWidth + 10
                implicitHeight: centerMaterialRow.implicitHeight 
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: centerMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveMiddleLayout
                        delegate: middleMaterialGroupDelegate
                    }

                    Component {
                        id: middleMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveMiddleLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: middleRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveMiddleLayout
                    delegate: middleBarGroupDelegate
                }

                Component {
                    id: middleBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveMiddleLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: middleNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item && item.hasOwnProperty("mirrored"))
                                item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, index)
                        }
                    }
                }
            }
        }

        // Right
        Item {
            anchors.right: parent.right
            anchors.rightMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.isMaterial ? rightMaterialPill.implicitWidth : rightRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: rightMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: rightMaterialRow.implicitWidth + 10
                implicitHeight: rightMaterialRow.implicitHeight 
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: rightMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveRightLayout
                        delegate: rightMaterialGroupDelegate
                    }

                    Component {
                        id: rightMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveRightLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: rightRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveRightLayout
                    delegate: rightBarGroupDelegate
                }

                Component {
                    id: rightBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveRightLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: rightNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item && item.hasOwnProperty("mirrored"))
                                item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                        }
                    }
                }
            }
        }
    }
}