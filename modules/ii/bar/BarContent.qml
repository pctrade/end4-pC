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
            ? (Config.options.bar.followFrameColor
                ? Appearance.getColorFromName(Config.options.bar.frameColor)
                : Appearance.colors.colLayer0)
            : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && Config.options.bar.cornerStyle === 1) ? 1 : 0
        border.color: Config.options.bar.cornerStyle === 1 && !Config.options.bar.showBackground ? "transparent" : Appearance.colors.colLayer0Border
    }

    // center-only
    readonly property bool centerOnly: root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0

    RoundCorner {
        id: leftPillCorner
        visible: root.centerOnly && showBarBackground && Config.options.bar.cornerStyle === 0 
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
        width: absoluteCenter.nonMatWidth + 10
        height: parent.height - (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        color: Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colLayer0
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
    }

    RoundCorner {
        id: rightPillCorner
        visible: root.centerOnly && showBarBackground && Config.options.bar.cornerStyle === 0
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
            anchors.leftMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 8)
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
                            isDivisor: modelData === "divisor"
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
                spacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2

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
                            isDivisor: modelData === "divisor"
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
            anchors.fill: parent

            property var mappedMiddleLayout: root.effectiveMiddleLayout.map((id, idx) => ({ name: id, globalIndex: idx }))
            property int anchorIdx: {
                if (!Config.options.bar.layouts.centerAnchor) return -1;
                return root.effectiveMiddleLayout.indexOf(Config.options.bar.layouts.centerAnchor);
            }
            property var leftList: anchorIdx !== -1 ? mappedMiddleLayout.slice(0, anchorIdx) : []
            property var centerList: anchorIdx !== -1 ? [mappedMiddleLayout[anchorIdx]] : mappedMiddleLayout
            property var rightList: anchorIdx !== -1 ? mappedMiddleLayout.slice(anchorIdx + 1) : []
            property int spacingVal: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2
            property real nonMatWidth: nonMatLeft.implicitWidth + nonMatCenter.implicitWidth + nonMatRight.implicitWidth + (absoluteCenter.leftList.length > 0 ? absoluteCenter.spacingVal : 0) + (absoluteCenter.rightList.length > 0 ? absoluteCenter.spacingVal : 0)

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                visible: root.isMaterial
                anchors.left: (absoluteCenter.anchorIdx !== -1 && absoluteCenter.leftList.length > 0) ? matLeft.left : matCenter.left
                anchors.right: (absoluteCenter.anchorIdx !== -1 && absoluteCenter.rightList.length > 0) ? matRight.right : matCenter.right
                anchors.leftMargin: -5
                anchors.rightMargin: -5
                anchors.verticalCenter: parent.verticalCenter
                height: matCenter.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0
            }

            // Material Layouts
            RowLayout {
                id: matLeft
                visible: root.isMaterial
                anchors.right: matCenter.left
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater { model: absoluteCenter.leftList; delegate: middleMaterialGroupDelegate }
            }
            RowLayout {
                id: matCenter
                visible: root.isMaterial
                anchors.centerIn: parent
                spacing: 3
                Repeater { model: absoluteCenter.centerList; delegate: middleMaterialGroupDelegate }
            }
            RowLayout {
                id: matRight
                visible: root.isMaterial
                anchors.left: matCenter.right
                anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater { model: absoluteCenter.rightList; delegate: middleMaterialGroupDelegate }
            }

            Component {
                id: middleMaterialGroupDelegate
                BarGroup {
                    Layout.fillHeight: true
                    currentIndex: modelData.globalIndex
                    totalCount: root.effectiveMiddleLayout.length
                    isDivisor: modelData.name === "divisor"
                    paintMaterialPill: root.shouldPaintMaterialPill(modelData.name)
                    bgColor: root.getMaterialPillColor(modelData.name)
                    Loader {
                        Layout.fillHeight: true
                        source: root.getWidgetUrl(modelData.name)
                        onLoaded: {
                            if (item && item.hasOwnProperty("mirrored"))
                                item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, modelData.globalIndex)
                        }
                    }
                }
            }

            // Non-material Layouts
            RowLayout {
                id: nonMatLeft
                visible: !root.isMaterial
                anchors.right: nonMatCenter.left
                anchors.rightMargin: absoluteCenter.spacingVal
                anchors.verticalCenter: parent.verticalCenter
                spacing: absoluteCenter.spacingVal
                Repeater { model: absoluteCenter.leftList; delegate: middleBarGroupDelegate }
            }
            RowLayout {
                id: nonMatCenter
                visible: !root.isMaterial
                anchors.centerIn: parent
                spacing: absoluteCenter.spacingVal
                Repeater { model: absoluteCenter.centerList; delegate: middleBarGroupDelegate }
            }
            RowLayout {
                id: nonMatRight
                visible: !root.isMaterial
                anchors.left: nonMatCenter.right
                anchors.leftMargin: absoluteCenter.spacingVal
                anchors.verticalCenter: parent.verticalCenter
                spacing: absoluteCenter.spacingVal
                Repeater { model: absoluteCenter.rightList; delegate: middleBarGroupDelegate }
            }

            Component {
                id: middleBarGroupDelegate
                BarGroup {
                    Layout.fillHeight: true
                    currentIndex: modelData.globalIndex
                    totalCount: root.effectiveMiddleLayout.length
                    isDivisor: modelData.name === "divisor"
                    Loader {
                        Layout.fillHeight: true
                        source: root.getWidgetUrl(modelData.name)
                        onLoaded: {
                            if (item && item.hasOwnProperty("mirrored"))
                                item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, modelData.globalIndex)
                        }
                    }
                }
            }

            Component {
                id: middleNoGroupDelegate
                Loader {
                    Layout.fillHeight: false
                    Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                    source: root.getWidgetUrl(modelData.name)
                    onLoaded: {
                        if (item && item.hasOwnProperty("mirrored"))
                            item.mirrored = root.getMirroredForIndex(root.effectiveMiddleLayout, modelData.globalIndex)
                    }
                }
            }
        }

        // Right
        Item {
            anchors.right: parent.right
            anchors.rightMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 8)
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
                            isDivisor: modelData === "divisor"
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
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2

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
                            isDivisor: modelData === "divisor"
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
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
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