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

    property bool visibleWhenLocked: Config.options.lock.showWidgets
    property var configEntry: Config.options.background.widgets[configEntryName]
    property string placementStrategy: configEntry.placementStrategy

    // Calculate normalized fraction of available margin for 100% 1-to-1 multi-monitor precision
    property real maxAvailWidth: Math.max(1, scaledScreenWidth - width)
    property real maxAvailHeight: Math.max(1, scaledScreenHeight - height)

    property real targetX: {
        if (configEntry === undefined || configEntry.x === undefined) return 0.5 * maxAvailWidth;
        const val = configEntry.x;
        // Support legacy pixel values (> 1.0) and relative fractions (0.0 .. 1.0)
        const normX = (val > 1.0) ? Math.min(1.0, Math.max(0.0, val / maxAvailWidth)) : Math.min(1.0, Math.max(0.0, val));
        return normX * maxAvailWidth;
    }

    property real targetY: {
        if (configEntry === undefined || configEntry.y === undefined) return 0.5 * maxAvailHeight;
        const val = configEntry.y;
        // Support legacy pixel values (> 1.0) and relative fractions (0.0 .. 1.0)
        const normY = (val > 1.0) ? Math.min(1.0, Math.max(0.0, val / maxAvailHeight)) : Math.min(1.0, Math.max(0.0, val));
        return normY * maxAvailHeight;
    }

    property real targetZ: configEntry.z

    x: targetX
    y: targetY
    z: targetZ
    visible: opacity > 0
    opacity: (GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    scale: (draggable && containsPress) ? 1.05 : 1
    Behavior on scale {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked
    function restoreXYBinding() {
        root.x = Qt.binding(() => root.targetX);
        root.y = Qt.binding(() => root.targetY);
        root.z = Qt.binding(() => root.targetZ);
    }

    function commitPosition() {
        const availW = Math.max(1, scaledScreenWidth - root.width);
        const availH = Math.max(1, scaledScreenHeight - root.height);

        const normX = Math.max(0.0, Math.min(1.0, root.x / availW));
        const normY = Math.max(0.0, Math.min(1.0, root.y / availH));

        configEntry.x = normX;
        configEntry.y = normY;
        configEntry.z = root.z;

        root.targetX = Qt.binding(() => normX * Math.max(1, scaledScreenWidth - root.width));
        root.targetY = Qt.binding(() => normY * Math.max(1, scaledScreenHeight - root.height));
        root.targetZ = Qt.binding(() => configEntry.z);
        root.restoreXYBinding();
    }

    onReleased: root.commitPosition()

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