import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: rootWidget
    required property var manifest
    required property string screenName
    readonly property bool blurEnabled: manifest
        ? PluginState.option(manifest.id, "blurEnabled", manifest.desktopWidget?.blur === true)
        : false

    configEntryName: manifest ? "plugin_" + manifest.id : "plugin_unknown"

    // Plugin ids and monitor names are dynamic, so their layout cannot safely live in
    // Config's fixed JsonAdapter schema. PluginState persists it as raw JSON instead.
    property var currentConfig: manifest
        ? PluginState.position(manifest.id, screenName)
        : PluginState.defaultPosition()
    placementStrategy: currentConfig.placementStrategy || "free"

    // Override targetX and targetY to avoid errors when configEntry is undefined
    targetX: Math.max(0, Math.min(currentConfig.x !== undefined ? currentConfig.x : 100, scaledScreenWidth - width))
    targetY: Math.max(0, Math.min(currentConfig.y !== undefined ? currentConfig.y : 100, scaledScreenHeight - height))

    onReleased: {
        rootWidget.targetX = rootWidget.x;
        rootWidget.targetY = rootWidget.y;
        if (!manifest) return;
        PluginState.setPosition(manifest.id, screenName, {
            x: rootWidget.targetX,
            y: rootWidget.targetY,
            placementStrategy: rootWidget.placementStrategy
        });
    }

    width: Math.max(manifest ? (manifest.defaultWidth || 0) : 0, pluginNode.width)
    height: Math.max(manifest ? (manifest.defaultHeight || 0) : 0, pluginNode.height)

    // Widgets here share the same background-layer surface as the wallpaper itself
    // (see Background.qml's WlrLayershell.namespace), so there's no separate surface
    // behind them for the compositor to blur - Hyprland's `layerrule blur` has nothing
    // to do here. Match UserCardWidget.qml's approach instead: sample + blur the
    // wallpaper ourselves. The sample window tracks rootWidget.x/y live so it keeps
    // showing the correct region while the widget is being dragged.
    readonly property real widgetRounding: {
        const val = manifest?.desktopWidget?.props?.radius;
        if (typeof val === "string" && val.startsWith("Appearance.rounding.")) {
            return Appearance.rounding[val.substring(20)] ?? Appearance.rounding.large;
        }
        if (typeof val === "number") return val;
        return Appearance.rounding.large;
    }

    Item {
        id: blurredBackdrop
        anchors.fill: parent
        clip: true
        visible: rootWidget.blurEnabled && Config.options.appearance.transparency.enable
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: blurredBackdrop.width
                height: blurredBackdrop.height
                radius: rootWidget.widgetRounding
            }
        }

        Image {
            id: wallpaperSample
            source: rootWidget.wallpaperPath ? ("file://" + rootWidget.wallpaperPath) : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            width: rootWidget.scaledScreenWidth
            height: rootWidget.scaledScreenHeight
            x: -rootWidget.x
            y: -rootWidget.y
            layer.enabled: true
            layer.effect: FastBlur { radius: 48 }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colScrim
            opacity: 0.1
        }
    }

    PluginNode {
        id: pluginNode
        manifestNode: rootWidget.manifest ? rootWidget.manifest.desktopWidget : null
        pluginId: rootWidget.manifest?.id ?? ""
        optionDefinitions: rootWidget.manifest?.options ?? []
        anchors.centerIn: parent
    }
}
