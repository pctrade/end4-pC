import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

Item {
    id: root
    property var barConfig: Config.barForScreen(root.QsWindow.window?.screen?.name)
    implicitWidth: Appearance.sizes.verticalBarWidth
    height: parent.height

    readonly property real barPadding: 0
    readonly property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    readonly property bool isMaterialHug: root.barConfig.cornerStyle === 4
    readonly property bool isSplitHug: root.barConfig.cornerStyle === 6
    readonly property bool hasTabs: root.isMaterialHug || root.isSplitHug
    readonly property bool useTabWrapper: root.isMaterial || root.isSplitHug
    readonly property bool glassTabs: root.hasTabs && Config.options.background.widgets.glass.enable
    readonly property real tabFlare: root.glassTabs ? Appearance.rounding.screenRounding : 0
    readonly property int tabEdge: root.barConfig.bottom ? 3 : 2
    readonly property bool glassHug: root.barConfig.cornerStyle === 0 && Config.options.background.widgets.glass.enable && root.barConfig.showBackground
    readonly property real hugFlare: root.glassHug && !root.centerOnly ? Appearance.rounding.screenRounding : 0
    readonly property real pillFlare: root.glassHug && root.centerOnly ? Appearance.rounding.screenRounding : 0
    readonly property real splitGroupSpacing: root.barConfig.borderless === "transparent" ? -4 : root.barConfig.borderless === "segmented" ? -2 : 2
    readonly property color materialPillBgColor: (root.barConfig.followFrameColor && root.barConfig.frameColor)
        ? Appearance.getColorFromName(root.barConfig.frameColor)
        : Appearance.colors.colUiBackground
    readonly property bool trayHasItems: SystemTray.items.values.length > 0
    readonly property bool isPanel: root.barConfig.cornerStyle === 5

    function filterLayout(layout) {
        if (trayHasItems) return layout
        return layout.filter(name => name !== "sysTray")
    }

    readonly property var effectiveLeftLayout:   filterLayout(root.barConfig.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: filterLayout(root.barConfig.layouts.middleLayout)
    readonly property var effectiveRightLayout:  filterLayout(root.barConfig.layouts.rightLayout)

    readonly property bool centerOnly: !root.useTabWrapper
        && root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0
    readonly property real centerPillY: centerPill.y
    readonly property real centerPillHeight: centerPill.height

    function shouldPaintMaterialPill(name) {
        if (!root.isMaterial) return false;
        const blacklist = ["workspaces", "divisor", "powerButton", "media", "docktoPanel", "leftSidebarButton", "dynamicIsland", "avatar"];
        if (blacklist.includes(name)) {
            return false;
        }
        return true;
    }

    function getMaterialPillColor(name) {
        if (!root.isMaterial) return Appearance.colors.colPrimaryContainer;
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
        WindowGlass {
            anchors.fill: parent
            anchors.leftMargin: root.barConfig.bottom ? -root.hugFlare : 0
            anchors.rightMargin: root.barConfig.bottom ? 0 : -root.hugFlare
            hangLeft: root.hugFlare
            hangRight: root.hugFlare
            edge: root.tabEdge
            glassEnabled: (parent?.fill.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            tint: parent?.fill ?? 'transparent'
        }
        anchors {
            fill: parent
            margins: root.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        property color fill: (!centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle !== 2 && !root.useTabWrapper)
            ? (root.barConfig.followFrameColor
                ? Appearance.getColorFromName(root.barConfig.frameColor)
                : Appearance.colors.colUiBackground)
            : "transparent"
        color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill
        radius: root.barConfig.cornerStyle === 1 ? Appearance.rounding.windowRounding + 6 : 0
        border.width: (!root.centerOnly && root.barConfig.cornerStyle === 1) ? 1 : 0
        border.color: root.barConfig.showBackground ? Appearance.colors.colLayer0Border : "transparent"
    }

    // centerOnly
    Rectangle {
        id: centerPill
        WindowGlass {
            anchors.fill: parent
            anchors.topMargin: -root.pillFlare
            anchors.bottomMargin: -root.pillFlare
            flareLeft: root.pillFlare
            flareRight: root.pillFlare
            edge: root.tabEdge
            glassEnabled: (parent?.fill.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
            topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
            bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
            bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
            tint: parent?.fill ?? 'transparent'
        }
        visible: root.centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle !== 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: middleCol.implicitHeight + 7
        width: parent.width - (root.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        property color fill: root.barConfig.followFrameColor
            ? Appearance.getColorFromName(root.barConfig.frameColor)
            : Appearance.colors.colUiBackground
        color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill
        radius: root.barConfig.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: root.barConfig.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomRightRadius: root.barConfig.cornerStyle === 0 && !root.barConfig.bottom ? Appearance.rounding.screenRounding : radius
        topRightRadius:    root.barConfig.cornerStyle === 0 && !root.barConfig.bottom ? Appearance.rounding.screenRounding : radius
        bottomLeftRadius:  root.barConfig.cornerStyle === 0 && root.barConfig.bottom  ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     root.barConfig.cornerStyle === 0 && root.barConfig.bottom  ? Appearance.rounding.screenRounding : radius
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Top
        Item {
            id: topItem
            anchors.top: parent.top
            anchors.topMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Appearance.sizes.hyprlandGapsOut || 5) : (root.barConfig.cornerStyle === 1 ? 4 : root.barConfig.cornerStyle === 5 ? 4 : 10))
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.useTabWrapper
                ? (root.effectiveLeftLayout.length > 0 ? (topMaterialPill.height + (root.hasTabs ? topBottomOutwardCorner.implicitSize : 0)) : 0)
                : topCol.implicitHeight

            // Material pill wrapper
            Rectangle {
                id: topMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.bottomMargin: -root.tabFlare
                    anchors.leftMargin: root.barConfig.bottom ? -root.tabFlare : 0
                    anchors.rightMargin: root.barConfig.bottom ? 0 : -root.tabFlare
                    flareRight: root.tabFlare
                    hangLeft: root.tabFlare
                    edge: root.tabEdge
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveLeftLayout.length > 0
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.effectiveLeftLayout.length > 0
                    ? (root.hasTabs ? (topMaterialCol.implicitHeight + 16) : (topMaterialCol.implicitHeight + 10))
                    : 0
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                topLeftRadius: root.hasTabs ? 0 : radius
                topRightRadius: root.hasTabs ? 0 : radius
                bottomLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                ColumnLayout {
                    id: topMaterialCol
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveLeftLayout
                        delegate: topMaterialGroupDelegate
                    }

                    Component {
                        id: topMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            widgetName: modelData
                            totalCount: root.effectiveLeftLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveLeftLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            RoundCorner {
                id: topBottomOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveLeftLayout.length > 0
                anchors.top: topMaterialPill.bottom
                anchors.left: !root.barConfig.bottom ? parent.left : undefined
                anchors.right: root.barConfig.bottom ? parent.right : undefined
                implicitSize: Appearance.rounding.screenRounding
                width: implicitSize
                height: implicitSize
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.TopRight
            }

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                visible: !root.useTabWrapper
                spacing: root.barConfig.borderless === "transparent" ? -4
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -2
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveLeftLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        widgetName: modelData
                        totalCount: root.effectiveLeftLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveLeftLayout, index)
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
            height: root.useTabWrapper
                ? (root.effectiveMiddleLayout.length > 0 ? (centerMaterialPill.height + (root.hasTabs ? (centerTopOutwardCorner.implicitSize + centerBottomOutwardCorner.implicitSize) : 0)) : 0)
                : middleCol.implicitHeight

            RoundCorner {
                id: centerTopOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveMiddleLayout.length > 0
                anchors.bottom: centerMaterialPill.top
                anchors.left: !root.barConfig.bottom ? parent.left : undefined
                anchors.right: root.barConfig.bottom ? parent.right : undefined
                implicitSize: Appearance.rounding.screenRounding
                width: implicitSize
                height: implicitSize
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.topMargin: -root.tabFlare
                    anchors.bottomMargin: -root.tabFlare
                    flareLeft: root.tabFlare
                    flareRight: root.tabFlare
                    edge: root.tabEdge
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveMiddleLayout.length > 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.effectiveMiddleLayout.length > 0
                    ? (root.hasTabs ? (centerMaterialCol.implicitHeight + 16) : (centerMaterialCol.implicitHeight + 10))
                    : 0
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                topLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                topRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                ColumnLayout {
                    id: centerMaterialCol
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveMiddleLayout
                        delegate: centerMaterialGroupDelegate
                    }

                    Component {
                        id: centerMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            widgetName: modelData
                            paintBackground: modelData !== "dynamicIsland"
                            totalCount: root.effectiveMiddleLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            RoundCorner {
                id: centerBottomOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveMiddleLayout.length > 0
                anchors.top: centerMaterialPill.bottom
                anchors.left: !root.barConfig.bottom ? parent.left : undefined
                anchors.right: root.barConfig.bottom ? parent.right : undefined
                implicitSize: Appearance.rounding.screenRounding
                width: implicitSize
                height: implicitSize
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.TopRight
            }

            ColumnLayout {
                id: middleCol
                anchors.fill: parent
                visible: !root.useTabWrapper
                spacing: root.barConfig.borderless === "transparent" ? -4
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -2
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveMiddleLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        widgetName: modelData
                        paintBackground: modelData !== "dynamicIsland"
                        totalCount: root.effectiveMiddleLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, index)
                            }
                        }
                    }
                }
            }
        }

        // Bottom
        Item {
            id: bottomItem
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Appearance.sizes.hyprlandGapsOut || 5) : (root.barConfig.cornerStyle === 1 ? 4 : root.barConfig.cornerStyle === 5 ? 4 : 10))
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.useTabWrapper
                ? (root.effectiveRightLayout.length > 0 ? (bottomMaterialPill.height + (root.hasTabs ? bottomTopOutwardCorner.implicitSize : 0)) : 0)
                : bottomCol.implicitHeight

            RoundCorner {
                id: bottomTopOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveRightLayout.length > 0
                anchors.bottom: bottomMaterialPill.top
                anchors.left: !root.barConfig.bottom ? parent.left : undefined
                anchors.right: root.barConfig.bottom ? parent.right : undefined
                implicitSize: Appearance.rounding.screenRounding
                width: implicitSize
                height: implicitSize
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: bottomMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.topMargin: -root.tabFlare
                    anchors.leftMargin: root.barConfig.bottom ? -root.tabFlare : 0
                    anchors.rightMargin: root.barConfig.bottom ? 0 : -root.tabFlare
                    flareLeft: root.tabFlare
                    hangRight: root.tabFlare
                    edge: root.tabEdge
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveRightLayout.length > 0
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.effectiveRightLayout.length > 0
                    ? (root.hasTabs ? (bottomMaterialCol.implicitHeight + 16) : (bottomMaterialCol.implicitHeight + 10))
                    : 0
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                bottomLeftRadius: root.hasTabs ? 0 : radius
                bottomRightRadius: root.hasTabs ? 0 : radius
                topLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                topRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                ColumnLayout {
                    id: bottomMaterialCol
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveRightLayout
                        delegate: bottomMaterialGroupDelegate
                    }

                    Component {
                        id: bottomMaterialGroupDelegate
                        Bar.BarGroup {
                            Layout.fillWidth: true
                            vertical: true
                            currentIndex: index
                            widgetName: modelData
                            totalCount: root.effectiveRightLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillWidth: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item && "vertical" in item) item.vertical = true
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: bottomCol
                anchors.fill: parent
                visible: !root.useTabWrapper
                spacing: root.barConfig.borderless === "transparent" ? -4
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -2
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveRightLayout
                    delegate: Bar.BarGroup {
                        Layout.fillWidth: true
                        vertical: true
                        currentIndex: index
                        widgetName: modelData
                        totalCount: root.effectiveRightLayout.length
                        Loader {
                            Layout.fillWidth: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item && "vertical" in item) item.vertical = true
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                            }
                        }
                    }
                }
            }
        }
    }
}
