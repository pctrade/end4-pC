import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
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
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    readonly property bool isMaterialHug: Config.options.bar.cornerStyle === 4
    readonly property bool isSplitHug: Config.options.bar.cornerStyle === 6
    readonly property bool hasTabs: root.isMaterialHug || root.isSplitHug
    readonly property bool useTabWrapper: root.isMaterial || root.isSplitHug
    readonly property real splitGroupSpacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options.bar.borderless === "segmented" ? -1 : 2
    readonly property color materialPillBgColor: (Config.options.bar.followFrameColor && Config.options.bar.frameColor)
        ? Appearance.getColorFromName(Config.options.bar.frameColor)
        : Appearance.colors.colLayer0
    readonly property real centerPillX: centerPill.x
    readonly property real centerPillWidth: centerPill.width
    readonly property bool isPanel: Config.options.bar.cornerStyle === 5
    readonly property var diLeftWidgets:  filterLayout(Config.options.bar.dynamicIsland.leftWidgets ?? [])
    readonly property var diRightWidgets: filterLayout(Config.options.bar.dynamicIsland.rightWidgets ?? [])

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
        if (!root.isMaterial) return false;
        const blacklist = ["workspaces", "divisor", "powerButton", "docktoPanel", "leftSidebarButton", "activeWindow", "dynamicIsland", "avatar"];
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

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0


    Rectangle {
        id: barBackground
        anchors.fill: parent
        anchors.margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        color: (!centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 && !root.useTabWrapper)
            ? (Config.options.bar.followFrameColor
                ? Appearance.getColorFromName(Config.options.bar.frameColor)
                : Appearance.colors.colLayer0)
            : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && Config.options.bar.cornerStyle === 1) ? 1 : 0
        border.color: Config.options.bar.cornerStyle === 1 && !Config.options.bar.showBackground ? "transparent" : ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.8) 
    }

    // center-only
    readonly property bool centerOnly: root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0

    Binding {
        target: GlobalStates
        property: "barCenterOnly"
        value: root.centerOnly
        restoreMode: Binding.RestoreBinding
    }

    RoundCorner {
        id: leftPillCorner
        visible: root.centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle === 0 
        x: barContent.centerPillX - implicitSize
        implicitSize: Appearance.rounding.screenRounding
        color: Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colLayer0
        corner: RoundCorner.CornerEnum.TopRight

        states: State {
            name: "bottom"
            when: Config.options.bar.bottom
            AnchorChanges {
                target: leftPillCorner
                anchors.top: undefined
                anchors.bottom: barContent.bottom
            }
            PropertyChanges {
                target: leftPillCorner
                corner: RoundCorner.CornerEnum.BottomRight
            }
        }
        AnchorChanges {
            target: leftPillCorner
            anchors.top: barContent.top
            anchors.bottom: undefined
        }
    }

    Rectangle {
        id: centerPill
        visible: centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: GlobalStates.dynamicIslandEnabled
            ? (Config.options.bar.cornerStyle === 1 ? middleRow.implicitWidth + 8 : middleRow.implicitWidth - 4)
            : middleRow.implicitWidth + 10
        height: GlobalStates.dynamicIslandEnabled ? parent.height : parent.height - (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        color: root.useTabWrapper ? "transparent" : Config.options.bar.followFrameColor 
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colLayer0
        radius: Config.options.bar.cornerStyle === 1 || root.useTabWrapper ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
    }

    RoundCorner {
        id: rightPillCorner
        visible: root.centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle === 0
        x: barContent.centerPillX + barContent.centerPillWidth
        implicitSize: Appearance.rounding.screenRounding
        color: Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colLayer0
        corner: RoundCorner.CornerEnum.TopLeft

        states: State {
            name: "bottom"
            when: Config.options.bar.bottom
            AnchorChanges {
                target: rightPillCorner
                anchors.top: undefined
                anchors.bottom: barContent.bottom
            }
            PropertyChanges {
                target: rightPillCorner
                corner: RoundCorner.CornerEnum.BottomLeft
            }
        }
        AnchorChanges {
            target: rightPillCorner
            anchors.top: barContent.top
            anchors.bottom: undefined
        }
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Left
        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : Config.options.bar.cornerStyle === 5 ? 4 : 8))
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.useTabWrapper ? (leftMaterialPill.width + (root.hasTabs && root.effectiveLeftLayout.length > 0 ? leftRightOutwardCorner.implicitSize : 0)) : leftRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: leftMaterialPill
                visible: root.useTabWrapper && root.effectiveLeftLayout.length > 0
                anchors.left: root.hasTabs ? parent.left : undefined
                anchors.top: (root.hasTabs && !Config.options.bar.bottom) ? parent.top : undefined
                anchors.bottom: (root.hasTabs && Config.options.bar.bottom) ? parent.bottom : undefined
                anchors.centerIn: root.hasTabs ? undefined : parent
                width: leftMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : leftMaterialRow.implicitHeight
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                color: root.materialPillBgColor

                topLeftRadius: root.hasTabs ? 0 : radius
                bottomLeftRadius: root.hasTabs ? 0 : radius
                topRightRadius: (root.hasTabs && Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                RowLayout {
                    id: leftMaterialRow
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveLeftLayout
                        delegate: leftMaterialGroupDelegate
                    }

                    Component {
                        id: leftMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            widgetName: modelData
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

            RoundCorner {
                id: leftRightOutwardCorner
                visible: root.hasTabs && root.effectiveLeftLayout.length > 0
                anchors.left: leftMaterialPill.right
                anchors.top: !Config.options.bar.bottom ? parent.top : undefined
                anchors.bottom: Config.options.bar.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !Config.options.bar.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
            }

            // Non-material layout
            RowLayout {
                id: leftRow
                visible: !root.useTabWrapper
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7
                    : (Config.options?.bar.borderless === "segmented" && root.isPanel) ? 3
                    : Config.options?.bar.borderless === "segmented" ? -1
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveLeftLayout
                    delegate: leftBarGroupDelegate
                }

                Component {
                    id: leftBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        widgetName: modelData
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
            width: root.useTabWrapper ? (centerMaterialPill.width + (root.hasTabs && root.effectiveMiddleLayout.length > 0 ? (centerLeftOutwardCorner.implicitSize + centerRightOutwardCorner.implicitSize) : 0)) : middleRow.implicitWidth
            height: parent.height

            // Dynamic Island — left
            Loader {
                id: diLeftWidget
                anchors.right: absoluteCenter.left
                anchors.rightMargin: 8
                anchors.verticalCenter: absoluteCenter.verticalCenter
                active: Config.options.bar.dynamicIsland.leftWidget !== "none" && GlobalStates.dynamicIslandEnabled
                source: active ? root.getWidgetUrl(Config.options.bar.dynamicIsland.leftWidget) : ""
            }

            // Dynamic Island — right
            Loader {
                id: diRightWidget
                anchors.left: absoluteCenter.right
                anchors.leftMargin: 8
                anchors.verticalCenter: absoluteCenter.verticalCenter
                active: Config.options.bar.dynamicIsland.rightWidget !== "none" && GlobalStates.dynamicIslandEnabled
                source: active ? root.getWidgetUrl(Config.options.bar.dynamicIsland.rightWidget) : ""
            }

            RoundCorner {
                id: centerLeftOutwardCorner
                visible: root.hasTabs && root.effectiveMiddleLayout.length > 0
                anchors.right: centerMaterialPill.left
                anchors.top: !Config.options.bar.bottom ? parent.top : undefined
                anchors.bottom: Config.options.bar.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !Config.options.bar.bottom ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                visible: root.useTabWrapper && root.effectiveMiddleLayout.length > 0
                anchors.centerIn: parent
                width: centerMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : centerMaterialRow.implicitHeight 
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                color: root.materialPillBgColor

                topLeftRadius: (root.hasTabs && Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                topRightRadius: (root.hasTabs && Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomLeftRadius: (root.hasTabs && !Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                RowLayout {
                    id: centerMaterialRow
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveMiddleLayout
                        delegate: middleMaterialGroupDelegate
                    }

                    Component {
                        id: middleMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            widgetName: modelData
                            paintBackground: modelData !== "dynamicIsland"
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

            RoundCorner {
                id: centerRightOutwardCorner
                visible: root.hasTabs && root.effectiveMiddleLayout.length > 0
                anchors.left: centerMaterialPill.right
                anchors.top: !Config.options.bar.bottom ? parent.top : undefined
                anchors.bottom: Config.options.bar.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !Config.options.bar.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
            }

            // Non-material layout
            RowLayout {
                id: middleRow
                visible: !root.useTabWrapper
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7
                    : (Config.options?.bar.borderless === "segmented" && root.isPanel) ? 3
                    : Config.options?.bar.borderless === "segmented" ? -1
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveMiddleLayout
                    delegate: middleBarGroupDelegate
                }

                Component {
                    id: middleBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        widgetName: modelData
                        paintBackground: modelData !== "dynamicIsland"
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
            anchors.rightMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : Config.options.bar.cornerStyle === 5 ? 4 : 8))
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.useTabWrapper ? (rightMaterialPill.width + (root.hasTabs && root.effectiveRightLayout.length > 0 ? rightLeftOutwardCorner.implicitSize : 0)) : rightRow.implicitWidth

            RoundCorner {
                id: rightLeftOutwardCorner
                visible: root.hasTabs && root.effectiveRightLayout.length > 0
                anchors.right: rightMaterialPill.left
                anchors.top: !Config.options.bar.bottom ? parent.top : undefined
                anchors.bottom: Config.options.bar.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !Config.options.bar.bottom ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: rightMaterialPill
                visible: root.useTabWrapper && root.effectiveRightLayout.length > 0
                anchors.right: root.hasTabs ? parent.right : undefined
                anchors.top: (root.hasTabs && !Config.options.bar.bottom) ? parent.top : undefined
                anchors.bottom: (root.hasTabs && Config.options.bar.bottom) ? parent.bottom : undefined
                anchors.centerIn: root.hasTabs ? undefined : parent
                width: rightMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : rightMaterialRow.implicitHeight 
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                color: root.materialPillBgColor

                topRightRadius: root.hasTabs ? 0 : radius
                bottomRightRadius: root.hasTabs ? 0 : radius
                topLeftRadius: (root.hasTabs && Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomLeftRadius: (root.hasTabs && !Config.options.bar.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

                RowLayout {
                    id: rightMaterialRow
                    anchors.centerIn: parent
                    spacing: root.isSplitHug ? root.splitGroupSpacing : 3

                    Repeater {
                        model: root.effectiveRightLayout
                        delegate: rightMaterialGroupDelegate
                    }

                    Component {
                        id: rightMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            widgetName: modelData
                            totalCount: root.effectiveRightLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    try {
                                        if (item && item.hasOwnProperty("mirrored"))
                                            item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                                    } catch (e) {}
                                    if (item && item.hasOwnProperty("mirrored")) {
                                        try {
                                            item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index);
                                        } catch (e) {}
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: rightRow
                visible: !root.useTabWrapper
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7
                    : (Config.options?.bar.borderless === "segmented" && root.isPanel) ? 3
                    : Config.options?.bar.borderless === "segmented" ? -1
                    : root.isPanel ? 4 : 2

                Repeater {
                    model: root.effectiveRightLayout
                    delegate: rightBarGroupDelegate
                }

                Component {
                    id: rightBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        widgetName: modelData
                        totalCount: root.effectiveRightLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                try {
                                    if (item && item.hasOwnProperty("mirrored"))
                                        item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                                } catch (e) {}
                                if (item && item.hasOwnProperty("mirrored")) {
                                    try {
                                        item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index);
                                    } catch (e) {}
                                }
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
                            try {
                                if (item && item.hasOwnProperty("mirrored"))
                                    item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index)
                            } catch (e) {}
                            if (item && item.hasOwnProperty("mirrored")) {
                                try {
                                    item.mirrored = root.getMirroredForIndex(root.effectiveRightLayout, index);
                                } catch (e) {}
                            }
                        }
                    }
                }
            }
        }
    }
}