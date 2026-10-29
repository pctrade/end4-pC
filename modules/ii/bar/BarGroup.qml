import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import QtQuick.Layouts

Item {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property bool vertical: false
    property int currentIndex: 0
    property int totalCount: 0
    property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    property bool paintMaterialPill: false
    property bool paintBackground: true
    property color bgColor: Appearance.colors.colPrimaryContainer
    property string widgetName: ""
    property string morphEdge: ""
    property bool morphStartFlat: false
    property bool morphEndFlat: false
    readonly property alias box: background
    readonly property bool flatTL: (morphEdge === "top" || morphEdge === "left") && morphStartFlat
    readonly property bool flatTR: (morphEdge === "top" && morphEndFlat) || (morphEdge === "right" && morphStartFlat)
    readonly property bool flatBL: (morphEdge === "bottom" && morphStartFlat) || (morphEdge === "left" && morphEndFlat)
    readonly property bool flatBR: (morphEdge === "bottom" || morphEdge === "right") && morphEndFlat

    readonly property string borderlessMode: root.barConfig.borderless ?? "pills"
    readonly property bool styleEditable: !root.isMaterial && root.paintBackground && root.widgetName !== ""
    property var stylePreview: ({})
    readonly property var style: {
        if (root.isMaterial) return ({});
        const entry = (root.barConfig.widgetStyles ?? []).find(e => e.mode === root.borderlessMode && e.widget === root.widgetName);
        return Object?.assign?.({}, entry ?? {}, root.stylePreview) ?? ({});
    }

    function previewStyle(key, value) {
        root.stylePreview = Object.assign({}, root.stylePreview, { [key]: value });
    }

    function commitPreview() {
        const preview = root.stylePreview;
        root.stylePreview = ({});
        for (const key in preview) root.setStyle(key, preview[key]);
    }

    readonly property bool rightClickFree: !["updatesCount", "weatherBar", "bluetooth", "workspaces", "sysTray", "media", "docktoPanel"].includes(root.widgetName)

    readonly property Item loadedWidget: gridLayout.children[0]?.item ?? null
    readonly property bool hasContentOverride: !root.isMaterial && root.style?.color !== undefined && root.style?.color !== "transparent"
    readonly property color contentColor: {
        const name = root.style?.color ?? "";
        const special = { surfaceContainer: "onSurface", onError: "error", onLayer0: "layer0" };
        const onName = special[name] ?? `on${name.charAt(0).toUpperCase()}${name.slice(1)}`;
        return root.resolveColorName(onName) ?? Appearance.colors.colOnLayer1;
    }

    Binding {
        target: root.loadedWidget && "contentColor" in root.loadedWidget ? root.loadedWidget : null
        property: "contentColor"
        value: root.contentColor
        when: root.hasContentOverride
    }

    Binding {
        target: root.loadedWidget && "contentColorOverridden" in root.loadedWidget ? root.loadedWidget : null
        property: "contentColorOverridden"
        value: true
        when: root.hasContentOverride
    }

    Connections {
        target: root.loadedWidget
        ignoreUnknownSignals: true
        function onStyleEditorRequested() {
            root.toggleStyleEditor();
        }
    }

    function toggleStyleEditor() {
        if (!root.styleEditable) return;
        if (stylePopupLoader.item) stylePopupLoader.item.close();
        else stylePopupLoader.active = true;
    }

    function resolveColorName(name) {
        if (name === undefined) return undefined;
        if (name === "transparent") return "transparent";
        return Appearance.colors[`col${name.charAt(0).toUpperCase()}${name.slice(1)}`] ?? undefined;
    }

    function setStyle(key, value) {
        const styles = (root.barConfig.widgetStyles ?? []).map(e => Object.assign({}, e));
        let entry = styles.find(e => e.mode === root.borderlessMode && e.widget === root.widgetName);
        if (!entry) {
            entry = { mode: root.borderlessMode, widget: root.widgetName };
            styles.push(entry);
        }
        if (value === undefined) delete entry[key];
        else entry[key] = value;
        Config.setBarValueForScreen(root.barScreenName, "widgetStyles",
            styles.filter(e => Object.keys(e).length > 2));
    }

    function resetStyle() {
        Config.setBarValueForScreen(root.barScreenName, "widgetStyles",
            (root.barConfig.widgetStyles ?? [])
                .filter(e => !(e.mode === root.borderlessMode && e.widget === root.widgetName)));
    }

    readonly property color resolvedGroupColor: {
        const name = root.barConfig.groupColor
        const key = `col${name.charAt(0).toUpperCase()}${name.slice(1)}`
        return Appearance.colors[key] ?? Appearance.colors.colLayer1
    }

    readonly property real currentRadius: background.topLeftRadius
    readonly property real currentBorderWidth: background.border.width

    property real padding: root.style?.padding ?? ((root.isMaterial && !root.paintMaterialPill) ? 0 : 5)

    readonly property bool isSegmented: root.barConfig.borderless === "segmented"
    readonly property bool isPanel: root.barConfig.cornerStyle === 5
    readonly property real panelRadius: Appearance.rounding.unsharpenmore + 4

    readonly property real fullRadius: root.isPanel ? root.panelRadius : height / 2
    readonly property real midRadius: root.isPanel
        ? root.panelRadius
        : root.isSegmented
            ? 0
            : (root.barConfig.cornerStyle === 2 ? Appearance.rounding.unsharpenmore + 2 : Appearance.rounding.unsharpenmore)

    property real startRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === 0) return fullRadius;
        return midRadius;
    }
    property real endRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === totalCount - 1) return fullRadius;
        return midRadius;
    }

    implicitWidth: vertical && root.isMaterial ? Appearance.sizes.baseVerticalBarWidth - 6 : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight

    default property alias items: gridLayout.children

    Rectangle {
        id: background
        WindowGlass {
            anchors.fill: parent
            glassEnabled: (parent?.fill.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            topLeftRadius: parent && parent.topLeftRadius >= 0 ? parent.topLeftRadius : cardRadius
            topRightRadius: parent && parent.topRightRadius >= 0 ? parent.topRightRadius : cardRadius
            bottomLeftRadius: parent && parent.bottomLeftRadius >= 0 ? parent.bottomLeftRadius : cardRadius
            bottomRightRadius: parent && parent.bottomRightRadius >= 0 ? parent.bottomRightRadius : cardRadius
            tint: parent?.fill ?? 'transparent'
        }
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        property color fill: root.morphEdge !== ""
            ? Appearance.colors.colUiPopupBackground
            : !root.paintBackground
            ? "transparent"
            : root.resolveColorName(root.style?.color) !== undefined
                ? root.resolveColorName(root.style?.color)
            : (root.isMaterial && !root.paintMaterialPill)
                ? "transparent"
                : (root.isMaterial && root.paintMaterialPill)
                    ? root.bgColor
                    : (root.barConfig.borderless === "transparent"
                        ? "transparent"
                        : root.barConfig.cornerStyle === 2 || (root.barConfig.borderless === "segmented" && !root.barConfig.showBackground)
                            ? Appearance.colors.colUiBackground
                            : root.resolvedGroupColor)

        color: Config.options.background.widgets.glass.enable && fill.a > 0 ? "transparent" : fill

        border.width: root.morphEdge !== "" ? 0 : root.style?.borderWidth ?? (root.paintBackground && root.isSegmented && !root.isMaterial ? 1 : 0)
        border.color: root.resolveColorName(root.style?.borderColor) ?? Appearance.colors.colLayer0Border

        topLeftRadius: root.flatTL ? 0 : root.style?.radius ?? ((root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (root.barConfig.borderless === "separated" ? root.fullRadius : root.startRadius))
        bottomLeftRadius: root.flatBL ? 0 : root.style?.radius ?? ((root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (root.barConfig.borderless === "separated" ? root.fullRadius : root.vertical ? root.endRadius : root.startRadius))
        topRightRadius: root.flatTR ? 0 : root.style?.radius ?? ((root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (root.barConfig.borderless === "separated" ? root.fullRadius : root.vertical ? root.startRadius : root.endRadius))
        bottomRightRadius: root.flatBR ? 0 : root.style?.radius ?? ((root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (root.barConfig.borderless === "separated" ? root.fullRadius : root.endRadius))

        Behavior on color {
            enabled: root.morphEdge === ""
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
    }

    Item {
        anchors.fill: parent
        z: 1
        TapHandler {
            enabled: root.styleEditable && root.rightClickFree
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.toggleStyleEditor()
            onLongPressed: root.toggleStyleEditor()
        }
    }

    Loader {
        id: stylePopupLoader
        active: false
        sourceComponent: BarGroupStylePopup {
            group: root
            onDismissed: stylePopupLoader.active = false
        }
    }
}
