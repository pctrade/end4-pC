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
    property var barConfig: Config.barForScreen(root.QsWindow.window?.screen?.name)
    implicitHeight: Appearance.sizes.barHeight
    width: parent.width
    readonly property real barPadding: 0
    readonly property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    readonly property bool isMaterialHug: root.barConfig.cornerStyle === 4
    readonly property bool isSplitHug: root.barConfig.cornerStyle === 6
    readonly property bool hasTabs: root.isMaterialHug || root.isSplitHug
    readonly property bool useTabWrapper: root.isMaterial || root.isSplitHug
    readonly property bool glassTabs: root.hasTabs && Config.options.background.widgets.glass.enable
    readonly property real tabFlare: root.glassTabs ? Appearance.rounding.screenRounding : 0
    readonly property bool glassHug: root.barConfig.cornerStyle === 0 && Config.options.background.widgets.glass.enable && root.barConfig.showBackground
    readonly property real hugFlare: root.glassHug && !root.centerOnly ? Appearance.rounding.screenRounding : 0
    readonly property real pillFlare: root.glassHug && root.centerOnly ? Appearance.rounding.screenRounding : 0
    readonly property real splitGroupSpacing: root.barConfig.borderless === "transparent" ? -7 : root.barConfig.borderless === "segmented" ? -1 : 2
    readonly property color materialPillBgColor: (root.barConfig.followFrameColor && root.barConfig.frameColor)
        ? Appearance.getColorFromName(root.barConfig.frameColor)
        : Appearance.colors.colUiBackground
    readonly property real centerPillX: centerPill.x
    readonly property real centerPillWidth: centerPill.width
    readonly property bool isPanel: root.barConfig.cornerStyle === 5
    readonly property bool dynamicIslandEnabled: Config.barHasWidget(root.screen?.name, "dynamicIsland")
    readonly property var diLeftWidgets:  filterLayout(root.barConfig.dynamicIsland.leftWidgets ?? [])
    readonly property var diRightWidgets: filterLayout(root.barConfig.dynamicIsland.rightWidgets ?? [])

    readonly property bool trayHasItems: SystemTray.items.values.length > 0

    function filterLayout(layout) {
        if (trayHasItems) return layout
        return layout.filter(name => name !== "sysTray")
    }

    readonly property var effectiveLeftLayout:   filterLayout(root.barConfig.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: filterLayout(root.barConfig.layouts.middleLayout)
    readonly property var effectiveRightLayout:  filterLayout(root.barConfig.layouts.rightLayout)

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
        anchors.margins: root.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        property color fill: (!centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle !== 2 && !root.useTabWrapper)
            ? (root.barConfig.followFrameColor
                ? Appearance.getColorFromName(root.barConfig.frameColor)
                : Appearance.colors.colUiBackground)
            : "transparent"
        color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill
        radius: root.barConfig.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && root.barConfig.cornerStyle === 1) ? 1 : 0
        border.color: root.barConfig.cornerStyle === 1 && !root.barConfig.showBackground ? "transparent" : ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.8)
    }

    WindowGlass {
        anchors.fill: barBackground
        anchors.topMargin: root.barConfig.bottom ? -root.hugFlare : 0
        anchors.bottomMargin: root.barConfig.bottom ? 0 : -root.hugFlare
        hangLeft: root.hugFlare
        hangRight: root.hugFlare
        edge: root.barConfig.bottom ? 1 : 0
        glassEnabled: barBackground.fill.a > 0
        cardRadius: barBackground.radius
        tint: barBackground.fill
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
        glass: true
        visible: root.centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle === 0 && !root.glassHug
        x: barContent.centerPillX - implicitSize
        implicitSize: Appearance.rounding.screenRounding
        color: root.barConfig.followFrameColor
            ? Appearance.getColorFromName(root.barConfig.frameColor)
            : Appearance.colors.colUiBackground
        corner: RoundCorner.CornerEnum.TopRight

        states: State {
            name: "bottom"
            when: root.barConfig.bottom
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
        WindowGlass {
            anchors.fill: parent
            anchors.leftMargin: -root.pillFlare
            anchors.rightMargin: -root.pillFlare
            flareLeft: root.pillFlare
            flareRight: root.pillFlare
            edge: root.barConfig.bottom ? 1 : 0
            glassEnabled: (parent?.fill.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
            topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
            bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
            bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
            tint: parent?.fill ?? 'transparent'
        }
        visible: centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle !== 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.dynamicIslandEnabled
            ? (root.barConfig.cornerStyle === 1 ? middleRow.implicitWidth + 8 : middleRow.implicitWidth - 4)
            : middleRow.implicitWidth + 10
        height: root.dynamicIslandEnabled ? parent.height : parent.height - (root.barConfig.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        property color fill: root.useTabWrapper ? "transparent" : root.barConfig.followFrameColor
            ? Appearance.getColorFromName(root.barConfig.frameColor)
            : Appearance.colors.colUiBackground
        color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill
        radius: root.barConfig.cornerStyle === 1 || root.useTabWrapper ? Appearance.rounding.windowRounding : 0
        border.width: root.barConfig.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  root.barConfig.cornerStyle === 0 && !root.barConfig.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: root.barConfig.cornerStyle === 0 && !root.barConfig.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     root.barConfig.cornerStyle === 0 && root.barConfig.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    root.barConfig.cornerStyle === 0 && root.barConfig.bottom  ? Appearance.rounding.screenRounding : radius
    }

    RoundCorner {
        id: rightPillCorner
        glass: true
        visible: root.centerOnly && root.barConfig.showBackground && root.barConfig.cornerStyle === 0 && !root.glassHug
        x: barContent.centerPillX + barContent.centerPillWidth
        implicitSize: Appearance.rounding.screenRounding
        color: root.barConfig.followFrameColor
            ? Appearance.getColorFromName(root.barConfig.frameColor)
            : Appearance.colors.colUiBackground
        corner: RoundCorner.CornerEnum.TopLeft

        states: State {
            name: "bottom"
            when: root.barConfig.bottom
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
            anchors.leftMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Config.options.hyprland.general.gapsOut || 5) : (root.barConfig.cornerStyle === 1 ? 4 : root.barConfig.cornerStyle === 5 ? 4 : 8))
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.useTabWrapper ? (leftMaterialPill.width + (root.hasTabs && root.effectiveLeftLayout.length > 0 ? leftRightOutwardCorner.implicitSize : 0)) : leftRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: leftMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.rightMargin: -root.tabFlare
                    anchors.topMargin: root.barConfig.bottom ? -root.tabFlare : 0
                    anchors.bottomMargin: root.barConfig.bottom ? 0 : -root.tabFlare
                    flareRight: root.tabFlare
                    hangLeft: root.tabFlare
                    edge: root.barConfig.bottom ? 1 : 0
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveLeftLayout.length > 0
                anchors.left: root.hasTabs ? parent.left : undefined
                anchors.top: (root.hasTabs && !root.barConfig.bottom) ? parent.top : undefined
                anchors.bottom: (root.hasTabs && root.barConfig.bottom) ? parent.bottom : undefined
                anchors.centerIn: root.hasTabs ? undefined : parent
                width: leftMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : leftMaterialRow.implicitHeight
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                topLeftRadius: root.hasTabs ? 0 : radius
                bottomLeftRadius: root.hasTabs ? 0 : radius
                topRightRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

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
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveLeftLayout.length > 0
                anchors.left: leftMaterialPill.right
                anchors.top: !root.barConfig.bottom ? parent.top : undefined
                anchors.bottom: root.barConfig.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
            }

            // Non-material layout
            RowLayout {
                id: leftRow
                visible: !root.useTabWrapper
                anchors.fill: parent
                spacing: root.barConfig.borderless === "transparent" ? -7
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -1
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
                        Layout.topMargin: root.barConfig.bottom ? -5 : 3
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
                active: root.barConfig.dynamicIsland.leftWidget !== "none" && root.dynamicIslandEnabled
                source: active ? root.getWidgetUrl(root.barConfig.dynamicIsland.leftWidget) : ""
            }

            // Dynamic Island — right
            Loader {
                id: diRightWidget
                anchors.left: absoluteCenter.right
                anchors.leftMargin: 8
                anchors.verticalCenter: absoluteCenter.verticalCenter
                active: root.barConfig.dynamicIsland.rightWidget !== "none" && root.dynamicIslandEnabled
                source: active ? root.getWidgetUrl(root.barConfig.dynamicIsland.rightWidget) : ""
            }

            RoundCorner {
                id: centerLeftOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveMiddleLayout.length > 0
                anchors.right: centerMaterialPill.left
                anchors.top: !root.barConfig.bottom ? parent.top : undefined
                anchors.bottom: root.barConfig.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.leftMargin: -root.tabFlare
                    anchors.rightMargin: -root.tabFlare
                    flareLeft: root.tabFlare
                    flareRight: root.tabFlare
                    edge: root.barConfig.bottom ? 1 : 0
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveMiddleLayout.length > 0
                anchors.centerIn: parent
                width: centerMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : centerMaterialRow.implicitHeight 
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                topLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                topRightRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomLeftRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomRightRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

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
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveMiddleLayout.length > 0
                anchors.left: centerMaterialPill.right
                anchors.top: !root.barConfig.bottom ? parent.top : undefined
                anchors.bottom: root.barConfig.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
            }

            // Non-material layout
            RowLayout {
                id: middleRow
                visible: !root.useTabWrapper
                anchors.fill: parent
                spacing: root.barConfig.borderless === "transparent" ? -7
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -1
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
                        Layout.topMargin: root.barConfig.bottom ? -5 : 3
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
            anchors.rightMargin: root.hasTabs ? 0 : (root.useTabWrapper ? (Config.options.hyprland.general.gapsOut || 5) : (root.barConfig.cornerStyle === 1 ? 4 : root.barConfig.cornerStyle === 5 ? 4 : 8))
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.useTabWrapper ? (rightMaterialPill.width + (root.hasTabs && root.effectiveRightLayout.length > 0 ? rightLeftOutwardCorner.implicitSize : 0)) : rightRow.implicitWidth

            RoundCorner {
                id: rightLeftOutwardCorner
                glass: true
                visible: root.hasTabs && !root.glassTabs && root.effectiveRightLayout.length > 0
                anchors.right: rightMaterialPill.left
                anchors.top: !root.barConfig.bottom ? parent.top : undefined
                anchors.bottom: root.barConfig.bottom ? parent.bottom : undefined
                implicitSize: Appearance.rounding.screenRounding
                color: root.materialPillBgColor
                corner: !root.barConfig.bottom ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
            }

            // Material pill wrapper
            Rectangle {
                id: rightMaterialPill
                WindowGlass {
                    anchors.fill: parent
                    anchors.leftMargin: -root.tabFlare
                    anchors.topMargin: root.barConfig.bottom ? -root.tabFlare : 0
                    anchors.bottomMargin: root.barConfig.bottom ? 0 : -root.tabFlare
                    flareLeft: root.tabFlare
                    hangRight: root.tabFlare
                    edge: root.barConfig.bottom ? 1 : 0
                    glassEnabled: (parent?.fill.a ?? 0) > 0
                    cardRadius: parent?.radius ?? 0
                    topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
                    topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
                    bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
                    bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
                    tint: parent?.fill ?? 'transparent'
                }
                visible: root.useTabWrapper && root.effectiveRightLayout.length > 0
                anchors.right: root.hasTabs ? parent.right : undefined
                anchors.top: (root.hasTabs && !root.barConfig.bottom) ? parent.top : undefined
                anchors.bottom: (root.hasTabs && root.barConfig.bottom) ? parent.bottom : undefined
                anchors.centerIn: root.hasTabs ? undefined : parent
                width: rightMaterialRow.implicitWidth + (root.hasTabs ? 16 : 10)
                height: root.hasTabs ? parent.height : rightMaterialRow.implicitHeight 
                radius: root.hasTabs ? 0 : Appearance.rounding.full
                property color fill: root.materialPillBgColor
                color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

                topRightRadius: root.hasTabs ? 0 : radius
                bottomRightRadius: root.hasTabs ? 0 : radius
                topLeftRadius: (root.hasTabs && root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)
                bottomLeftRadius: (root.hasTabs && !root.barConfig.bottom) ? Appearance.rounding.screenRounding : (root.hasTabs ? 0 : radius)

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
                spacing: root.barConfig.borderless === "transparent" ? -7
                    : (root.barConfig.borderless === "segmented" && root.isPanel) ? 3
                    : root.barConfig.borderless === "segmented" ? -1
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
                        Layout.topMargin: root.barConfig.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
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
