import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common

QtObject {
    function hyprToggle(key) {
        return { type: "switch", get: () => Boolean(HyprlandOptions.get(key, false)), set: v => HyprlandOptions.apply(key, v) };
    }

    function hyprSelect(key, fallback, options) {
        return { type: "select", get: () => HyprlandOptions.get(key, fallback), set: v => HyprlandOptions.apply(key, v), options: options };
    }

    function hyprSpin(key, from, to, stepSize, factor, fallback) {
        return {
            type: "spin",
            get: () => Math.round(Number(HyprlandOptions.get(key, fallback)) * factor),
            set: v => HyprlandOptions.apply(key, v / factor),
            from: from, to: to, stepSize: stepSize
        };
    }

    function hyprText(key) {
        return { type: "text", get: () => String(HyprlandOptions.get(key, "")), set: v => HyprlandOptions.apply(key, v) };
    }

    function roleColor(name) {
        if (name === "black") return "black";
        return Appearance.colors["col" + name.charAt(0).toUpperCase() + name.slice(1)] ?? Appearance.getColorFromName(name);
    }

    function controlFor(key) {
        return custom[key] ?? hyprControls[key] ?? null;
    }

    readonly property var hyprControls: ({
        "hyprland:opt:dwindle:preserve_split": hyprToggle("dwindle:preserve_split"),
        "hyprland:opt:dwindle:smart_split": hyprToggle("dwindle:smart_split"),
        "hyprland:opt:dwindle:force_split": hyprSelect("dwindle:force_split", 0, [{ displayName: Translation.tr("Auto"), icon: "auto_mode", value: 0 }, { displayName: Translation.tr("Left / top"), icon: "align_horizontal_left", value: 1 }, { displayName: Translation.tr("Right / bottom"), icon: "align_horizontal_right", value: 2 }]),
        "hyprland:opt:dwindle:default_split_ratio": hyprSpin("dwindle:default_split_ratio", 2, 18, 1, 10, 0),
        "hyprland:opt:master:new_status": hyprSelect("master:new_status", "slave", [{ displayName: Translation.tr("Master"), icon: "star", value: "master" }, { displayName: Translation.tr("Slave"), icon: "view_agenda", value: "slave" }, { displayName: Translation.tr("Inherit"), icon: "content_copy", value: "inherit" }]),
        "hyprland:opt:master:orientation": hyprSelect("master:orientation", "left", [{ displayName: Translation.tr("Left"), icon: "align_horizontal_left", value: "left" }, { displayName: Translation.tr("Right"), icon: "align_horizontal_right", value: "right" }, { displayName: Translation.tr("Top"), icon: "align_vertical_top", value: "top" }, { displayName: Translation.tr("Bottom"), icon: "align_vertical_bottom", value: "bottom" }, { displayName: Translation.tr("Center"), icon: "align_horizontal_center", value: "center" }]),
        "hyprland:opt:master:mfact": hyprSpin("master:mfact", 10, 90, 5, 100, 0),
        "hyprland:opt:input:kb_variant": hyprText("input:kb_variant"),
        "hyprland:opt:input:kb_options": hyprText("input:kb_options"),
        "hyprland:opt:input:sensitivity": hyprSpin("input:sensitivity", -10, 10, 1, 10, 0),
        "hyprland:opt:input:accel_profile": hyprSelect("input:accel_profile", "", [{ displayName: Translation.tr("Default"), icon: "settings_backup_restore", value: "" }, { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" }, { displayName: Translation.tr("Adaptive"), icon: "show_chart", value: "adaptive" }]),
        "hyprland:opt:input:force_no_accel": hyprToggle("input:force_no_accel"),
        "hyprland:opt:input:left_handed": hyprToggle("input:left_handed"),
        "hyprland:opt:misc:middle_click_paste": hyprToggle("misc:middle_click_paste"),
        "hyprland:opt:input:touchpad:tap-to-click": hyprToggle("input:touchpad:tap-to-click"),
        "hyprland:opt:input:touchpad:tap-and-drag": hyprToggle("input:touchpad:tap-and-drag"),
        "hyprland:opt:input:touchpad:middle_button_emulation": hyprToggle("input:touchpad:middle_button_emulation"),
        "hyprland:opt:decoration:shadow:enabled": hyprToggle("decoration:shadow:enabled"),
        "hyprland:opt:decoration:shadow:range": hyprSpin("decoration:shadow:range", 0, 50, 1, 1, 0),
        "hyprland:opt:decoration:dim_inactive": hyprToggle("decoration:dim_inactive"),
        "hyprland:opt:decoration:dim_strength": hyprSpin("decoration:dim_strength", 0, 100, 5, 100, 0),
        "hyprland:opt:decoration:blur:noise": hyprSpin("decoration:blur:noise", 0, 50, 1, 100, 0),
        "hyprland:opt:decoration:blur:vibrancy": hyprSpin("decoration:blur:vibrancy", 0, 100, 5, 100, 0),
        "hyprland:opt:misc:vrr": hyprSelect("misc:vrr", 0, [{ displayName: Translation.tr("Off"), icon: "block", value: 0 }, { displayName: Translation.tr("On"), icon: "check_circle", value: 1 }, { displayName: Translation.tr("Fullscreen only"), icon: "fullscreen", value: 2 }]),
        "hyprland:opt:misc:enable_swallow": hyprToggle("misc:enable_swallow"),
        "hyprland:opt:misc:animate_manual_resizes": hyprToggle("misc:animate_manual_resizes"),
        "hyprland:opt:misc:close_special_on_empty": hyprToggle("misc:close_special_on_empty"),
        "hyprland:opt:misc:disable_hyprland_logo": hyprToggle("misc:disable_hyprland_logo"),
        "hyprland:opt:misc:disable_splash_rendering": hyprToggle("misc:disable_splash_rendering"),
        "hyprland:opt:misc:mouse_move_enables_dpms": hyprToggle("misc:mouse_move_enables_dpms"),
        "hyprland:opt:misc:key_press_enables_dpms": hyprToggle("misc:key_press_enables_dpms"),
        "hyprland:opt:xwayland:force_zero_scaling": hyprToggle("xwayland:force_zero_scaling"),
        "hyprland:opt:group:auto_group": hyprToggle("group:auto_group"),
        "hyprland:opt:binds:workspace_back_and_forth": hyprToggle("binds:workspace_back_and_forth"),
        "hyprland:opt:binds:allow_workspace_cycles": hyprToggle("binds:allow_workspace_cycles"),
        "hyprland:opt:render:direct_scanout": hyprSelect("render:direct_scanout", 0, [{ displayName: Translation.tr("Off"), icon: "block", value: 0 }, { displayName: Translation.tr("On"), icon: "check_circle", value: 1 }, { displayName: Translation.tr("Auto"), icon: "auto_mode", value: 2 }]),
        "hyprland:opt:general:resize_on_border": hyprToggle("general:resize_on_border"),
        "hyprland:opt:general:extend_border_grab_area": hyprSpin("general:extend_border_grab_area", 0, 60, 1, 1, 0),
        "hyprland:opt:general:allow_tearing": hyprToggle("general:allow_tearing"),
        "hyprland:opt:cursor:no_hardware_cursors": hyprSelect("cursor:no_hardware_cursors", 2, [{ displayName: Translation.tr("Auto"), icon: "auto_mode", value: 2 }, { displayName: Translation.tr("On"), icon: "check_circle", value: 0 }, { displayName: Translation.tr("Off"), icon: "block", value: 1 }]),
        "hyprland:opt:cursor:inactive_timeout": hyprSpin("cursor:inactive_timeout", 0, 60, 1, 1, 0),
        "hyprland:opt:cursor:hide_on_key_press": hyprToggle("cursor:hide_on_key_press"),
        "hyprland:opt:cursor:warp_on_change_workspace": hyprSelect("cursor:warp_on_change_workspace", 0, [{ displayName: Translation.tr("Off"), icon: "block", value: 0 }, { displayName: Translation.tr("On"), icon: "check_circle", value: 1 }, { displayName: Translation.tr("Force"), icon: "bolt", value: 2 }]),
    })

    readonly property var custom: ({
        "bar:Bar style": { type: "select", get: () => Config.options.bar.cornerStyle, set: v => { Config.options.bar.cornerStyle = v; }, options: [{ displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 }, { displayName: Translation.tr("Split Hug"), icon: "splitscreen", value: 6 }, { displayName: Translation.tr("Float"), icon: "view_day", value: 1 }, { displayName: Translation.tr("Islands"), icon: "crop_3_2", value: 2 }, { displayName: Translation.tr("M3"), icon: "interests", value: 3 }, { displayName: Translation.tr("M3 Hug"), icon: "category", value: 4 }, { displayName: Translation.tr("Panel"), icon: "toolbar", value: 5 }] },
        "bar:Group color": { type: "select", get: () => Config.options.bar.groupColor, set: v => { Config.options.bar.groupColor = v; }, get options() { return ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"].map(name => ({ value: name, color: roleColor(name) })); } },
        "bar:Frame color": { type: "select", get: () => Config.options.bar.frameColor, set: v => { Config.options.bar.frameColor = v; }, get options() { return ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"].map(name => ({ value: name, color: roleColor(name) })); } },
        "bar:Screen rounded corners": { type: "select", get: () => Config.options.appearance.fakeScreenRounding, set: v => { Config.options.appearance.fakeScreenRounding = v; }, options: [{ displayName: Translation.tr("No"), icon: "close", value: 0 }, { displayName: Translation.tr("Yes"), icon: "check", value: 1 }, { displayName: Translation.tr("When not fullscreen"), icon: "fullscreen_exit", value: 2 }] },
        "bar:Workspaces style": { type: "select", get: () => Config.options.bar.workspaces.style, set: v => { Config.options.bar.workspaces.style = v; }, options: [{ displayName: Translation.tr("Default"), icon: "view_carousel", value: "default" }, { displayName: Translation.tr("GNOME"), icon: "more_horiz", value: "gnome" }, { displayName: Translation.tr("Dots"), icon: "hdr_weak", value: "dots" }, { displayName: Translation.tr("Ticks"), icon: "more_vert", value: "ticks" }] },
        "bar:Notification position": { type: "select", get: () => Config.options.notifications.position, set: v => { Config.options.notifications.position = v; }, options: [{ displayName: Translation.tr("Top left"), icon: "north_west", value: "top_left" }, { displayName: Translation.tr("Top center"), icon: "north", value: "top_center" }, { displayName: Translation.tr("Top right"), icon: "north_east", value: "top_right" }, { displayName: Translation.tr("Bottom left"), icon: "south_west", value: "bottom_left" }, { displayName: Translation.tr("Bottom center"), icon: "south", value: "bottom_center" }, { displayName: Translation.tr("Bottom right"), icon: "south_east", value: "bottom_right" }] },
        "bar:Colorize icon": { type: "switch", get: () => Config.options.custom.colorizeIcon, set: v => { Config.options.custom.colorizeIcon = v; } },
        "bar:Icon color": { type: "select", get: () => Config.options.custom.iconColor, set: v => { Config.options.custom.iconColor = v; }, get options() { return ["onLayer0", "primary", "secondary", "tertiary", "onPrimaryContainer", "onSecondaryContainer", "onTertiaryContainer"].map(name => ({ value: name, color: roleColor(name) })); } },
        "bar:Icons folder": { type: "text", get: () => Config.options.custom.iconsPath, set: v => { Config.options.custom.iconsPath = v; } },
        "bar:Preferred player": { type: "text", get: () => Config.options.bar.media.preferredPlayer, set: v => { Config.options.bar.media.preferredPlayer = v; } },
        "hyprland:Active border color": { type: "select", get: () => Config.options.hyprland.general.borderColor.activeRole, set: v => { Config.options.hyprland.general.borderColor.activeRole = v; HyprlandConfig.applyBorderColors(); }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"].map(name => ({ value: name, color: roleColor(name) })); } },
        "hyprland:Active border opacity": { type: "spin", get: () => Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100), set: v => { Config.options.hyprland.general.borderColor.activeOpacity = v / 100.0; HyprlandConfig.applyBorderColors(); }, from: 0, to: 100, stepSize: 5 },
        "hyprland:Inactive border color": { type: "select", get: () => Config.options.hyprland.general.borderColor.inactiveRole, set: v => { Config.options.hyprland.general.borderColor.inactiveRole = v; HyprlandConfig.applyBorderColors(); }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"].map(name => ({ value: name, color: roleColor(name) })); } },
        "hyprland:Inactive border opacity": { type: "spin", get: () => Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100), set: v => { Config.options.hyprland.general.borderColor.inactiveOpacity = v / 100.0; HyprlandConfig.applyBorderColors(); }, from: 0, to: 100, stepSize: 5 },
        "hyprland:Idle lock": { type: "duration", get: () => Config.options.hyprland.idle.lock, set: v => { Config.options.hyprland.idle.lock = v; HyprlandConfig.setIdle(Config.options.hyprland.idle.lock, Config.options.hyprland.idle.screenOff, Config.options.hyprland.idle.suspend); } },
        "hyprland:Idle screen off": { type: "duration", get: () => Config.options.hyprland.idle.screenOff, set: v => { Config.options.hyprland.idle.screenOff = v; HyprlandConfig.setIdle(Config.options.hyprland.idle.lock, Config.options.hyprland.idle.screenOff, Config.options.hyprland.idle.suspend); } },
        "hyprland:Idle standby": { type: "duration", get: () => Config.options.hyprland.idle.suspend, set: v => { Config.options.hyprland.idle.suspend = v; HyprlandConfig.setIdle(Config.options.hyprland.idle.lock, Config.options.hyprland.idle.screenOff, Config.options.hyprland.idle.suspend); } },
        "interface:Dock/Style": { type: "select", get: () => Config.options.dock.style, set: v => { Config.options.dock.style = v; }, options: [{ displayName: Translation.tr("Float"), icon: "call_to_action", value: "float" }, { displayName: Translation.tr("Hug"), icon: "dock_to_bottom", value: "hug" }] },
        "interface:Dock/Position": { type: "select", get: () => Config.options.dock.position, set: v => { Config.options.dock.position = v; }, options: [{ displayName: Translation.tr("Left"), icon: "dock_to_left", value: "left" }, { displayName: Translation.tr("Bottom"), icon: "dock_to_bottom", value: "bottom" }, { displayName: Translation.tr("Right"), icon: "dock_to_right", value: "right" }] },
        "interface:Dock/Previews": { type: "switch", get: () => Config.options.dock.showPreviews, set: v => { Config.options.dock.showPreviews = v; } },
        "interface:Dock/Icon size": { type: "spin", get: () => Config.options.dock.iconSize, set: v => { Config.options.dock.iconSize = v; }, from: 20, to: 48, stepSize: 1 },
        "interface:Dock/Icon spacing": { type: "spin", get: () => Config.options.dock.iconSpacing, set: v => { Config.options.dock.iconSpacing = v; }, from: 0, to: 12, stepSize: 1 },
        "interface:Dock/Radius": { type: "spin", get: () => Config.options.dock.radius, set: v => { Config.options.dock.radius = v; }, from: 0, to: 40, stepSize: 1 },
        "interface:Dock/Background color": { type: "select", get: () => Config.options.dock.backgroundColor, set: v => { Config.options.dock.backgroundColor = v; }, get options() { return ["layer0", "layer1", "primaryContainer", "secondaryContainer", "tertiaryContainer", "primary", "secondary", "tertiary", "black"].map(name => ({ value: name, color: roleColor(name) })); } },
        "interface:Dock/Follow frame color": { type: "switch", get: () => Config.options.dock.followFrameColor, set: v => { Config.options.dock.followFrameColor = v; } },
        "interface:Dock/Border": { type: "switch", get: () => Config.options.dock.showBorder, set: v => { Config.options.dock.showBorder = v; } },
        "interface:Dock/Border width": { type: "spin", get: () => Config.options.dock.borderWidth, set: v => { Config.options.dock.borderWidth = v; }, from: 1, to: 10, stepSize: 1 },
        "interface:Dock/Border color": { type: "select", get: () => Config.options.dock.borderColor, set: v => { Config.options.dock.borderColor = v; }, get options() { return ["layer0Border", "primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "black"].map(name => ({ value: name, color: roleColor(name) })); } },
        "interface:UI background": { type: "select", get: () => Config.options.appearance.uiBackground, set: v => { Config.options.appearance.uiBackground = v; }, options: [{ displayName: Translation.tr("Themed"), icon: "palette", value: "themed" }, { displayName: "OLED", icon: "contrast", value: "oled" }] },
        "interface:Palette type": { type: "select", get: () => Config.options.appearance.palette.type, set: v => { Config.options.appearance.palette.type = v; Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]); }, options: [{ displayName: Translation.tr("Auto"), icon: "auto_awesome", value: "auto" }, { displayName: Translation.tr("Content"), icon: "image", value: "scheme-content" }, { displayName: Translation.tr("Expressive"), icon: "palette", value: "scheme-expressive" }, { displayName: Translation.tr("Fidelity"), icon: "equal", value: "scheme-fidelity" }, { displayName: Translation.tr("Fruit Salad"), icon: "nutrition", value: "scheme-fruit-salad" }, { displayName: Translation.tr("Monochrome"), icon: "invert_colors", value: "scheme-monochrome" }, { displayName: Translation.tr("Neutral"), icon: "tonality", value: "scheme-neutral" }, { displayName: Translation.tr("Rainbow"), icon: "gradient", value: "scheme-rainbow" }, { displayName: Translation.tr("Tonal Spot"), icon: "lens", value: "scheme-tonal-spot" }] },
        "desktop:Same wallpaper": { type: "switch", get: () => Config.options.background.lockWall === "", set: v => { if (v) Config.options.background.lockWall = ""; } },
        "desktop:Transitions": { type: "select", get: () => Config.options.background.wallpaperAnimation, set: v => { Config.options.background.wallpaperAnimation = v; }, options: [{ displayName: Translation.tr("None"), icon: "block", value: "" }, { displayName: Translation.tr("Circle"), icon: "circle", value: "circleSelect" }, { displayName: Translation.tr("Circle Pit"), icon: "blur_circular", value: "circlePit" }, { displayName: Translation.tr("Magic"), icon: "auto_awesome", value: "magic" }, { displayName: Translation.tr("Doom"), icon: "whatshot", value: "Doom" }, { displayName: Translation.tr("Peel"), icon: "layers", value: "Peel" }, { displayName: Translation.tr("Fade"), icon: "gradient", value: "transition" }, { displayName: Translation.tr("Pixelate"), icon: "grain", value: "pixelate" }, { displayName: Translation.tr("Stripes"), icon: "texture_minus", value: "stripes" }, { displayName: Translation.tr("CRT"), icon: "tv", value: "crt" }, { displayName: Translation.tr("Dissolve"), icon: "blur_on", value: "dissolve" }, { displayName: Translation.tr("Glitch"), icon: "bug_report", value: "glitch" }, { displayName: Translation.tr("Ripple"), icon: "water", value: "ripple" }, { displayName: Translation.tr("Shatter"), icon: "broken_image", value: "shatter" }, { displayName: Translation.tr("Random"), icon: "shuffle", value: "random" }] },
        "desktop:Centered shape": { type: "select", get: () => Config.options.background.centeredWallpaperShape, set: v => { Config.options.background.centeredWallpaperShape = v; }, options: ["Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill", "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"] },
        "desktop:Image shape": { type: "select", get: () => Config.options.background.widgets.customImage.shape, set: v => { Config.options.background.widgets.customImage.shape = v; }, options: ["Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill", "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"] },
        "desktop:Image card layout": { type: "select", get: () => Config.options.background.widgets.imageCard.sizeMode, set: v => { Config.options.background.widgets.imageCard.sizeMode = v; }, options: [ { displayName: "1x1", icon: "crop_square", value: "1x1" }, { displayName: "1x2", icon: "crop_landscape", value: "1x2" }, { displayName: "1x3", icon: "crop_16_9", value: "1x3" }, { displayName: "2x2", icon: "grid_view", value: "2x2" }, { displayName: "2x3", icon: "view_module", value: "2x3" }] },
        "desktop:Centered color": { type: "select", get: () => Config.options.background.centeredWallpaperColor, set: v => { Config.options.background.centeredWallpaperColor = v; }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"].map(name => ({ value: name, color: Appearance.getColorFromName(name) })); } },
        "desktop:Collage enable": { type: "switch", get: () => Config.options.background.collage.enable, set: v => { if (v && !Config.options.background.collage.enable) Collage.reset(); Config.options.background.collage.enable = v; } },
        "desktop:Collage gap": { type: "spin", get: () => Config.options.background.collage.gap, set: v => { Config.options.background.collage.gap = v; }, from: 0, to: 80, stepSize: 2 },
        "desktop:Collage margin": { type: "spin", get: () => Config.options.background.collage.margin, set: v => { Config.options.background.collage.margin = v; }, from: 0, to: 120, stepSize: 2 },
        "desktop:Collage radius": { type: "spin", get: () => Config.options.background.collage.radius, set: v => { Config.options.background.collage.radius = v; }, from: 0, to: 80, stepSize: 2 },
        "desktop:Clock auto colors": { type: "switch", get: () => Config.options.background.widgets.clock.color === "", set: v => { Config.options.background.widgets.clock.color = v ? "" : "primary"; } },
        "desktop:Clock color": { type: "select", get: () => Config.options.background.widgets.clock.color, set: v => { Config.options.background.widgets.clock.color = v; }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"].map(name => ({ value: name, color: Appearance.getColorFromName(name) })); } },
        "desktop:Clock font family": { type: "select", get: () => Config.options.background.widgets.clock.digital.font.family, set: v => { Config.options.background.widgets.clock.digital.font.family = v; }, get options() { return SystemAppearance.fontOptions(Config.options.background.widgets.clock.digital.font.family); } },
        "desktop:Minute hand": { type: "select", get: () => Config.options.background.widgets.clock.cookie.minuteHandStyle, set: v => { Config.options.background.widgets.clock.cookie.minuteHandStyle = v; }, options: [{ displayName: "", icon: "block", value: "hide" }, { displayName: Translation.tr("Classic"), icon: "show_chart", value: "classic" }, { displayName: Translation.tr("Thin"), icon: "horizontal_rule", value: "thin" }, { displayName: Translation.tr("Medium"), icon: "remove", value: "medium" }, { displayName: Translation.tr("Bold"), icon: "format_bold", value: "bold" }] },
        "desktop:Quote text": { type: "text", get: () => Config.options.background.widgets.clock.quote.text, set: v => { Config.options.background.widgets.clock.quote.text = v; } },
        "desktop:Visualizer enable": { type: "switch", get: () => Config.options.background.widgets.visualizer.enable, set: v => { Config.options.background.widgets.visualizer.enable = v; } },
        "desktop:Visualizer style": { type: "select", get: () => Config.options.background.widgets.visualizer.style, set: v => { Config.options.background.widgets.visualizer.style = v; }, options: [{ displayName: Translation.tr("Classic"), icon: "equalizer", value: "bars" }, { displayName: Translation.tr("Mirror"), icon: "flip", value: "mirror" }, { displayName: Translation.tr("Aurora"), icon: "auto_awesome", value: "aurora" }, { displayName: Translation.tr("Ring"), icon: "radio_button_unchecked", value: "ring" }, { displayName: Translation.tr("Dots"), icon: "more_horiz", value: "dots" }] },
        "desktop:Visualizer colors": { type: "select", get: () => Config.options.background.widgets.visualizer.colorSource, set: v => { Config.options.background.widgets.visualizer.colorSource = v; }, options: [{ displayName: Translation.tr("Theme"), icon: "palette", value: "theme" }, { displayName: Translation.tr("Album cover"), icon: "album", value: "cover" }] },
        "desktop:Visualizer sensitivity": { type: "slider", get: () => Config.options.background.widgets.visualizer.sensitivity * 100, set: v => { Config.options.background.widgets.visualizer.sensitivity = Math.round(v) / 100; }, from: 50, to: 300, stopIndicatorValues: [], usePercentTooltip: false },
        "desktop:Visualizer height": { type: "slider", get: () => Config.options.background.widgets.visualizer.height, set: v => { Config.options.background.widgets.visualizer.height = Math.round(v); }, from: 120, to: 600, stopIndicatorValues: [], usePercentTooltip: false },
        "desktop:Visualizer size": { type: "slider", get: () => Config.options.background.widgets.visualizer.ringSize, set: v => { Config.options.background.widgets.visualizer.ringSize = Math.round(v); }, from: 200, to: 900, stopIndicatorValues: [], usePercentTooltip: false },
        "desktop:Text enable": { type: "switch", get: () => Config.options.background.widgets.customText.enable, set: v => { Config.options.background.widgets.customText.enable = v; } },
        "desktop:Text shadow": { type: "switch", get: () => Config.options.background.widgets.customText.shadow, set: v => { Config.options.background.widgets.customText.shadow = v; } },
        "desktop:Text auto colors": { type: "switch", get: () => Config.options.background.widgets.customText.color === "", set: v => { Config.options.background.widgets.customText.color = v ? "" : "primary"; } },
        "desktop:Text content": { type: "text", get: () => Config.options.background.widgets.customText.content, set: v => { Config.options.background.widgets.customText.content = v; } },
        "desktop:Text font family": { type: "select", get: () => Config.options.background.widgets.customText.fontFamily, set: v => { Config.options.background.widgets.customText.fontFamily = v; }, get options() { return Fonts.handwritingFamilies.map(family => ({ displayName: family, value: family })); } },
        "desktop:Text custom font": { type: "text", get: () => Fonts.handwritingFamilies.includes(Config.options.background.widgets.customText.fontFamily) ? "" : Config.options.background.widgets.customText.fontFamily, set: v => { Config.options.background.widgets.customText.fontFamily = v; } },
        "desktop:Text size": { type: "slider", get: () => Config.options.background.widgets.customText.fontSize, set: v => { Config.options.background.widgets.customText.fontSize = Math.round(v); }, from: 12, to: 400, stopIndicatorValues: [], usePercentTooltip: false },
        "desktop:Text alignment": { type: "select", get: () => Config.options.background.widgets.customText.alignment, set: v => { Config.options.background.widgets.customText.alignment = v; }, options: [{ displayName: Translation.tr("Left"), icon: "format_align_left", value: "left" }, { displayName: Translation.tr("Center"), icon: "format_align_center", value: "center" }, { displayName: Translation.tr("Right"), icon: "format_align_right", value: "right" }] },
        "desktop:Text color": { type: "select", get: () => Config.options.background.widgets.customText.color, set: v => { Config.options.background.widgets.customText.color = v; }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"].map(name => ({ value: name, color: Appearance.getColorFromName(name) })); } },
        "interface:AI policy": { type: "select", get: () => Config.options.policies.ai, set: v => { Config.options.policies.ai = v; }, options: [{ displayName: Translation.tr("No"), icon: "close", value: 0 }, { displayName: Translation.tr("Yes"), icon: "check", value: 1 }, { displayName: Translation.tr("Local"), icon: "sync_saved_locally", value: 2 }] },
        "interface:Weeb policy": { type: "select", get: () => Config.options.policies.weeb, set: v => { Config.options.policies.weeb = v; }, options: [{ displayName: Translation.tr("No"), icon: "close", value: 0 }, { displayName: Translation.tr("Yes"), icon: "check", value: 1 }, { displayName: Translation.tr("Closet"), icon: "ev_shadow", value: 2 }] },
        "interface:Overview order horizontal": { type: "select", get: () => Config.options.overview.orderRightLeft, set: v => { Config.options.overview.orderRightLeft = v; }, options: [{ displayName: Translation.tr("Left to right"), icon: "arrow_forward", value: 0 }, { displayName: Translation.tr("Right to left"), icon: "arrow_back", value: 1 }] },
        "interface:Overview order vertical": { type: "select", get: () => Config.options.overview.orderBottomUp, set: v => { Config.options.overview.orderBottomUp = v; }, options: [{ displayName: Translation.tr("Top-down"), icon: "arrow_downward", value: 0 }, { displayName: Translation.tr("Bottom-up"), icon: "arrow_upward", value: 1 }] },
        "interface:Hot corner bottom-left": { type: "select", get: () => Config.options.sidebar.cornerOpen.bottomLeftAction, set: v => { Config.options.sidebar.cornerOpen.bottomLeftAction = v; }, get options() { return GlobalStates.hotCornerOptions; } },
        "interface:Hot corner bottom-right": { type: "select", get: () => Config.options.sidebar.cornerOpen.bottomRightAction, set: v => { Config.options.sidebar.cornerOpen.bottomRightAction = v; }, get options() { return GlobalStates.hotCornerOptions; } },
        "interface:Border color": { type: "select", get: () => Config.options.settings.borderColor, set: v => { Config.options.settings.borderColor = v; }, get options() { return ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"].map(name => ({ value: name, color: Appearance.getColorFromName(name) })); } },
        "interface:Floating image source": { type: "text", get: () => Config.options.overlay.floatingImage.imageSource, set: v => { Config.options.overlay.floatingImage.imageSource = v; } },
        "interface:Crosshair code": { type: "text", get: () => Config.options.crosshair.code, set: v => { Config.options.crosshair.code = v; } },
        "interface:Custom wallpaper folder": { type: "text", get: () => Config.options.wallpaperSelector.userPath ?? "", set: v => { Config.options.wallpaperSelector.userPath = v; } },
        "interface:Live wallpaper folder": { type: "text", get: () => Config.options.wallpaperSelector.liveWallpapersPath ?? "", set: v => { Config.options.wallpaperSelector.liveWallpapersPath = v; } },
        "services:Video recording path": { type: "text", get: () => Config.options.screenRecord.savePath, set: v => { Config.options.screenRecord.savePath = v; } },
        "services:Screenshot path": { type: "text", get: () => Config.options.screenSnip.savePath, set: v => { Config.options.screenSnip.savePath = v; } },
        "services:Base URL": { type: "text", get: () => Config.options.search.engineBaseUrl, set: v => { Config.options.search.engineBaseUrl = v; } },
        "services:Prefix action": { type: "text", get: () => Config.options.search.prefix.action, set: v => { Config.options.search.prefix.action = v; } },
        "services:Prefix clipboard": { type: "text", get: () => Config.options.search.prefix.clipboard, set: v => { Config.options.search.prefix.clipboard = v; } },
        "services:Prefix emojis": { type: "text", get: () => Config.options.search.prefix.emojis, set: v => { Config.options.search.prefix.emojis = v; } },
        "services:Prefix symbols": { type: "text", get: () => Config.options.search.prefix.symbols, set: v => { Config.options.search.prefix.symbols = v; } },
        "services:Prefix shell": { type: "text", get: () => Config.options.search.prefix.shellCommand, set: v => { Config.options.search.prefix.shellCommand = v; } },
        "services:Prefix web": { type: "text", get: () => Config.options.search.prefix.webSearch, set: v => { Config.options.search.prefix.webSearch = v; } },
        "services:Prefix app": { type: "text", get: () => Config.options.search.prefix.app, set: v => { Config.options.search.prefix.app = v; } },
        "services:Prefix keybinds": { type: "text", get: () => Config.options.search.prefix.keybinds, set: v => { Config.options.search.prefix.keybinds = v; } },
        "services:City name": { type: "text", get: () => Config.options.bar.weather.city, set: v => { Config.options.bar.weather.city = v; } },
        "general:Icon theme": { type: "select", get: () => SystemAppearance.iconTheme, set: v => SystemAppearance.setIcons(v), get options() { return SystemAppearance.toOptions(SystemAppearance.iconThemes); } },
        "general:Cursor theme": { type: "select", get: () => SystemAppearance.cursorTheme, set: v => SystemAppearance.setCursor(v, SystemAppearance.cursorSize), get options() { return SystemAppearance.toOptions(SystemAppearance.cursorThemes); } },
        "general:System font": { type: "select", get: () => SystemAppearance.fontFamily, set: v => SystemAppearance.setFont("ui", v, SystemAppearance.fontSize), get options() { return SystemAppearance.toOptions(SystemAppearance.fonts); } },
        "general:Monospace font": { type: "select", get: () => SystemAppearance.monoFamily, set: v => SystemAppearance.setFont("mono", v, SystemAppearance.monoSize), get options() { return SystemAppearance.toOptions(SystemAppearance.fonts); } },
        "general:Cursor size": { type: "spin", get: () => SystemAppearance.cursorSize, set: v => SystemAppearance.setCursor(SystemAppearance.cursorTheme, v), from: 16, to: 64, stepSize: 2 },
        "general:System font size": { type: "spin", get: () => SystemAppearance.fontSize, set: v => SystemAppearance.setFont("ui", SystemAppearance.fontFamily, v), from: 8, to: 20, stepSize: 1 },
        "general:Monospace font size": { type: "spin", get: () => SystemAppearance.monoSize, set: v => SystemAppearance.setFont("mono", SystemAppearance.monoFamily, v), from: 8, to: 20, stepSize: 1 },
        "general:Interface language": { type: "select", get: () => Config.options.language.ui, set: v => { Config.options.language.ui = v; }, get options() { return [{ displayName: Translation.tr("Auto (System)"), value: "auto" }].concat(Translation.allAvailableLanguages.map(lang => ({ displayName: lang, value: lang }))); } }
    })

    readonly property var sections: [
        {
            page: Translation.tr("Bar"), title: Translation.tr("Bar layout"), icon: "view_week", cards: [
                { type: "barlayout", key: "bar:Layout editor", title: Translation.tr("Bar layout"), icon: "view_week" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Positioning & Styles"), icon: "pivot_table_chart", cards: [
                { type: "toggle", key: "bar:Show Background", title: Translation.tr("Bar background"), icon: "web_asset" },
                { type: "toggle", key: "bar:Overlap windows when center-only", title: Translation.tr("Overlap windows"), icon: "layers" },
                { type: "toggle", key: "bar:Follow Frame Color", title: Translation.tr("Follow frame color"), icon: "format_paint" },
                { type: "toggle", key: "bar:Show Frame", title: Translation.tr("Screen frame"), icon: "crop_free" },
                { type: "spin", key: "bar:Frame thickness", title: Translation.tr("Frame thickness"), icon: "border_outer" },
                { type: "select", key: "bar:Autohide", title: Translation.tr("Autohide"), icon: "visibility_off" },
                { type: "select", key: "bar:Group style", title: Translation.tr("Group style"), icon: "view_agenda" },
                { type: "select", w: 4, key: "bar:Bar style", title: Translation.tr("Bar style"), icon: "style", kw: "corner hug float islands panel m3" },
                { type: "swatch", w: 2, key: "bar:Group color", title: Translation.tr("Group color"), icon: "brush" },
                { type: "swatch", w: 2, key: "bar:Frame color", title: Translation.tr("Frame color"), icon: "imagesearch_roller" },
                { type: "select", w: 2, key: "bar:Screen rounded corners", title: Translation.tr("Screen rounded corners"), icon: "rounded_corner", kw: "fake screen rounding" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Dynamic Island"), icon: "nest_wifi_pro", requires: "dynamicIsland", cards: [
                { type: "select", key: "bar:Left widget", title: Translation.tr("Left widget"), icon: "right_panel_open" },
                { type: "select", key: "bar:Right widget", title: Translation.tr("Right widget"), icon: "left_panel_open" },
                { type: "select", key: "bar:Visualizer style", title: Translation.tr("Visualizer style"), icon: "graphic_eq" },
                { type: "toggle", key: "bar:Show media controls", title: Translation.tr("Media controls"), icon: "play_circle" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Notifications"), icon: "notifications", cards: [
                { type: "toggle", key: "bar:Unread indicator: show count", title: Translation.tr("Unread count"), icon: "counter_1" },
                { type: "spin", key: "bar:Timeout duration (if not defined by notification) (ms)", title: Translation.tr("Popup timeout (ms)"), icon: "timer" },
                { type: "combo", key: "bar:Notification position", title: Translation.tr("Popup position"), icon: "my_location" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Tray"), icon: "inbox", requires: "sysTray", cards: [
                { type: "toggle", key: "bar:Make icons pinned by default", title: Translation.tr("Pinned by default"), icon: "push_pin" },
                { type: "toggle", key: "bar:Tint icons", title: Translation.tr("Tint icons"), icon: "palette" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Left sidebar button"), icon: "left_panel_open", requires: "leftSidebarButton", cards: [
                { type: "iconpicker", key: "bar:Icon picker", title: Translation.tr("Icon"), icon: "image" },
                { type: "text", w: 2, key: "bar:Icons folder", title: Translation.tr("Custom icons folder"), icon: "folder_open", placeholder: "~/Pictures/icons", kw: "icons path folder custom" },
                { type: "toggle", key: "bar:Colorize icon", title: Translation.tr("Colorize icon"), icon: "colors" },
                { type: "swatch", w: 2, key: "bar:Icon color", title: Translation.tr("Icon color"), icon: "palette" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Divider"), icon: "horizontal_distribute", requires: "divisor", cards: [
                { type: "select", key: "bar:Divider/Style", title: Translation.tr("Divider style"), icon: "horizontal_rule" },
                { type: "spin", key: "bar:Space width (px)", title: Translation.tr("Space width"), icon: "space_bar" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Utility buttons"), icon: "toggle_on", requires: "utilButtons", cards: [
                { type: "toggle", key: "bar:Screen snip", title: Translation.tr("Screen snip"), icon: "screenshot_region" },
                { type: "toggle", key: "bar:Color picker", title: Translation.tr("Color picker"), icon: "colorize" },
                { type: "toggle", key: "bar:Keyboard toggle", title: Translation.tr("Keyboard toggle"), icon: "keyboard" },
                { type: "toggle", key: "bar:Mic toggle", title: Translation.tr("Mic toggle"), icon: "mic" },
                { type: "toggle", key: "bar:Dark/Light toggle", title: Translation.tr("Dark/Light toggle"), icon: "dark_mode" },
                { type: "toggle", key: "bar:Performance Profile", title: Translation.tr("Performance profile"), icon: "speed" },
                { type: "toggle", key: "bar:Record Screen", title: Translation.tr("Record screen"), icon: "screen_record" },
                { type: "toggle", key: "bar:Wallpapers Toggle", title: Translation.tr("Wallpapers toggle"), icon: "wallpaper" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Workspaces"), icon: "steppers", requires: "workspaces", cards: [
                { type: "toggle", key: "bar:Always show numbers", title: Translation.tr("Always show numbers"), icon: "pin" },
                { type: "toggle", key: "bar:Show app icons", title: Translation.tr("Show app icons"), icon: "apps" },
                { type: "spin", key: "bar:Workspaces shown", title: Translation.tr("Workspaces shown"), icon: "workspaces" },
                { type: "select", key: "bar:Indicator style", title: Translation.tr("Indicator style"), icon: "more_horiz" },
                { type: "select", key: "bar:Numbers style", title: Translation.tr("Numbers style"), icon: "123" },
                { type: "select", w: 2, key: "bar:Workspaces style", title: Translation.tr("Workspaces style"), icon: "style" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Resources"), icon: "empty_dashboard", requires: "resources", cards: [
                { type: "toggle", key: "bar:CPU", title: Translation.tr("CPU"), icon: "memory" },
                { type: "toggle", key: "bar:CPU Temperature", title: Translation.tr("CPU temperature"), icon: "device_thermostat" },
                { type: "toggle", key: "bar:RAM", title: Translation.tr("RAM"), icon: "developer_board" },
                { type: "toggle", key: "bar:Disk", title: Translation.tr("Disk"), icon: "hard_drive" },
                { type: "toggle", key: "bar:Swap", title: Translation.tr("Swap"), icon: "swap_horiz" },
                { type: "toggle", key: "bar:Show Percentage", title: Translation.tr("Show percentage"), icon: "percent" },
                { type: "select", key: "bar:Resources/Style", title: Translation.tr("Style"), icon: "monitoring" },
                { type: "spin", key: "bar:Polling interval (ms)", title: Translation.tr("Polling interval (ms)"), icon: "av_timer" }
            ]
        },
        {
            page: Translation.tr("Bar"), title: Translation.tr("Media"), icon: "music_note", requires: "media", cards: [
                { type: "text", w: 2, key: "bar:Preferred player", title: Translation.tr("Preferred player"), icon: "play_circle", placeholder: "e.g. spotify, firefox", kw: "mpris spotify firefox player music" },
                { type: "toggle", key: "bar:Pin media controls", title: Translation.tr("Pin media controls"), icon: "push_pin" },
                { type: "toggle", key: "bar:Show only title", title: Translation.tr("Only title"), icon: "title" },
                { type: "spin", key: "bar:Max media width", title: Translation.tr("Max media width"), icon: "width" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Transparency"), icon: "opacity", cards: [
                { type: "toggle", key: "interface:Automatic (from wallpaper)", title: Translation.tr("Auto transparency"), icon: "auto_awesome" },
                { type: "slider", key: "interface:Transparency/Background", title: Translation.tr("Background"), icon: "opacity" },
                { type: "slider", key: "interface:Transparency/Content", title: Translation.tr("Content"), icon: "opacity" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Left Sidebar"), icon: "splitscreen_left", cards: [
                { type: "toggle", key: "interface:Left Sidebar/Enable", title: Translation.tr("Media player"), icon: "music_note" },
                { type: "toggle", key: "interface:Follow Album Colors", title: Translation.tr("Album colors"), icon: "palette" },
                { type: "toggle", key: "interface:Enable Translator", title: Translation.tr("Translator"), icon: "translate" },
                { type: "select", key: "interface:AI policy", title: Translation.tr("AI"), icon: "smart_toy" },
                { type: "select", key: "interface:Weeb policy", title: Translation.tr("Weeb"), icon: "playing_cards" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Right Sidebar"), icon: "splitscreen_right", cards: [
                { type: "toggle", key: "interface:Banner", title: Translation.tr("Banner"), icon: "image" },
                { type: "toggle", key: "interface:Bottom Group", title: Translation.tr("Bottom group"), icon: "bottom_navigation" },
                { type: "toggle", key: "interface:Right Sidebar/Media Player", title: Translation.tr("Media player"), icon: "play_circle" },
                { type: "toggle", key: "interface:Keep right sidebar loaded", title: Translation.tr("Keep loaded"), icon: "bolt" },
                { type: "select", key: "interface:Right Sidebar/Style", title: Translation.tr("Quick toggles style"), icon: "toggle_on" },
                { type: "spin", key: "interface:Right Sidebar/Columns", title: Translation.tr("Toggle columns"), icon: "view_column" },
                { type: "toggle", key: "interface:Right Sidebar/Enable", title: Translation.tr("Quick sliders"), icon: "tune" },
                { type: "toggle", key: "interface:Brightness", title: Translation.tr("Brightness slider"), icon: "brightness_6" },
                { type: "toggle", key: "interface:Volume", title: Translation.tr("Volume slider"), icon: "volume_up" },
                { type: "toggle", key: "interface:Microphone", title: Translation.tr("Mic slider"), icon: "mic" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Hot Corners"), icon: "call_to_action", cards: [
                { type: "toggle", key: "interface:Hot Corners/Enable", title: Translation.tr("Enable"), icon: "call_to_action" },
                { type: "toggle", key: "interface:Hover to trigger", title: Translation.tr("Hover to trigger"), icon: "ads_click" },
                { type: "toggle", key: "interface:Place at bottom", title: Translation.tr("Place at bottom"), icon: "position_bottom_left" },
                { type: "toggle", key: "interface:Value scroll", title: Translation.tr("Value scroll"), icon: "unfold_more" },
                { type: "toggle", key: "interface:Visualize region", title: Translation.tr("Visualize region"), icon: "visibility" },
                { type: "toggle", key: "interface:Force hover at absolute corner", title: Translation.tr("Absolute corner"), icon: "crop_free" },
                { type: "spin", key: "interface:Vertical offset", title: Translation.tr("Vertical offset"), icon: "vertical_align_center" },
                { type: "spin", key: "interface:Region width", title: Translation.tr("Region width"), icon: "width" },
                { type: "spin", key: "interface:Region height", title: Translation.tr("Region height"), icon: "height" },
                { type: "combo", key: "interface:Hot corner bottom-left", title: Translation.tr("Bottom-left"), icon: "position_bottom_left" },
                { type: "combo", key: "interface:Hot corner bottom-right", title: Translation.tr("Bottom-right"), icon: "position_bottom_right" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Overview"), icon: "overview_key", cards: [
                { type: "toggle", key: "interface:Overview/Enable", title: Translation.tr("Enable"), icon: "overview_key" },
                { type: "toggle", key: "interface:Center icons", title: Translation.tr("Center icons"), icon: "center_focus_strong" },
                { type: "spin", key: "interface:Scale (%)", title: Translation.tr("Scale (%)"), icon: "zoom_in" },
                { type: "spin", key: "interface:Rows", title: Translation.tr("Rows"), icon: "table_rows" },
                { type: "spin", key: "interface:Overview/Columns", title: Translation.tr("Columns"), icon: "view_column" },
                { type: "select", key: "interface:Overview/Style", title: Translation.tr("Style"), icon: "grid_view" },
                { type: "select", key: "interface:Overview order horizontal", title: Translation.tr("Horizontal order"), icon: "swap_horiz" },
                { type: "select", key: "interface:Overview order vertical", title: Translation.tr("Vertical order"), icon: "swap_vert" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Dock"), icon: "dock_to_bottom", cards: [
                { type: "toggle", key: "interface:Dock/Enable", title: Translation.tr("Enable"), icon: "dock_to_bottom" },
                { type: "toggle", key: "interface:Dock/Background", title: Translation.tr("Background"), icon: "layers" },
                { type: "toggle", key: "interface:Hover to reveal", title: Translation.tr("Hover to reveal"), icon: "visibility" },
                { type: "toggle", key: "interface:Pinned on startup", title: Translation.tr("Pinned on startup"), icon: "push_pin" },
                { type: "toggle", key: "interface:Dock/Media Player", title: Translation.tr("Media player"), icon: "music_note" },
                { type: "toggle", key: "interface:Show Pin Button", title: Translation.tr("Pin button"), icon: "push_pin" },
                { type: "toggle", key: "interface:Show Apps Button", title: Translation.tr("Apps button"), icon: "apps" },
                { type: "toggle", key: "interface:Tint app icons", title: Translation.tr("Tint app icons"), icon: "palette" },
                { type: "toggle", key: "interface:Dock/Previews", title: Translation.tr("Window previews"), icon: "preview" },
                { type: "spin", key: "interface:Dock/Icon size", title: Translation.tr("Icon size"), icon: "photo_size_select_large" },
                { type: "spin", key: "interface:Dock/Icon spacing", title: Translation.tr("Icon spacing"), icon: "space_bar" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Dock style"), icon: "call_to_action", cards: [
                { type: "select", key: "interface:Dock/Style", title: Translation.tr("Style"), icon: "dock_to_bottom", kw: "dock hug float attached screen edge frame" },
                { type: "select", key: "interface:Dock/Position", title: Translation.tr("Position"), icon: "dock_to_bottom", kw: "dock position left right bottom side edge" },
                { type: "spin", key: "interface:Dock/Radius", title: Translation.tr("Corner radius"), icon: "rounded_corner" },
                { type: "toggle", when: "dockhug", key: "interface:Dock/Follow frame color", title: Translation.tr("Follow frame color"), icon: "filter_frames" },
                { type: "toggle", when: "dockfloat", key: "interface:Dock/Border", title: Translation.tr("Border"), icon: "border_style" },
                { type: "spin", when: "dockfloat", key: "interface:Dock/Border width", title: Translation.tr("Border width"), icon: "line_weight" },
                { type: "swatch", w: 2, when: "dockfloat", key: "interface:Dock/Border color", title: Translation.tr("Border color"), icon: "format_paint" },
                { type: "swatch", w: 2, key: "interface:Dock/Background color", title: Translation.tr("Background color"), icon: "palette" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Lock screen"), icon: "lock", cards: [
                { type: "toggle", key: "interface:Use Hyprlock (instead of Quickshell)", title: Translation.tr("Use Hyprlock"), icon: "lock" },
                { type: "toggle", key: "interface:Launch on startup", title: Translation.tr("Lock on startup"), icon: "power_settings_new" },
                { type: "toggle", key: "interface:Show Widgets", title: Translation.tr("Widgets"), icon: "widgets" },
                { type: "toggle", key: "interface:Show Toolbars", title: Translation.tr("Toolbars"), icon: "toolbar" },
                { type: "toggle", key: "interface:Show media player info", title: Translation.tr("Media info"), icon: "music_note" },
                { type: "toggle", key: "interface:Require password to power off/restart", title: Translation.tr("Password to power off"), icon: "password" },
                { type: "toggle", key: "interface:Also unlock keyring", title: Translation.tr("Unlock keyring"), icon: "key" },
                { type: "toggle", key: "interface:Center clock", title: Translation.tr("Center clock"), icon: "center_focus_strong" },
                { type: "toggle", key: "interface:Use varying shapes for password characters", title: Translation.tr("Password shapes"), icon: "shapes" },
                { type: "toggle", key: "interface:Enable blur", title: Translation.tr("Blur"), icon: "blur_on" },
                { type: "spin", key: "interface:Samples", title: Translation.tr("Blur samples"), icon: "grain" },
                { type: "spin", key: "interface:Extra wallpaper zoom (%)", title: Translation.tr("Wallpaper zoom (%)"), icon: "zoom_in" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Overlay"), icon: "layers", cards: [
                { type: "toggle", key: "interface:Enable opening zoom animation", title: Translation.tr("Opening zoom"), icon: "zoom_out_map" },
                { type: "toggle", key: "interface:Darken screen", title: Translation.tr("Darken screen"), icon: "brightness_low" },
                { type: "text", key: "interface:Floating image source", title: Translation.tr("Floating image source"), icon: "imagesmode", w: 2 },
                { type: "text", key: "interface:Crosshair code", title: Translation.tr("Crosshair code"), icon: "point_scan", w: 2 },
                { type: "spin", key: "interface:Timeout (ms)", title: Translation.tr("OSD timeout (ms)"), icon: "timer" }
            ]
        },
        {
            page: Translation.tr("Interface"), title: Translation.tr("Wallpaper selector"), icon: "wallpaper", cards: [
                { type: "toggle", key: "interface:Use system file picker", title: Translation.tr("System file picker"), icon: "ad" },
                { type: "toggle", key: "interface:Show home directory in quick access", title: Translation.tr("Home in quick access"), icon: "home" },
                { type: "toggle", key: "interface:Close after selection", title: Translation.tr("Close after selection"), icon: "done" },
                { type: "toggle", key: "interface:Show blur background", title: Translation.tr("Blur background"), icon: "blur_on" },
                { type: "toggle", key: "interface:Always show search bar", title: Translation.tr("Search bar"), icon: "search" },
                { type: "spin", key: "interface:Columns in grid view", title: Translation.tr("Grid columns"), icon: "grid_view" },
                { type: "spin", key: "interface:Wallpaper change interval (min)", title: Translation.tr("Change interval (min)"), icon: "timer" },
                { type: "text", key: "interface:Custom wallpaper folder", title: Translation.tr("Custom wallpaper folder"), icon: "folder", w: 2 },
                { type: "text", key: "interface:Live wallpaper folder", title: Translation.tr("Live wallpaper folder"), icon: "video_template", w: 2 }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Wallpaper"), icon: "wallpaper", cards: [
                { type: "toggle", key: "desktop:Same wallpaper", title: Translation.tr("Same wallpaper (lock)"), icon: "sync" },
                { type: "toggle", key: "desktop:Preview wallpaper", title: Translation.tr("Preview wallpaper"), icon: "preview" },
                { type: "toggle", key: "desktop:Blur wall", title: Translation.tr("Blur wallpaper"), icon: "blur_on" },
                { type: "spin", key: "desktop:Wallpaper change interval (min)", title: Translation.tr("Change interval (min)"), icon: "timer" },
                { type: "slider", key: "desktop:Blur Size", title: Translation.tr("Blur size"), icon: "blur_on", percent: false },
                { type: "select", key: "desktop:Split blur amount", title: Translation.tr("Split blur amount"), icon: "thumbnail_bar" },
                { type: "select", key: "desktop:Split blur side", title: Translation.tr("Split blur side"), icon: "align_horizontal_left" },
                { type: "combo", key: "desktop:Transitions", title: Translation.tr("Transitions"), icon: "animation" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Centered wallpaper"), icon: "filter_center_focus", cards: [
                { type: "toggle", key: "desktop:Wallpaper/Centered wallpaper/Enable", title: Translation.tr("Enable"), icon: "wallpaper" },
                { type: "toggle", key: "desktop:Wallpaper/Centered wallpaper/Show only when locked", title: Translation.tr("Only when locked"), icon: "lock" },
                { type: "slider", key: "desktop:Wallpaper/Centered wallpaper/Size", title: Translation.tr("Size"), icon: "aspect_ratio", percent: false },
                { type: "swatch", key: "desktop:Centered color", title: Translation.tr("Background color"), icon: "palette", w: 2 },
                { type: "shape", key: "desktop:Centered shape", title: Translation.tr("Shape"), icon: "shapes" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Multiple wallpapers"), icon: "grid_view", cards: [
                { type: "toggle", key: "desktop:Collage enable", title: Translation.tr("Enable"), icon: "grid_view" },
                { type: "collagelayouts", key: "desktop:Collage layouts", title: Translation.tr("Layouts"), icon: "dashboard_customize", kw: "collage multiple wallpapers layout preset grid mosaic" },
                { type: "spin", key: "desktop:Collage gap", title: Translation.tr("Spacing"), icon: "space_bar" },
                { type: "spin", key: "desktop:Collage margin", title: Translation.tr("Outer margin"), icon: "padding" },
                { type: "spin", key: "desktop:Collage radius", title: Translation.tr("Corner radius"), icon: "rounded_corner" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Desktop widgets"), icon: "widgets", cards: [
                { type: "widgets", key: "desktop:Widgets", title: Translation.tr("Desktop widgets"), icon: "widgets", kw: "widgets desktop menu star favorite clock weather calendar media resources todo notes timers sticker visualizer" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Clock"), icon: "schedule", cards: [
                { type: "toggle", key: "desktop:Clock/Enable", title: Translation.tr("Enable"), icon: "schedule" },
                { type: "toggle", key: "desktop:Clock/Show only when locked", title: Translation.tr("Only when locked"), icon: "lock" },
                { type: "select", key: "desktop:Placement strategy", title: Translation.tr("Placement"), icon: "drag_pan" },
                { type: "select", key: "desktop:Clock style", title: Translation.tr("Style"), icon: "schedule" },
                { type: "select", key: "desktop:Clock style (locked)", title: Translation.tr("Style (locked)"), icon: "lock_clock" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Digital clock"), when: "clockdigital", icon: "timer_10", cards: [
                { type: "toggle", key: "desktop:Vertical", title: Translation.tr("Vertical"), icon: "vertical_align_center" },
                { type: "toggle", key: "desktop:Animate time change", title: Translation.tr("Animate change"), icon: "animation" },
                { type: "toggle", key: "desktop:Show date", title: Translation.tr("Show date"), icon: "calendar_today" },
                { type: "toggle", key: "desktop:Use adaptive alignment", title: Translation.tr("Adaptive alignment"), icon: "format_align_center" },
                { type: "toggle", key: "desktop:Clock auto colors", title: Translation.tr("Automatic colors"), icon: "auto_awesome" },
                { type: "swatch", key: "desktop:Clock color", title: Translation.tr("Color"), icon: "palette", w: 2 },
                { type: "combo", key: "desktop:Clock font family", title: Translation.tr("Font family"), icon: "font_download" },
                { type: "slider", key: "desktop:Font weight", title: Translation.tr("Weight"), icon: "format_bold", percent: false },
                { type: "slider", key: "desktop:Font size", title: Translation.tr("Size"), icon: "format_size", percent: false },
                { type: "slider", key: "desktop:Font width", title: Translation.tr("Width"), icon: "width", percent: false },
                { type: "slider", key: "desktop:Font roundness", title: Translation.tr("Roundness"), icon: "rounded_corner", percent: false }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Cookie clock"), when: "clockcookie", icon: "cookie", cards: [
                { type: "toggle", key: "desktop:Auto styling with Gemini", title: Translation.tr("Auto styling (Gemini)"), icon: "auto_awesome" },
                { type: "toggle", key: "desktop:Use old sine wave cookie implementation", title: Translation.tr("Old sine cookie"), icon: "waves" },
                { type: "toggle", key: "desktop:Constantly rotate", title: Translation.tr("Constantly rotate"), icon: "autorenew" },
                { type: "toggle", key: "desktop:Hour marks", title: Translation.tr("Hour marks"), icon: "more_horiz" },
                { type: "toggle", key: "desktop:Digits in the middle", title: Translation.tr("Digits in the middle"), icon: "pin" },
                { type: "spin", key: "desktop:Sides", title: Translation.tr("Sides"), icon: "hexagon" },
                { type: "select", key: "desktop:Dial Style", title: Translation.tr("Dial style"), icon: "history_toggle_off" },
                { type: "select", key: "desktop:Hour hand", title: Translation.tr("Hour hand"), icon: "schedule" },
                { type: "select", key: "desktop:Minute hand", title: Translation.tr("Minute hand"), icon: "schedule" },
                { type: "select", key: "desktop:Second hand", title: Translation.tr("Second hand"), icon: "schedule" },
                { type: "select", key: "desktop:Date style", title: Translation.tr("Date style"), icon: "calendar_today" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Pixel clock"), when: "clockpixel", icon: "grid_view", cards: [
                { type: "select", key: "desktop:Pixel clock orientation", title: Translation.tr("Orientation"), icon: "screen_rotation" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Quote"), icon: "format_quote", cards: [
                { type: "toggle", key: "desktop:Clock/Quote/Enable", title: Translation.tr("Enable"), icon: "format_quote" },
                { type: "toggle", key: "desktop:Follow Clock Font", title: Translation.tr("Follow clock font"), icon: "font_download" },
                { type: "text", key: "desktop:Quote text", title: Translation.tr("Quote"), icon: "edit", w: 2 }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Custom image"), icon: "imagesmode", cards: [
                { type: "toggle", key: "desktop:Custom Image/Enable", keepOrder: true, title: Translation.tr("Enable"), icon: "imagesmode" },
                { type: "shape", key: "desktop:Image shape", title: Translation.tr("Shape"), icon: "shapes" },
                { type: "toggle", key: "desktop:Image card/Enable", title: Translation.tr("Image card"), icon: "photo_size_select_large" },
                { type: "select", key: "desktop:Image card layout", title: Translation.tr("Image card layout"), icon: "grid_view" }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Visualizer"), icon: "graphic_eq", cards: [
                { type: "toggle", key: "desktop:Visualizer enable", title: Translation.tr("Enable"), icon: "graphic_eq" },
                { type: "select", key: "desktop:Visualizer style", title: Translation.tr("Style"), icon: "equalizer" },
                { type: "select", key: "desktop:Visualizer colors", title: Translation.tr("Colors"), icon: "palette" },
                { type: "slider", key: "desktop:Visualizer sensitivity", title: Translation.tr("Sensitivity (%)"), icon: "speed", percent: false },
                { type: "slider", key: "desktop:Visualizer height", title: Translation.tr("Height"), icon: "height", percent: false },
                { type: "slider", key: "desktop:Visualizer size", title: Translation.tr("Ring size"), icon: "radio_button_unchecked", percent: false }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Text"), icon: "text_fields", cards: [
                { type: "toggle", key: "desktop:Text enable", title: Translation.tr("Enable"), icon: "text_fields" },
                { type: "toggle", key: "desktop:Text shadow", title: Translation.tr("Shadow"), icon: "shadow" },
                { type: "toggle", key: "desktop:Text auto colors", title: Translation.tr("Automatic colors"), icon: "auto_awesome" },
                { type: "text", key: "desktop:Text content", title: Translation.tr("Text to display"), icon: "edit", w: 2 },
                { type: "combo", key: "desktop:Text font family", title: Translation.tr("Font family"), icon: "font_download" },
                { type: "text", key: "desktop:Text custom font", title: Translation.tr("Custom font"), icon: "edit" },
                { type: "slider", key: "desktop:Text size", title: Translation.tr("Font size"), icon: "format_size", percent: false },
                { type: "select", key: "desktop:Text alignment", title: Translation.tr("Alignment"), icon: "format_align_center" },
                { type: "swatch", key: "desktop:Text color", title: Translation.tr("Color"), icon: "palette", w: 2 }
            ]
        },
        {
            page: Translation.tr("Desktop"), title: Translation.tr("Canvas"), icon: "drag_pan", cards: [
                { type: "toggle", key: "desktop:Show alignment grid while dragging", title: Translation.tr("Alignment grid"), icon: "grid_on" },
                { type: "toggle", key: "desktop:Show snap lines when dropping", title: Translation.tr("Snap lines"), icon: "straighten" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("System Appearance"), icon: "palette", cards: [
                { type: "combo", key: "general:Icon theme", title: Translation.tr("Icon theme"), icon: "category", kw: "icons" },
                { type: "combo", key: "general:Cursor theme", title: Translation.tr("Cursor theme"), icon: "mouse" },
                { type: "combo", key: "general:System font", title: Translation.tr("System font"), icon: "text_fields", kw: "typography" },
                { type: "combo", key: "general:Monospace font", title: Translation.tr("Monospace font"), icon: "terminal", kw: "terminal code" },
                { type: "spin", key: "general:Cursor size", title: Translation.tr("Cursor size"), icon: "ads_click" },
                { type: "spin", key: "general:System font size", title: Translation.tr("System font size"), icon: "format_size" },
                { type: "spin", key: "general:Monospace font size", title: Translation.tr("Mono font size"), icon: "format_size" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Time"), icon: "nest_clock_farsight_analog", cards: [
                { type: "timepreview", key: "general:Time preview", title: Translation.tr("Preview"), icon: "schedule", kw: "clock time preview" },
                { type: "toggle", key: "general:Second precision", title: Translation.tr("Second precision"), icon: "pace" },
                { type: "toggle", key: "general:Show date", title: Translation.tr("Show date"), icon: "date_range" },
                { type: "select", w: 4, key: "general:Format", title: Translation.tr("Time format"), icon: "schedule", kw: "clock 24h 12h" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Battery"), icon: "battery_android_full", cards: [
                { type: "spin", key: "general:Low warning", title: Translation.tr("Low warning"), icon: "warning" },
                { type: "spin", key: "general:Critical warning", title: Translation.tr("Critical warning"), icon: "dangerous" },
                { type: "spin", key: "general:Full warning", title: Translation.tr("Full warning"), icon: "charger" },
                { type: "toggle", key: "general:Automatic suspend", title: Translation.tr("Automatic suspend"), icon: "pause" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Audio"), icon: "volume_up", cards: [
                { type: "toggle", key: "general:Earbang protection", title: Translation.tr("Earbang protection"), icon: "hearing" },
                { type: "spin", key: "general:Max allowed increase", title: Translation.tr("Max allowed increase"), icon: "arrow_warm_up" },
                { type: "spin", key: "general:Volume limit", title: Translation.tr("Volume limit"), icon: "vertical_align_top" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Sounds"), icon: "notification_sound", cards: [
                { type: "toggle", key: "general:Sounds/Battery", title: Translation.tr("Battery sounds"), icon: "battery_android_full" },
                { type: "toggle", key: "general:Sounds/Pomodoro", title: Translation.tr("Pomodoro sounds"), icon: "av_timer" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Language"), icon: "language_japanese_kana", cards: [
                { type: "combo", key: "general:Interface language", title: Translation.tr("Interface language"), icon: "language", kw: "locale translate" }
            ]
        },
        {
            page: Translation.tr("General"), title: Translation.tr("Work safety"), icon: "work_alert", cards: [
                { type: "toggle", key: "general:Hide clipboard images copied from sussy sources", title: Translation.tr("Hide clipboard images"), icon: "assignment" },
                { type: "toggle", key: "general:Hide sussy/anime wallpapers", title: Translation.tr("Hide sussy wallpapers"), icon: "wallpaper" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Displays"), icon: "monitor", when: "hyprland", cards: [
                { type: "displays", key: "hyprland:Displays", title: Translation.tr("Displays"), icon: "monitor" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Layout"), icon: "dashboard_customize", when: "hyprland", cards: [
                { type: "select", key: "hyprland:Tiling Layout", title: Translation.tr("Tiling layout"), icon: "browse" },
                { type: "spin", key: "hyprland:Gaps In", title: Translation.tr("Gaps in"), icon: "fit_screen" },
                { type: "spin", key: "hyprland:Gaps Out", title: Translation.tr("Gaps out"), icon: "aspect_ratio" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Dwindle"), icon: "browse", when: "layoutdwindle", cards: [
                { type: "toggle", key: "hyprland:opt:dwindle:preserve_split", title: Translation.tr("Preserve split direction"), icon: "call_split" },
                { type: "toggle", key: "hyprland:opt:dwindle:smart_split", title: Translation.tr("Smart split (follow cursor)"), icon: "smart_toy" },
                { type: "select", key: "hyprland:opt:dwindle:force_split", title: Translation.tr("Force split side"), icon: "splitscreen" },
                { type: "spin", key: "hyprland:opt:dwindle:default_split_ratio", title: Translation.tr("Default split ratio"), icon: "percent" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Master"), icon: "auto_awesome_mosaic", when: "layoutmaster", cards: [
                { type: "select", key: "hyprland:opt:master:new_status", title: Translation.tr("New windows become"), icon: "add_box" },
                { type: "select", key: "hyprland:opt:master:orientation", title: Translation.tr("Master position"), icon: "screen_rotation" },
                { type: "spin", key: "hyprland:opt:master:mfact", title: Translation.tr("Master size"), icon: "aspect_ratio" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Keyboard"), icon: "keyboard", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:Numlock by default", title: Translation.tr("Numlock by default"), icon: "pin" },
                { type: "spin", key: "hyprland:Repeat delay (ms)", title: Translation.tr("Repeat delay (ms)"), icon: "timer" },
                { type: "spin", key: "hyprland:Repeat rate", title: Translation.tr("Repeat rate"), icon: "speed" },
                { type: "text", key: "hyprland:opt:input:kb_variant", title: Translation.tr("Keyboard variant"), icon: "keyboard_alt", w: 2 },
                { type: "text", key: "hyprland:opt:input:kb_options", title: Translation.tr("Keyboard options"), icon: "keyboard_command_key", w: 2 }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Mouse"), icon: "mouse", when: "hyprland", cards: [
                { type: "select", key: "hyprland:Follow mouse", title: Translation.tr("Follow mouse"), icon: "ads_click" },
                { type: "spin", key: "hyprland:opt:input:sensitivity", title: Translation.tr("Pointer sensitivity"), icon: "speed" },
                { type: "select", key: "hyprland:opt:input:accel_profile", title: Translation.tr("Acceleration profile"), icon: "trending_up" },
                { type: "toggle", key: "hyprland:opt:input:force_no_accel", title: Translation.tr("Disable acceleration"), icon: "mouse" },
                { type: "toggle", key: "hyprland:opt:input:left_handed", title: Translation.tr("Left-handed buttons"), icon: "front_hand" },
                { type: "toggle", key: "hyprland:opt:misc:middle_click_paste", title: Translation.tr("Middle click paste"), icon: "content_paste" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Touchpad"), icon: "touchpad_mouse", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:Natural scroll", title: Translation.tr("Natural scroll"), icon: "swap_vert" },
                { type: "toggle", key: "hyprland:Disable while typing", title: Translation.tr("Disable while typing"), icon: "keyboard_off" },
                { type: "toggle", key: "hyprland:Clickfinger behavior", title: Translation.tr("Clickfinger behavior"), icon: "touch_app" },
                { type: "spin", key: "hyprland:Scroll factor", title: Translation.tr("Scroll factor"), icon: "unfold_more" },
                { type: "toggle", key: "hyprland:opt:input:touchpad:tap-to-click", title: Translation.tr("Tap to click"), icon: "touch_app" },
                { type: "toggle", key: "hyprland:opt:input:touchpad:tap-and-drag", title: Translation.tr("Tap and drag"), icon: "drag_pan" },
                { type: "toggle", key: "hyprland:opt:input:touchpad:middle_button_emulation", title: Translation.tr("Middle button emulation"), icon: "mouse" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Idle"), icon: "bedtime", when: "hyprland", cards: [
                { type: "duration", key: "hyprland:Idle lock", title: Translation.tr("Lock screen"), icon: "lock_clock" },
                { type: "duration", key: "hyprland:Idle screen off", title: Translation.tr("Screen off"), icon: "monitor" },
                { type: "duration", key: "hyprland:Idle standby", title: Translation.tr("Standby"), icon: "bedtime" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Visual & Aesthetics"), icon: "palette", when: "hyprland", cards: [
                { type: "spin", key: "hyprland:Window Rounding", title: Translation.tr("Window rounding"), icon: "rounded_corner" },
                { type: "spin", key: "hyprland:Border Size", title: Translation.tr("Border size"), icon: "border_style" },
                { type: "spin", key: "hyprland:Active Opacity", title: Translation.tr("Active opacity"), icon: "opacity" },
                { type: "spin", key: "hyprland:Inactive Opacity", title: Translation.tr("Inactive opacity"), icon: "opacity" },
                { type: "toggle", key: "hyprland:Custom border colors", title: Translation.tr("Custom border colors"), icon: "format_paint" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Border colors"), icon: "border_color", when: "hyprbordercolor", cards: [
                { type: "swatch", w: 2, key: "hyprland:Active border color", title: Translation.tr("Active border"), icon: "border_color" },
                { type: "swatch", w: 2, key: "hyprland:Inactive border color", title: Translation.tr("Inactive border"), icon: "border_color" },
                { type: "spin", key: "hyprland:Active border opacity", title: Translation.tr("Active border opacity"), icon: "opacity" },
                { type: "spin", key: "hyprland:Inactive border opacity", title: Translation.tr("Inactive border opacity"), icon: "opacity" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Shadows, dimming & blur"), icon: "blur_on", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:opt:decoration:shadow:enabled", title: Translation.tr("Window shadows"), icon: "shadow" },
                { type: "spin", key: "hyprland:opt:decoration:shadow:range", title: Translation.tr("Shadow range"), icon: "blur_on" },
                { type: "toggle", key: "hyprland:opt:decoration:dim_inactive", title: Translation.tr("Dim inactive windows"), icon: "brightness_low" },
                { type: "spin", key: "hyprland:opt:decoration:dim_strength", title: Translation.tr("Dim strength"), icon: "contrast" },
                { type: "toggle", key: "hyprland:Blur", title: Translation.tr("Window blur"), icon: "blur_on" },
                { type: "spin", key: "hyprland:Blur Size", title: Translation.tr("Blur size"), icon: "blur_linear" },
                { type: "spin", key: "hyprland:Blur Passes", title: Translation.tr("Blur passes"), icon: "layers" },
                { type: "spin", key: "hyprland:opt:decoration:blur:noise", title: Translation.tr("Blur noise"), icon: "grain" },
                { type: "spin", key: "hyprland:opt:decoration:blur:vibrancy", title: Translation.tr("Blur vibrancy"), icon: "palette" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Misc"), icon: "tune", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:Focus on activate", title: Translation.tr("Focus on activate"), icon: "center_focus_strong" },
                { type: "select", key: "hyprland:opt:misc:vrr", title: Translation.tr("Variable refresh rate"), icon: "slow_motion_video" },
                { type: "toggle", key: "hyprland:opt:misc:enable_swallow", title: Translation.tr("Window swallowing"), icon: "call_merge" },
                { type: "toggle", key: "hyprland:opt:misc:animate_manual_resizes", title: Translation.tr("Animate manual resizes"), icon: "animation" },
                { type: "toggle", key: "hyprland:opt:misc:close_special_on_empty", title: Translation.tr("Close empty special workspace"), icon: "close_fullscreen" },
                { type: "toggle", key: "hyprland:opt:misc:disable_hyprland_logo", title: Translation.tr("Hide Hyprland logo"), icon: "hide_image" },
                { type: "toggle", key: "hyprland:opt:misc:disable_splash_rendering", title: Translation.tr("Hide splash text"), icon: "subtitles_off" },
                { type: "toggle", key: "hyprland:opt:misc:mouse_move_enables_dpms", title: Translation.tr("Mouse wakes the screen"), icon: "mouse" },
                { type: "toggle", key: "hyprland:opt:misc:key_press_enables_dpms", title: Translation.tr("Keys wake the screen"), icon: "keyboard" },
                { type: "toggle", key: "hyprland:opt:xwayland:force_zero_scaling", title: Translation.tr("XWayland sharp apps"), icon: "zoom_out_map" },
                { type: "toggle", key: "hyprland:opt:group:auto_group", title: Translation.tr("Auto-group dragged windows"), icon: "tab_group" },
                { type: "toggle", key: "hyprland:opt:binds:workspace_back_and_forth", title: Translation.tr("Workspace back and forth"), icon: "swap_horiz" },
                { type: "toggle", key: "hyprland:opt:binds:allow_workspace_cycles", title: Translation.tr("Allow workspace cycles"), icon: "cached" },
                { type: "select", key: "hyprland:opt:render:direct_scanout", title: Translation.tr("Direct scanout"), icon: "speed" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Windows"), icon: "select_window", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:opt:general:resize_on_border", title: Translation.tr("Resize on borders"), icon: "open_in_full" },
                { type: "spin", key: "hyprland:opt:general:extend_border_grab_area", title: Translation.tr("Border grab area (px)"), icon: "border_outer" },
                { type: "toggle", key: "hyprland:opt:general:allow_tearing", title: Translation.tr("Allow tearing"), icon: "sports_esports" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Cursor"), icon: "mouse", when: "hyprland", cards: [
                { type: "select", key: "hyprland:opt:cursor:no_hardware_cursors", title: Translation.tr("Hardware cursor"), icon: "mouse" },
                { type: "spin", key: "hyprland:opt:cursor:inactive_timeout", title: Translation.tr("Hide cursor after (s)"), icon: "hourglass_empty" },
                { type: "toggle", key: "hyprland:opt:cursor:hide_on_key_press", title: Translation.tr("Hide cursor while typing"), icon: "keyboard_hide" },
                { type: "select", key: "hyprland:opt:cursor:warp_on_change_workspace", title: Translation.tr("Warp to new workspace"), icon: "ads_click" }
            ]
        },
        {
            page: Translation.tr("Hyprland"), title: Translation.tr("Animations"), icon: "animation", when: "hyprland", cards: [
                { type: "toggle", key: "hyprland:Enable", title: Translation.tr("Animations"), icon: "animation" },
                { type: "select", key: "hyprland:Presets", title: Translation.tr("Animation presets"), icon: "auto_awesome" }
            ]
        },
        {
            page: Translation.tr("Services"), title: Translation.tr("Music Recognition"), icon: "music_cast", cards: [
                { type: "spin", key: "services:Total duration timeout (s)", title: Translation.tr("Timeout (s)"), icon: "timer_off" },
                { type: "spin", key: "services:Polling interval (s)", title: Translation.tr("Polling interval (s)"), icon: "av_timer" }
            ]
        },
        {
            page: Translation.tr("Services"), title: Translation.tr("Save paths"), icon: "file_open", cards: [
                { type: "text", w: 2, key: "services:Video recording path", title: Translation.tr("Video recording path"), icon: "video_file" },
                { type: "text", w: 2, key: "services:Screenshot path", title: Translation.tr("Screenshot path (empty = copy)"), icon: "screenshot_monitor" }
            ]
        },
        {
            page: Translation.tr("Services"), title: Translation.tr("Search"), icon: "search", cards: [
                { type: "toggle", key: "services:Use Levenshtein distance-based algorithm instead of fuzzy", title: Translation.tr("Levenshtein search"), icon: "manage_search" },
                { type: "toggle", key: "services:Show clipboard preview popups", title: Translation.tr("Clipboard previews"), icon: "preview" },
                { type: "text", w: 2, key: "services:Base URL", title: Translation.tr("Web search base URL"), icon: "travel_explore" },
                { type: "text", key: "services:Prefix action", title: Translation.tr("Prefix: Action"), icon: "bolt" },
                { type: "text", key: "services:Prefix clipboard", title: Translation.tr("Prefix: Clipboard"), icon: "content_paste" },
                { type: "text", key: "services:Prefix emojis", title: Translation.tr("Prefix: Emojis"), icon: "mood" },
                { type: "text", key: "services:Prefix symbols", title: Translation.tr("Prefix: Icons"), icon: "emoji_symbols" },
                { type: "text", key: "services:Prefix shell", title: Translation.tr("Prefix: Shell command"), icon: "terminal" },
                { type: "text", key: "services:Prefix web", title: Translation.tr("Prefix: Web search"), icon: "travel_explore" },
                { type: "text", key: "services:Prefix app", title: Translation.tr("Prefix: Apps"), icon: "apps" },
                { type: "text", key: "services:Prefix keybinds", title: Translation.tr("Prefix: Keybinds"), icon: "keyboard_command_key" }
            ]
        },
        {
            page: Translation.tr("Services"), title: Translation.tr("System updates (Arch)"), icon: "deployed_code_update", cards: [
                { type: "toggle", key: "services:Enable update checks", title: Translation.tr("Update checks"), icon: "update" },
                { type: "spin", key: "services:Check interval (mins)", title: Translation.tr("Check interval (min)"), icon: "av_timer" }
            ]
        },
        {
            page: Translation.tr("Services"), title: Translation.tr("Weather"), icon: "weather_mix", cards: [
                { type: "weathermap", key: "services:Weather map", title: Translation.tr("Weather location"), icon: "public", kw: "weather map city location world" },
                { type: "toggle", key: "services:Enable GPS based location", title: Translation.tr("GPS location"), icon: "assistant_navigation" },
                { type: "toggle", key: "services:Fahrenheit unit", title: Translation.tr("Fahrenheit"), icon: "thermometer" },
                { type: "spin", key: "services:Polling interval (m)", title: Translation.tr("Polling interval (m)"), icon: "av_timer" },
                { type: "text", w: 2, key: "services:City name", title: Translation.tr("City name"), icon: "location_city" }
            ]
        }
    ]
}
