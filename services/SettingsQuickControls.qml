pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    readonly property var hypr: Config.options.hyprland

    function toggle(get, set) {
        return { type: "switch", get: get, set: set };
    }

    function spin(get, set, from, to, stepSize) {
        return { type: "spin", get: get, set: set, from: from, to: to, stepSize: stepSize };
    }

    function select(get, set, options) {
        return { type: "select", get: get, set: set, options: options };
    }

    function hyprSwitch(read, write, key) {
        return root.toggle(read, value => {
            write(value);
            HyprlandConfig.set(key, value ? 1 : 0);
        });
    }

    function hyprSpin(read, write, key, from, to, stepSize, scale) {
        const factor = scale ?? 1;
        return root.spin(
            () => Math.round(read() * factor),
            value => {
                write(value / factor);
                HyprlandConfig.set(key, value / factor);
            },
            from, to, stepSize
        );
    }

    function optionAccessors(path) {
        const keys = path.split(".");
        const last = keys.pop();
        const parent = () => keys.reduce((node, key) => node[key], Config.options);
        return { get: () => parent()[last], set: value => { parent()[last] = value; } };
    }

    function optionSwitch(path) {
        const access = root.optionAccessors(path);
        return root.toggle(access.get, access.set);
    }

    function optionSpin(path, from, to, stepSize) {
        const access = root.optionAccessors(path);
        return root.spin(access.get, access.set, from, to, stepSize);
    }

    function optionSlider(path, from, to, stopIndicatorValues, usePercentTooltip) {
        const access = root.optionAccessors(path);
        return {
            type: "slider", get: access.get, set: access.set, from: from, to: to,
            stopIndicatorValues: stopIndicatorValues ?? [], usePercentTooltip: usePercentTooltip ?? true
        };
    }

    function optionScaledSpin(path, from, to, stepSize, factor) {
        const access = root.optionAccessors(path);
        return root.spin(() => Math.round(access.get() * factor), value => access.set(value / factor), from, to, stepSize);
    }

    function optionSelect(path, options) {
        const access = root.optionAccessors(path);
        return root.select(access.get, access.set, options);
    }

    readonly property var controls: ({
        "desktop:Preview wallpaper": root.optionSwitch("background.enableWallpaperPreview"),
        "desktop:Blur wall": root.optionSwitch("background.showBlur"),
        "desktop:Blur Size": root.optionSlider("background.blurRadius", 1, 64, [32], false),
        "desktop:Split blur amount": root.optionSelect("background.splitRatio", [
            { displayName: "25%", icon: "thumbnail_bar", value: "25" },
            { displayName: "50%", icon: "side_navigation", value: "50" },
            { displayName: "100%", icon: "fullscreen", value: "100" }
        ]),
        "desktop:Split blur side": root.optionSelect("background.splitSide", [
            { displayName: Translation.tr("Left"), icon: "align_horizontal_left", value: "left" },
            { displayName: Translation.tr("Right"), icon: "align_horizontal_right", value: "right" }
        ]),
        "desktop:Wallpaper change interval (min)": root.spin(
            () => Math.round(Config.options.wallpaperSelector.changeInterval / 60000),
            value => { Config.options.wallpaperSelector.changeInterval = value * 60000; },
            0, 1440, 5
        ),
        "desktop:Wallpaper/Centered wallpaper/Enable": root.optionSwitch("background.centeredWallpaper"),
        "desktop:Wallpaper/Centered wallpaper/Show only when locked": root.optionSwitch("background.centeredWallpaperOnlyWhenLocked"),
        "desktop:Wallpaper/Centered wallpaper/Size": root.optionSlider("background.centeredWallpaperSize", 400, 800, [400], false),
        "desktop:Clock/Enable": root.optionSwitch("background.widgets.clock.enable"),
        "desktop:Clock/Show only when locked": root.optionSwitch("background.widgets.clock.showOnlyWhenLocked"),
        "desktop:Placement strategy": root.optionSelect("background.widgets.clock.placementStrategy", [
            { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
            { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
            { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" }
        ]),
        "desktop:Clock style": root.optionSelect("background.widgets.clock.style", [
            { displayName: Translation.tr("Digital"), icon: "timer_10", value: "digital" },
            { displayName: Translation.tr("Cookie"), icon: "cookie", value: "cookie" },
            { displayName: Translation.tr("Daily"), icon: "today", value: "daily" },
            { displayName: Translation.tr("Pixel"), icon: "grid_view", value: "pixel" }
        ]),
        "desktop:Clock style (locked)": root.optionSelect("background.widgets.clock.styleLocked", [
            { displayName: Translation.tr("Digital"), icon: "timer_10", value: "digital" },
            { displayName: Translation.tr("Cookie"), icon: "cookie", value: "cookie" },
            { displayName: Translation.tr("Daily"), icon: "today", value: "daily" },
            { displayName: Translation.tr("Pixel"), icon: "grid_view", value: "pixel" }
        ]),
        "desktop:Vertical": root.optionSwitch("background.widgets.clock.digital.vertical"),
        "desktop:Show date": root.optionSwitch("background.widgets.clock.digital.showDate"),
        "desktop:Animate time change": root.optionSwitch("background.widgets.clock.digital.animateChange"),
        "desktop:Use adaptive alignment": root.optionSwitch("background.widgets.clock.digital.adaptiveAlignment"),
        "desktop:Font weight": root.optionSlider("background.widgets.clock.digital.font.weight", 1, 1000, [350], false),
        "desktop:Font size": root.optionSlider("background.widgets.clock.digital.font.size", 50, 700, [90], false),
        "desktop:Font width": root.optionSlider("background.widgets.clock.digital.font.width", 25, 125, [100], false),
        "desktop:Font roundness": root.optionSlider("background.widgets.clock.digital.font.roundness", 0, 100, [], false),
        "desktop:Auto styling with Gemini": root.optionSwitch("background.widgets.clock.cookie.aiStyling"),
        "desktop:Use old sine wave cookie implementation": root.optionSwitch("background.widgets.clock.cookie.useSineCookie"),
        "desktop:Sides": root.optionSpin("background.widgets.clock.cookie.sides", 0, 40, 1),
        "desktop:Constantly rotate": root.optionSwitch("background.widgets.clock.cookie.constantlyRotate"),
        "desktop:Hour marks": root.optionSwitch("background.widgets.clock.cookie.hourMarks"),
        "desktop:Digits in the middle": root.optionSwitch("background.widgets.clock.cookie.timeIndicators"),
        "desktop:Dial Style": root.select(
            () => Config.options.background.widgets.clock.cookie.dialNumberStyle,
            value => {
                Config.options.background.widgets.clock.cookie.dialNumberStyle = value;
                Config.options.background.widgets.clock.cookie.hourMarks = false;
                Config.options.background.widgets.clock.cookie.timeIndicators = false;
            },
            [
                { displayName: "",                        icon: "block",              value: "none" },
                { displayName: Translation.tr("Dots"),    icon: "graph_6",            value: "dots" },
                { displayName: Translation.tr("Full"),    icon: "history_toggle_off", value: "full" },
                { displayName: Translation.tr("Numbers"), icon: "counter_1",          value: "numbers" }
            ]
        ),
        "desktop:Hour hand": root.optionSelect("background.widgets.clock.cookie.hourHandStyle", [
            { displayName: "", icon: "block", value: "hide" },
            { displayName: Translation.tr("Classic"), icon: "radio", value: "classic" },
            { displayName: Translation.tr("Hollow"), icon: "circle", value: "hollow" },
            { displayName: Translation.tr("Fill"), icon: "eraser_size_5", value: "fill" }
        ]),
        "desktop:Second hand": root.optionSelect("background.widgets.clock.cookie.secondHandStyle", [
            { displayName: "", icon: "block", value: "hide" },
            { displayName: Translation.tr("Classic"), icon: "radio", value: "classic" },
            { displayName: Translation.tr("Line"), icon: "line_end", value: "line" },
            { displayName: Translation.tr("Dot"), icon: "adjust", value: "dot" }
        ]),
        "desktop:Date style": root.optionSelect("background.widgets.clock.cookie.dateStyle", [
            { displayName: "", icon: "block", value: "hide" },
            { displayName: Translation.tr("Bubble"), icon: "bubble_chart", value: "bubble" },
            { displayName: Translation.tr("Border"), icon: "rotate_right", value: "border" },
            { displayName: Translation.tr("Rect"), icon: "rectangle", value: "rect" }
        ]),
        "desktop:Pixel clock orientation": root.optionSelect("background.widgets.clock.pixel.orientation", [
            { displayName: Translation.tr("Horizontal"), icon: "swap_horiz", value: "horizontal" },
            { displayName: Translation.tr("Vertical"), icon: "swap_vert", value: "vertical" }
        ]),
        "desktop:Clock/Quote/Enable": root.optionSwitch("background.widgets.clock.quote.enable"),
        "desktop:Follow Clock Font": root.optionSwitch("background.widgets.clock.quote.followClock"),
        "desktop:Custom Image/Enable": root.optionSwitch("background.widgets.customImage.enable"),
        "desktop:Image card/Enable": root.optionSwitch("background.widgets.imageCard.enable"),
        "desktop:Show alignment grid while dragging": root.optionSwitch("background.showGrid"),
        "desktop:Show snap lines when dropping": root.optionSwitch("background.showSnapLines"),

        "interface:Transparency/Enable": root.optionSwitch("appearance.transparency.enable"),
        "interface:Automatic (from wallpaper)": root.optionSwitch("appearance.transparency.automatic"),
        "interface:Transparency/Background": root.optionSlider("appearance.transparency.backgroundTransparency", 0, 0.6, [0.11]),
        "interface:Transparency/Content": root.optionSlider("appearance.transparency.contentTransparency", 0, 1, [0.57]),
        "interface:Settings Panel/Style": root.optionSelect("settings.style", [
            { displayName: Translation.tr("Default"), icon: "settings_panorama", value: "default" },
            { displayName: Translation.tr("Minimal"), icon: "settings_heart", value: "minimal" }
        ]),
        "interface:Border width": root.optionSpin("settings.borderSize", 0, 10, 1),
        "interface:Left Sidebar/Enable": root.optionSwitch("sidebar.media.enable"),
        "interface:Follow Album Colors": root.optionSwitch("sidebar.media.artColors"),
        "interface:Enable Translator": root.optionSwitch("sidebar.translator.enable"),
        "interface:Enable Apps": root.optionSwitch("sidebar.apps.enable"),
        "interface:Enable Football": root.optionSwitch("sidebar.football.enable"),
        "interface:Football/Alerts": root.optionSwitch("sidebar.football.alerts"),
        "interface:Football/Scope": root.optionSelect("sidebar.football.alertsScope", [
            { displayName: Translation.tr("My parlay"), icon: "layers", value: "parlay" },
            { displayName: Translation.tr("All matches"), icon: "public", value: "all" }
        ]),
        "interface:Football/Goal sound": root.optionSwitch("sidebar.football.goalSound"),
        "interface:Football/Corner sound": root.optionSwitch("sidebar.football.cornerSound"),
        "interface:Football/Notify": root.optionSwitch("sidebar.football.notify"),
        "interface:Football/Volume": root.optionSpin("sidebar.football.soundVolume", 0, 100, 5),
        "interface:Banner": root.optionSwitch("sidebar.banner"),
        "interface:Bottom Group": root.optionSwitch("sidebar.bottomGroup"),
        "interface:Right Sidebar/Media Player": root.optionSwitch("sidebar.mediaPlayer"),
        "interface:Keep right sidebar loaded": root.optionSwitch("sidebar.keepRightSidebarLoaded"),
        "interface:Right Sidebar/Style": root.optionSelect("sidebar.quickToggles.style", [
            { displayName: Translation.tr("Classic"), icon: "password_2", value: "classic" },
            { displayName: Translation.tr("Android"), icon: "action_key", value: "android" }
        ]),
        "interface:Right Sidebar/Columns": root.optionSpin("sidebar.quickToggles.android.columns", 1, 8, 1),
        "interface:Right Sidebar/Enable": root.optionSwitch("sidebar.quickSliders.enable"),
        "interface:Brightness": root.optionSwitch("sidebar.quickSliders.showBrightness"),
        "interface:Volume": root.optionSwitch("sidebar.quickSliders.showVolume"),
        "interface:Microphone": root.optionSwitch("sidebar.quickSliders.showMic"),
        "interface:Hot Corners/Enable": root.optionSwitch("sidebar.cornerOpen.enable"),
        "interface:Hover to trigger": root.optionSwitch("sidebar.cornerOpen.clickless"),
        "interface:Place at bottom": root.optionSwitch("sidebar.cornerOpen.bottom"),
        "interface:Value scroll": root.optionSwitch("sidebar.cornerOpen.valueScroll"),
        "interface:Visualize region": root.optionSwitch("sidebar.cornerOpen.visualize"),
        "interface:Force hover at absolute corner": root.optionSwitch("sidebar.cornerOpen.clicklessCornerEnd"),
        "interface:Vertical offset": root.optionSpin("sidebar.cornerOpen.clicklessCornerVerticalOffset", 0, 20, 1),
        "interface:Region width": root.optionSpin("sidebar.cornerOpen.cornerRegionWidth", 1, 300, 1),
        "interface:Region height": root.optionSpin("sidebar.cornerOpen.cornerRegionHeight", 1, 300, 1),
        "interface:Overview/Enable": root.optionSwitch("overview.enable"),
        "interface:Center icons": root.optionSwitch("overview.centerIcons"),
        "interface:Scale (%)": root.optionScaledSpin("overview.scale", 1, 100, 1, 100),
        "interface:Overview/Style": root.optionSelect("overview.style", [
            { displayName: Translation.tr("Default"), icon: "grid_on", value: "default" },
            { displayName: Translation.tr("Niri Like"), icon: "mobiledata_arrows", value: "niri" }
        ]),
        "interface:Rows": root.optionSpin("overview.rows", 1, 20, 1),
        "interface:Overview/Columns": root.optionSpin("overview.columns", 1, 20, 1),
        "interface:Dock/Enable": root.optionSwitch("dock.enable"),
        "interface:Dock/Background": root.optionSwitch("dock.showBackground"),
        "interface:Hover to reveal": root.optionSwitch("dock.hoverToReveal"),
        "interface:Pinned on startup": root.optionSwitch("dock.pinnedOnStartup"),
        "interface:Dock/Media Player": root.optionSwitch("dock.showMedia"),
        "interface:Show Pin Button": root.optionSwitch("dock.showPinButton"),
        "interface:Show Apps Button": root.optionSwitch("dock.showAppsButton"),
        "interface:Tint app icons": root.optionSwitch("dock.monochromeIcons"),
        "interface:Use Hyprlock (instead of Quickshell)": root.optionSwitch("lock.useHyprlock"),
        "interface:Launch on startup": root.optionSwitch("lock.launchOnStartup"),
        "interface:Show Widgets": root.optionSwitch("lock.showWidgets"),
        "interface:Show Toolbars": root.optionSwitch("lock.showToolbars"),
        "interface:Show media player info": root.optionSwitch("lock.showMedia"),
        "interface:Require password to power off/restart": root.optionSwitch("lock.security.requirePasswordToPower"),
        "interface:Also unlock keyring": root.optionSwitch("lock.security.unlockKeyring"),
        "interface:Center clock": root.optionSwitch("lock.centerClock"),
        "interface:Show \"Locked\" text": root.optionSwitch("lock.showLockedText"),
        "interface:Use varying shapes for password characters": root.optionSwitch("lock.materialShapeChars"),
        "interface:Enable blur": root.optionSwitch("lock.blur.enable"),
        "interface:Samples": root.optionSpin("lock.blur.size", 20, 200, 10),
        "interface:Extra wallpaper zoom (%)": root.optionScaledSpin("lock.blur.extraZoom", 1, 150, 2, 100),
        "interface:Enable opening zoom animation": root.optionSwitch("overlay.openingZoomAnimation"),
        "interface:Darken screen": root.optionSwitch("overlay.darkenScreen"),
        "interface:Region selector (screen snipping/Google Lens)/Windows": root.optionSwitch("regionSelector.targetRegions.windows"),
        "interface:Region selector (screen snipping/Google Lens)/Layers": root.optionSwitch("regionSelector.targetRegions.layers"),
        "interface:Region selector (screen snipping/Google Lens)/Content": root.optionSwitch("regionSelector.targetRegions.content"),
        "interface:Show aim lines": root.optionSwitch("regionSelector.rect.showAimLines"),
        "interface:Stroke width": root.optionSpin("regionSelector.circle.strokeWidth", 1, 20, 1),
        "interface:Padding": root.optionSpin("regionSelector.circle.padding", 0, 100, 5),
        "interface:Timeout (ms)": root.optionSpin("osd.timeout", 100, 3000, 100),
        "interface:Use system file picker": root.optionSwitch("wallpaperSelector.useSystemFileDialog"),
        "interface:Show home directory in quick access": root.optionSwitch("wallpaperSelector.showHomePath"),
        "interface:Close after selection": root.optionSwitch("wallpaperSelector.closeAfterSelection"),
        "interface:Show blur background": root.optionSwitch("wallpaperSelector.showBlurBackground"),
        "interface:Columns in grid view": root.optionSpin("wallpaperSelector.columns", 3, 10, 1),
        "interface:Always show search bar": root.optionSwitch("wallpaperSelector.showSearchbar"),
        "interface:Shell & utilities": root.optionSwitch("appearance.wallpaperTheming.enableAppsAndShell"),
        "interface:Qt apps": root.optionSwitch("appearance.wallpaperTheming.enableQtApps"),
        "interface:Terminal": root.optionSwitch("appearance.wallpaperTheming.enableTerminal"),
        "interface:Force dark mode in terminal": root.optionSwitch("appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode"),
        "interface:Terminal: Harmony (%)": root.optionScaledSpin("appearance.wallpaperTheming.terminalGenerationProps.harmony", 0, 100, 10, 100),
        "interface:Terminal: Harmonize threshold": root.optionSpin("appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold", 0, 100, 10),
        "interface:Terminal: Foreground boost (%)": root.optionScaledSpin("appearance.wallpaperTheming.terminalGenerationProps.termFgBoost", 0, 100, 10, 100),
        "interface:Wallpaper change interval (min)": root.spin(
            () => Math.round(Config.options.wallpaperSelector.changeInterval / 60000),
            value => { Config.options.wallpaperSelector.changeInterval = value * 60000; },
            0, 1440, 5
        ),
        "interface:Selection Type": root.select(
            () => Config.options.search.imageSearch.useCircleSelection ? "circle" : "rectangles",
            value => { Config.options.search.imageSearch.useCircleSelection = (value === "circle"); },
            [
                { displayName: Translation.tr("Rectangular selection"), icon: "activity_zone", value: "rectangles" },
                { displayName: Translation.tr("Circle to Search"),      icon: "gesture",       value: "circle" }
            ]
        ),

        "bar:Show Background": root.optionSwitch("bar.showBackground"),
        "bar:Overlap windows when center-only": root.optionSwitch("bar.centerOnlyReserveFrame"),
        "bar:Follow Frame Color": root.optionSwitch("bar.followFrameColor"),
        "bar:Show media controls": root.optionSwitch("bar.dynamicIsland.showMediaControls"),
        "bar:Unread indicator: show count": root.optionSwitch("bar.indicators.notifications.showUnreadCount"),
        "bar:Make icons pinned by default": root.optionSwitch("tray.invertPinnedItems"),
        "bar:Tint icons": root.optionSwitch("tray.monochromeIcons"),
        "bar:Screen snip": root.optionSwitch("bar.utilButtons.showScreenSnip"),
        "bar:Color picker": root.optionSwitch("bar.utilButtons.showColorPicker"),
        "bar:Keyboard toggle": root.optionSwitch("bar.utilButtons.showKeyboardToggle"),
        "bar:Mic toggle": root.optionSwitch("bar.utilButtons.showMicToggle"),
        "bar:Dark/Light toggle": root.optionSwitch("bar.utilButtons.showDarkModeToggle"),
        "bar:Performance Profile": root.optionSwitch("bar.utilButtons.showPerformanceProfileToggle"),
        "bar:Record Screen": root.optionSwitch("bar.utilButtons.showScreenRecord"),
        "bar:Wallpapers Toggle": root.optionSwitch("bar.utilButtons.showWallpaperToggle"),
        "bar:Always show numbers": root.optionSwitch("bar.workspaces.alwaysShowNumbers"),
        "bar:Show app icons": root.optionSwitch("bar.workspaces.showAppIcons"),
        "bar:CPU": root.optionSwitch("bar.resources.alwaysShowCpu"),
        "bar:CPU Temperature": root.optionSwitch("bar.resources.alwaysShowCpuTemp"),
        "bar:RAM": root.optionSwitch("bar.resources.alwaysShowRam"),
        "bar:Disk": root.optionSwitch("bar.resources.alwaysShowDisk"),
        "bar:Swap": root.optionSwitch("bar.resources.alwaysShowSwap"),
        "bar:Show Percentage": root.optionSwitch("bar.resources.showValue"),
        "bar:Pin media controls": root.optionSwitch("bar.media.alwaysVisible"),
        "bar:Show only title": root.optionSwitch("bar.media.onlyTitle"),
        "bar:Tooltips/Enable": root.optionSwitch("bar.tooltips.enable"),
        "bar:Click to show": root.optionSwitch("bar.tooltips.clickToShow"),
        "bar:Tooltips/Style": root.optionSelect("bar.tooltips.style", [
            { displayName: Translation.tr("Default"), icon: "tooltip", value: "default" },
            { displayName: Translation.tr("Morph"), icon: "join_inner", value: "morph" }
        ]),
        "bar:Show Frame": root.toggle(
            () => Config.options.bar.showFrame,
            value => {
                if (value) GlobalStates.refreshBar();
                Config.options.bar.showFrame = value;
            }
        ),
        "bar:Frame thickness": root.optionSpin("bar.frameThickness", 2, 10, 1),
        "bar:Timeout duration (if not defined by notification) (ms)": root.optionSpin("notifications.timeout", 1000, 60000, 1000),
        "bar:Space width (px)": root.optionSpin("bar.divider.spacing", 4, 400, 2),
        "bar:Workspaces shown": root.optionSpin("bar.workspaces.shown", 1, 30, 1),
        "bar:Polling interval (ms)": root.optionSpin("resources.updateInterval", 100, 10000, 100),
        "bar:Max media width": root.optionSpin("bar.media.maxWidth", 100, 500, 10),
        "bar:Group style": Object.assign(root.optionSelect("bar.borderless", [
            { displayName: Translation.tr(""), icon: "block", value: "transparent" },
            { displayName: Translation.tr("Pills"), icon: "pill", value: "pills" },
            { displayName: Translation.tr("Separated"), icon: "view_column_2", value: "separated" },
            { displayName: Translation.tr("Segmented"), icon: "tablet", value: "segmented" }
        ]), {
            canReset: () => (Config.options.bar.widgetStyles ?? []).length > 0,
            reset: () => { Config.options.bar.widgetStyles = []; }
        }),
        "bar:Autohide": root.optionSelect("bar.autoHide.enable", [
            { displayName: Translation.tr("No"), icon: "close", value: false },
            { displayName: Translation.tr("Yes"), icon: "check", value: true }
        ]),
        "bar:Left widget": root.optionSelect("bar.dynamicIsland.leftWidget", [
            { displayName: Translation.tr(""), icon: "block", value: "none" },
            { displayName: Translation.tr("Clock"), icon: "schedule", value: "clockWidget" },
            { displayName: Translation.tr("Weather"), icon: "partly_cloudy_day", value: "weatherBar" },
            { displayName: Translation.tr("Updates"), icon: "update", value: "updatesCount" }
        ]),
        "bar:Right widget": root.optionSelect("bar.dynamicIsland.rightWidget", [
            { displayName: Translation.tr(""), icon: "block", value: "none" },
            { displayName: Translation.tr("System icons"), icon: "settings", value: "systemIcons" },
            { displayName: Translation.tr("Tray"), icon: "apps", value: "sysTray" },
            { displayName: Translation.tr("Util buttons"), icon: "widgets", value: "utilButtons" }
        ]),
        "bar:Visualizer style": root.optionSelect("bar.dynamicIsland.visualizerStyle", [
            { displayName: Translation.tr(""), icon: "block", value: "none" },
            { displayName: Translation.tr("Dots"), icon: "steppers", value: "dots" },
            { displayName: Translation.tr("Wave"), icon: "ssid_chart", value: "wave" }
        ]),
        "bar:Divider/Style": root.optionSelect("bar.divider.style", [
            { displayName: Translation.tr("Line"), icon: "more_vert", value: "rect" },
            { displayName: Translation.tr("Dot"), icon: "fiber_manual_record", value: "dot" },
            { displayName: Translation.tr("Space"), icon: "space_bar", value: "space" }
        ]),
        "bar:Indicator style": root.optionSelect("bar.workspaces.indicatorStyle", [
            { displayName: Translation.tr("Dots"), icon: "radio_button_checked", value: "dot" },
            { displayName: Translation.tr("Icons"), icon: "interests", value: "icon" }
        ]),
        "bar:Battery/Style": root.optionSelect("bar.battery.style", [
            { displayName: "Android", icon: "battery_android_full", value: "bar" },
            { displayName: Translation.tr("Ring"), icon: "donut_large", value: "ring" },
            { displayName: Translation.tr("Icon"), icon: "battery_android_6", value: "icon" },
            { displayName: Translation.tr("Number"), icon: "pin", value: "number" },
            { displayName: "iOS", icon: "tablet_mac", value: "ios" },
            { displayName: "macOS", icon: "laptop_mac", value: "macos" },
            { displayName: "Windows", icon: "desktop_windows", value: "windows" }
        ]),
        "bar:Battery/Show percentage": root.optionSwitch("bar.battery.showPercentage"),
        "bar:Battery/Show charging": root.optionSwitch("bar.battery.showCharging"),
        "interface:Dock/Magnify": root.optionSwitch("dock.magnify"),
        "interface:Dock/Magnification": root.optionScaledSpin("dock.magnification", 110, 220, 10, 100),
        "bar:Resources/Style": root.optionSelect("bar.resources.style", [
            { displayName: Translation.tr("Filled"), icon: "incomplete_circle", value: "filled" },
            { displayName: Translation.tr("Outline"), icon: "circles", value: "outline" },
            { displayName: Translation.tr("Text"), icon: "text_fields", value: "text" }
        ]),
        "bar:Bar position": root.select(
            () => (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0),
            value => {
                Config.options.bar.bottom = (value & 1) !== 0;
                Config.options.bar.vertical = (value & 2) !== 0;
            },
            [
                { displayName: Translation.tr("Top"),    icon: "arrow_upward",   value: 0 },
                { displayName: Translation.tr("Left"),   icon: "arrow_back",     value: 2 },
                { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                { displayName: Translation.tr("Right"),  icon: "arrow_forward",  value: 3 }
            ]
        ),
        "bar:Numbers style": root.select(
            () => JSON.stringify(Config.options.bar.workspaces.numberMap),
            value => { Config.options.bar.workspaces.numberMap = JSON.parse(value); },
            [
                { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                { displayName: Translation.tr("Han chars"), icon: "glyphs",          value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
            ]
        ),


        "general:Format": root.select(
            () => Config.options.time.format,
            value => {
                const hyprlock = FileUtils.trimFileProtocol(Directories.config) + "/hypr/hyprlock.conf";
                const expression = value === "hh:mm" ? "s/\\TIME12\\b/TIME/" : "s/\\TIME\\b/TIME12/";
                Quickshell.execDetached(["sed", "-i", expression, hyprlock]);
                Config.options.time.format = value;
            },
            [
                { displayName: Translation.tr("24h"),       value: "hh:mm"   },
                { displayName: Translation.tr("12h am/pm"), value: "h:mm ap" },
                { displayName: Translation.tr("12h AM/PM"), value: "h:mm AP" }
            ]
        ),
        "general:Second precision": root.toggle(() => Config.options.time.secondPrecision, v => Config.options.time.secondPrecision = v),
        "general:Show date": root.toggle(() => Config.options.time.showDate, v => Config.options.time.showDate = v),
        "general:Low warning": root.spin(() => Config.options.battery.low, v => Config.options.battery.low = v, 0, 100, 5),
        "general:Critical warning": root.spin(() => Config.options.battery.critical, v => Config.options.battery.critical = v, 0, 100, 5),
        "general:Automatic suspend": root.toggle(() => Config.options.battery.automaticSuspend, v => Config.options.battery.automaticSuspend = v),
        "general:Full warning": root.spin(() => Config.options.battery.full, v => Config.options.battery.full = v, 0, 101, 5),
        "general:Earbang protection": root.toggle(() => Config.options.audio.protection.enable, v => Config.options.audio.protection.enable = v),
        "general:Max allowed increase": root.spin(() => Config.options.audio.protection.maxAllowedIncrease, v => Config.options.audio.protection.maxAllowedIncrease = v, 0, 100, 2),
        "general:Volume limit": root.spin(() => Config.options.audio.protection.maxAllowed, v => Config.options.audio.protection.maxAllowed = v, 0, 154, 2),
        "general:Sounds/Battery": root.toggle(() => Config.options.sounds.battery, v => Config.options.sounds.battery = v),
        "general:Sounds/Pomodoro": root.toggle(() => Config.options.sounds.pomodoro, v => Config.options.sounds.pomodoro = v),
        "general:Hide clipboard images copied from sussy sources": root.toggle(() => Config.options.workSafety.enable.clipboard, v => Config.options.workSafety.enable.clipboard = v),
        "general:Hide sussy/anime wallpapers": root.toggle(() => Config.options.workSafety.enable.wallpaper, v => Config.options.workSafety.enable.wallpaper = v),

        "services:Use Levenshtein distance-based algorithm instead of fuzzy": root.toggle(() => Config.options.search.sloppy, v => Config.options.search.sloppy = v),
        "services:Show clipboard preview popups": root.optionSwitch("search.clipboardPreviewPopup"),
        "services:Enable update checks": root.toggle(() => Config.options.updates.enableCheck, v => Config.options.updates.enableCheck = v),
        "services:Enable GPS based location": root.toggle(() => Config.options.bar.weather.enableGPS, v => Config.options.bar.weather.enableGPS = v),
        "services:Fahrenheit unit": root.toggle(() => Config.options.bar.weather.useUSCS, v => Config.options.bar.weather.useUSCS = v),

        "services:Total duration timeout (s)": root.spin(() => Config.options.musicRecognition.timeout, v => Config.options.musicRecognition.timeout = v, 10, 100, 2),
        "services:Polling interval (s)": root.spin(() => Config.options.musicRecognition.interval, v => Config.options.musicRecognition.interval = v, 2, 10, 1),
        "services:Check interval (mins)": root.spin(() => Config.options.updates.checkInterval, v => Config.options.updates.checkInterval = v, 60, 1440, 60),
        "services:Polling interval (m)": root.spin(() => Config.options.bar.weather.fetchInterval, v => Config.options.bar.weather.fetchInterval = v, 5, 50, 5),

        "hyprland:Numlock by default": hyprSwitch(() => root.hypr.input.numlock, v => root.hypr.input.numlock = v, "input:numlock_by_default"),
        "hyprland:Natural scroll": hyprSwitch(() => root.hypr.input.touchpad.naturalScroll, v => root.hypr.input.touchpad.naturalScroll = v, "input:touchpad:natural_scroll"),
        "hyprland:Disable while typing": hyprSwitch(() => root.hypr.input.touchpad.disableWhileTyping, v => root.hypr.input.touchpad.disableWhileTyping = v, "input:touchpad:disable_while_typing"),
        "hyprland:Clickfinger behavior": hyprSwitch(() => root.hypr.input.touchpad.clickfingerBehavior, v => root.hypr.input.touchpad.clickfingerBehavior = v, "input:touchpad:clickfinger_behavior"),
        "hyprland:Blur": hyprSwitch(() => root.hypr.decoration.blur.enabled, v => root.hypr.decoration.blur.enabled = v, "decoration:blur:enabled"),
        "hyprland:Focus on activate": hyprSwitch(() => root.hypr.misc.focusOnActivate, v => root.hypr.misc.focusOnActivate = v, "misc:focus_on_activate"),
        "hyprland:Enable": hyprSwitch(() => root.hypr.animations.enable, v => root.hypr.animations.enable = v, "animations:enabled"),
        "hyprland:Custom border colors": root.toggle(
            () => root.hypr.general.borderColor.enable,
            value => {
                root.hypr.general.borderColor.enable = value;
                if (value) HyprlandConfig.applyBorderColors();
                else HyprlandConfig.resetBorderColors();
            }
        ),

        "hyprland:Repeat delay (ms)": hyprSpin(() => root.hypr.input.repeatDelay, v => root.hypr.input.repeatDelay = v, "input:repeat_delay", 100, 1000, 10),
        "hyprland:Repeat rate": hyprSpin(() => root.hypr.input.repeatRate, v => root.hypr.input.repeatRate = v, "input:repeat_rate", 10, 100, 1),
        "hyprland:Scroll factor": hyprSpin(() => root.hypr.input.touchpad.scrollFactor, v => root.hypr.input.touchpad.scrollFactor = v, "input:touchpad:scroll_factor", 1, 30, 1, 10),
        "hyprland:Window Rounding": hyprSpin(() => root.hypr.decoration.rounding, v => root.hypr.decoration.rounding = v, "decoration:rounding", 0, 30, 1),
        "hyprland:Blur Size": hyprSpin(() => root.hypr.decoration.blur.size, v => root.hypr.decoration.blur.size = v, "decoration:blur:size", 1, 20, 1),
        "hyprland:Blur Passes": hyprSpin(() => root.hypr.decoration.blur.passes, v => root.hypr.decoration.blur.passes = v, "decoration:blur:passes", 1, 6, 1),
        "hyprland:Gaps In": hyprSpin(() => root.hypr.general.gapsIn, v => root.hypr.general.gapsIn = v, "general:gaps_in", 0, 40, 1),
        "hyprland:Gaps Out": hyprSpin(() => root.hypr.general.gapsOut, v => root.hypr.general.gapsOut = v, "general:gaps_out", 0, 60, 1),
        "hyprland:Active Opacity": hyprSpin(() => root.hypr.decoration.activeOpacity, v => root.hypr.decoration.activeOpacity = v, "decoration:active_opacity", 10, 100, 5, 100),
        "hyprland:Inactive Opacity": hyprSpin(() => root.hypr.decoration.inactiveOpacity, v => root.hypr.decoration.inactiveOpacity = v, "decoration:inactive_opacity", 10, 100, 5, 100),
        "hyprland:Border Size": hyprSpin(() => root.hypr.general.borderSize, v => root.hypr.general.borderSize = v, "general:border_size", 0, 10, 1),

        "hyprland:Tiling Layout": root.select(
            () => root.hypr.general.layout,
            value => {
                root.hypr.general.layout = value;
                HyprlandConfig.set("general:layout", value);
            },
            [
                { displayName: Translation.tr("Dwindle"),   icon: "browse",              value: "dwindle"   },
                { displayName: Translation.tr("Master"),    icon: "auto_awesome_mosaic", value: "master"    },
                { displayName: Translation.tr("Scrolling"), icon: "view_carousel",       value: "scrolling" }
            ]
        ),
        "hyprland:Follow mouse": root.select(
            () => root.hypr.input.followMouse,
            value => {
                root.hypr.input.followMouse = value;
                HyprlandConfig.set("input:follow_mouse", value);
            },
            [
                { displayName: Translation.tr("Disabled"), icon: "mouse",    value: 0 },
                { displayName: Translation.tr("Full"),     icon: "open_with", value: 1 },
                { displayName: Translation.tr("Loose"),    icon: "drag_pan",  value: 2 },
                { displayName: Translation.tr("Explicit"), icon: "ads_click", value: 3 }
            ]
        ),
        "hyprland:Presets": root.select(
            () => root.hypr.animations.animation,
            value => {
                root.hypr.animations.animation = value;
                Quickshell.execDetached(["python3", HyprlandConfig.configuratorScriptPath, "--anim-preset", value]);
            },
            [
                { displayName: Translation.tr("Elastic"),   icon: "move_selection_right", value: "fast"   },
                { displayName: Translation.tr("Normal"),    icon: "animation",            value: "normal" },
                { displayName: Translation.tr("Niri Like"), icon: "mobiledata_arrows",    value: "niri"   }
            ]
        )
    })

    function find(pageId, rawSection, rawSubsection, rawLabel) {
        return root.controls[pageId + ":" + rawSection + "/" + rawSubsection + "/" + rawLabel]
            ?? root.controls[pageId + ":" + rawSection + "/" + rawLabel]
            ?? root.controls[pageId + ":" + rawLabel]
            ?? null;
    }
}
