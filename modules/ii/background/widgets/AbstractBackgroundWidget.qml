import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale

    property Item wallpaperItem: null

    // Host of the true scene behind this widget (the depth wallpaper
    // container). Injected by WidgetsLoader; null = plain translucency.
    property var backdropHost: null

    property bool visibleWhenLocked: Config.options.lock.showWidgets
    property var configEntry: Config.options.background.widgets[configEntryName]
    property string placementStrategy: root.configEntry?.placementStrategy ?? "free"

    // Position anchor semantics. `false` (default, all keyed widgets) means
    // configEntry.x/.y store the widget's TOP-LEFT corner. `true` (custom
    // text widgets) means they store the widget's CENTER. The visual top-left
    // is ALWAYS derived here from the single stored value, so the settings
    // X/Y (px or %) and the drag-drop result are interpreted identically by
    // the render path and the persistence path — no widget subclass shadows
    // these bindings anymore.
    property bool centerAnchored: false

    function _targetX() {
        const maxW = Math.max(0, root.scaledScreenWidth - root.width)
        const fallback = root.centerAnchored ? (root.scaledScreenWidth / 2) : 0
        const c = root.configEntry?.x ?? fallback
        const topLeft = root.centerAnchored ? (c - root.width / 2) : c
        return Math.max(0, Math.min(topLeft, maxW))
    }
    function _targetY() {
        const maxH = Math.max(0, root.scaledScreenHeight - root.height)
        const fallback = root.centerAnchored ? (root.scaledScreenHeight / 2) : 0
        const c = root.configEntry?.y ?? fallback
        const topLeft = root.centerAnchored ? (c - root.height / 2) : c
        return Math.max(0, Math.min(topLeft, maxH))
    }
    property real targetX: root._targetX()
    property real targetY: root._targetY()
    x: targetX
    y: targetY

    // ✅ The widget's z-position comes from its position RELATIVE to the
    // depth wallpaper layers, not from a standalone widget stack. Reading the
    // config values declaratively keeps the binding alive when either the
    // widget's position or the layer list changes.
    //   depthLayerCount  = number of sorted layers (background is lowest)
    //   depthPosition k  = "just above layer k-1"; k = count means above the
    //                      highest layer (the default / front position).
    //   z = k - 0.5       → fraction half a step above the layer below it, so
    //                      it never collides with an integer layer z.
    //   pinnedBottom widgets (e.g. the visualizer) stay behind everything.
    readonly property int depthLayerCount: Math.max(1, (Config.options.background.depthEffect.layers ?? []).length)
    readonly property real depthPosition: {
        // configEntry may be undefined while Config loads; never let this
        // binding throw or Qt drops it and the widget's z freezes at 0-0.5.
        const raw = root.configEntry?.depthLayerPosition ?? -1
        return (raw > 0 && raw <= root.depthLayerCount) ? raw : root.depthLayerCount
    }
    // Small sub-order within the widget's layer slot, so overlapping widgets
    // sharing a layer can be ordered without crossing wallpaper layers.
    readonly property real stackOffset: (root.canvas && typeof root.canvas.stackOffset === "function")
        ? root.canvas.stackOffset(root.configEntryName)
        : 0
    z: root.pinnedBottom ? -1000 : root.depthPosition - 0.5 + root.stackOffset

    // Ordered back-to-front scene items strictly beneath this card (base
    // wallpaper, then depth layers below this widget's slot) for
    // WidgetBackdropBlur. Reactive in the layer list (depthLayers is
    // replaced on every refresh) and in this widget's own slot.
    readonly property var backdropSources: (root.backdropHost
        && typeof root.backdropHost.backdropSourcesBelow === "function")
        ? root.backdropHost.backdropSourcesBelow(root.depthPosition)
        : []

    visible: opacity > 0
    opacity: (GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    scale: (draggable && containsPress) ? 1.05 : 1
    // Scale about the visual center so the press-pop effect never shifts
    // the widget's top-left (a top-left origin would walk the widget
    // down-right on every press/drag cycle).
    transformOrigin: Item.Center
    Behavior on scale {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // draggable is controlled by each derived widget. Base class provides
    // the drag infrastructure via AbstractWidget.draggable (default true).
    // Derived widgets should override draggable as needed.
    // draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked
    function restoreXYBinding() {
        root.x = Qt.binding(() => root.targetX)
        root.y = Qt.binding(() => root.targetY)
    }

    function commitPosition() {
        // If a subclass (e.g. CustomTextWidget) overrides commitPosition,
        // it will be called instead of this one.  This base implementation
        // handles keyed widgets that store top-left coordinates.
        configEntry.x = root.x;
        configEntry.y = root.y;
        root.targetX = Qt.binding(() => Math.max(0, Math.min(configEntry?.x ?? 0, scaledScreenWidth - width)));
        root.targetY = Qt.binding(() => Math.max(0, Math.min(configEntry?.y ?? 0, scaledScreenHeight - height)));
        root.restoreXYBinding();
    }

    // Commit when the drag ENDS (dragging true->false), not on release:
    // onReleased does not fire when the pointer is released outside the
    // widget, which left the RestoreNone-stripped x/y binding permanently
    // destroyed (stale top-left position, Settings edits ignored). The
    // dragging-changed signal always fires at drag end, inside or outside.
    onDraggingChanged: {
        if (!root.dragging) root.commitPosition()
    }

    // Right-click: open the widget context menu instead of toggling the lock.
    function handleContextMenu(mouse) {
        const pos = root.mapToItem(null, mouse.x, mouse.y)
        GlobalStates.widgetContextMenuWindow = root.QsWindow.window
        GlobalStates.widgetContextMenuX = pos.x
        GlobalStates.widgetContextMenuY = pos.y
        GlobalStates.widgetContextMenuKey = root.configEntryName
        GlobalStates.widgetContextMenuOpen = true
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onNormalBackground = (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }

    property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
    property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
    
    onWallpaperPathChanged: refreshPlacementIfNeeded()
    onPlacementStrategyChanged: refreshPlacementIfNeeded()
    Connections {
        target: Config
        function onReadyChanged() { refreshPlacementIfNeeded() }
    }
    function refreshPlacementIfNeeded() {
        if (!Config.ready) return;
        if (root.placementStrategy === "free" && !root.needsColText) return;
        leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        // TODO: make these less arbitrary
        property int contentWidth: 300
        property int contentHeight: 300
        property int horizontalPadding: 200
        property int verticalPadding: 200
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh")
            , "--screen-width", Math.round(root.scaledScreenWidth)
            , "--screen-height", Math.round(root.scaledScreenHeight)
            , "--width", contentWidth
            , "--height", contentHeight
            , "--horizontal-padding", horizontalPadding
            , "--vertical-padding", verticalPadding
            , wallpaperPath
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                if (output.length === 0) return;
                const parsedContent = JSON.parse(output);
                root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                if (root.placementStrategy === "free") return;
                root.targetX = parsedContent.center_x * root.wallpaperScale - root.width / 2;
                root.targetY  = parsedContent.center_y * root.wallpaperScale - root.height / 2;
            }
        }
    }
}