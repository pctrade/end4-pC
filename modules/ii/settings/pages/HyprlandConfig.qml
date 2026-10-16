import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    id: page
    forceWidth: true

    Component.onCompleted: {
        HyprlandOptions.refresh()
        const h = Config.options.hyprland
        // One setMany for everything: separate calls would be separate
        // processes racing to rewrite the same overrides file.
        HyprlandConfig.setMany(Object.assign({
            "decoration:rounding":                  h.decoration.rounding,
            "decoration:blur:enabled":              h.decoration.blur.enabled ? 1 : 0,
            "decoration:blur:size":                 h.decoration.blur.size,
            "decoration:blur:passes":               h.decoration.blur.passes,
            "decoration:active_opacity":            h.decoration.activeOpacity,
            "decoration:inactive_opacity":          h.decoration.inactiveOpacity,
            "general:border_size":                  h.general.borderSize,
            "general:gaps_in":                      h.general.gapsIn,
            "general:gaps_out":                     h.general.gapsOut,
            "general:layout":                       h.general.layout,
            "animations:enabled":                   h.animations.enable ? 1 : 0,
            "input:kb_layout":                      h.input.kbLayout,
            "input:numlock_by_default":             h.input.numlock ? 1 : 0,
            "input:repeat_delay":                   h.input.repeatDelay,
            "input:repeat_rate":                    h.input.repeatRate,
            "input:follow_mouse":                   h.input.followMouse,
            "input:touchpad:natural_scroll":        h.input.touchpad.naturalScroll ? 1 : 0,
            "input:touchpad:disable_while_typing":  h.input.touchpad.disableWhileTyping ? 1 : 0,
            "input:touchpad:clickfinger_behavior":  h.input.touchpad.clickfingerBehavior ? 1 : 0,
            "input:touchpad:scroll_factor":         h.input.touchpad.scrollFactor,
            "misc:focus_on_activate":               h.misc.focusOnActivate ? 1 : 0
        }, HyprlandConfig.borderColorEntries()))
    }
    MonitorConfigOption { id: monitorConfig }

    // Same roles as the settings panel border color on the Interface page.
    readonly property var borderColorRoles: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"]

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // Displays
        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            title: Translation.tr("Displays")
            visible: monitorConfig.monitors.length > 0

            MonitorCanvas {
                id: monitorCanvas
                Layout.fillWidth: true
                monitorConfig: monitorConfig
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? "")
                    + " · "
                    + (monitorConfig.monitors[monitorCanvas.selectedIndex]?.description ?? "")

                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "tv_off"
                        text: Translation.tr("Enabled")
                        enabled: monitorConfig.monitors.length > 1
                        checked: !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)
                        onCheckedChanged: {
                            if (checked === !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "aspect_ratio"
                        text: Translation.tr("Resolution & Refresh Rate")
                        textRole: "display"
                        model: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.availableModes ?? [])
                            .map(mode => ({ display: mode, value: mode }))
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.currentMode ?? ""
                        onSelected: newValue => {
                            const mode = newValue
                            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, {
                                currentMode: mode,
                                width: parseInt(parts[1]),
                                height: parseInt(parts[2]),
                                refreshRate: parseFloat(parts[3])
                            })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Orientation")
                        icon: "mobile_rotate"
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.transform ?? 0
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                        options: [
                            { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                            { displayName: "90°",                    icon: "rotate_90_degrees_cw",  value: 1 },
                            { displayName: "180°",                   icon: "screen_rotation",       value: 2 },
                            { displayName: "270°",                   icon: "rotate_90_degrees_ccw", value: 3 },
                        ]
                    }
    
                    ConfigSpinBox {
                        icon: "zoom_in"
                        text: Translation.tr("Scale")
                        value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0) * 100)
                        from: 50; to: 300; stepSize: 25
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: newVal })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_horiz"
                        text: Translation.tr("Position X")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0
                        from: 0; to: 7680; stepSize: 1
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { x: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_vert"
                        text: Translation.tr("Position Y")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0
                        from: 0; to: 4320; stepSize: 1
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { y: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("HDR & Color Management")

                NoticeBox {
                    Layout.fillWidth: true
                    visible: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported === null
                    text: Translation.tr("Couldn't confirm this display's HDR capability from its EDID. Options are shown but may not do anything.")
                }

                NoticeBox {
                    Layout.fillWidth: true
                    visible: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported === false
                    text: Translation.tr("This display's EDID does not report HDR support, so HDR options are disabled here. Open an issue in GitHub if you think this is a mistake.")
                }

                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Bit depth")
                        icon: "gradient"
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.bitdepth
                            ?? (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxBpc ?? 8)
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { bitdepth: newValue })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                        options: (() => {
                            const maxBpc = monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxBpc ?? 8
                            return [
                                { displayName: "8-bit",  icon: "filter_8", value: 8  },
                                { displayName: "10-bit", icon: "palette",   value: 10 },
                                { displayName: "12-bit", icon: "hdr_on",   value: 12 },
                            ].filter(o => o.value <= maxBpc)
                        })()
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "palette"
                        text: Translation.tr("Color management")
                        enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported !== false
                        model: [
                            { displayName: Translation.tr("Auto"),       icon: "auto_awesome",  value: "auto"    },
                            { displayName: "sRGB",                       icon: "light_mode",    value: "srgb"    },
                            { displayName: Translation.tr("Wide (P3)"),  icon: "wb_iridescent", value: "wide"    },
                            { displayName: "HDR",                        icon: "hdr_on",        value: "hdr"     },
                            { displayName: Translation.tr("HDR (EDID)"), icon: "hdr_auto",      value: "hdredid" },
                        ]
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm ?? "auto"
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { cm: newValue })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            icon: "brightness_6"
                            text: Translation.tr("SDR brightness")
                            value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrBrightness ?? 1.0) * 100)
                            from: 10; to: 300; stepSize: 5
                            onValueChanged: {
                                const newVal = value / 100.0
                                if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrBrightness ?? 1.0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrBrightness: newVal })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            icon: "contrast"
                            text: Translation.tr("SDR saturation")
                            value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrSaturation ?? 1.0) * 100)
                            from: 10; to: 200; stepSize: 5
                            onValueChanged: {
                                const newVal = value / 100.0
                                if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrSaturation ?? 1.0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrSaturation: newVal })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "wb_twilight"
                            text: Translation.tr("SDR min (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMinLuminance ?? 0
                            from: 0; to: 100; stepSize: 1
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMinLuminance ?? 0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrMinLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "wb_sunny"
                            text: Translation.tr("SDR max (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMaxLuminance ?? 250
                            from: 50; to: 2000; stepSize: 10
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMaxLuminance ?? 250)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrMaxLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "nightlight"
                            text: Translation.tr("HDR min (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.minLuminance ?? 0
                            from: 0; to: 100; stepSize: 1
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.minLuminance ?? 0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { minLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "hdr_strong"
                            text: Translation.tr("HDR peak (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxLuminance ?? 1000
                            from: 100; to: 10000; stepSize: 50
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxLuminance ?? 1000)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { maxLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    ConfigSpinBox {
                        icon: "hdr_weak"
                        text: Translation.tr("HDR max average luminance (nits)")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxAvgLuminance ?? 250
                        from: 50; to: 5000; stepSize: 10
                        enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxAvgLuminance ?? 250)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { maxAvgLuminance: value })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                    }
                }
            }
        }

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Tiling Layout")
                    icon: "responsive_layout"
                    currentValue: Config.options.hyprland.general.layout
                    onSelected: newValue => {
                        Config.options.hyprland.general.layout = newValue
                        HyprlandConfig.set("general:layout", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Dwindle"),   icon: "browse",             value: "dwindle"   },
                        { displayName: Translation.tr("Master"),    icon: "auto_awesome_mosaic", value: "master"    },
                        { displayName: Translation.tr("Scrolling"), icon: "view_carousel",       value: "scrolling" },
                    ]
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                visible: Config.options.hyprland.general.layout === "dwindle"
                title: Translation.tr("Dwindle")

                GroupedList {
                    HyprOptionSwitch {
                        optionKey: "dwindle:preserve_split"
                        buttonIcon: "call_split"
                        text: Translation.tr("Preserve split direction")
                    }
                    HyprOptionSwitch {
                        optionKey: "dwindle:smart_split"
                        buttonIcon: "smart_toy"
                        text: Translation.tr("Smart split (follow the cursor)")
                    }
                    HyprOptionSelection {
                        optionKey: "dwindle:force_split"
                        icon: "splitscreen"
                        text: Translation.tr("Force split side")
                        fallback: 0
                        options: [
                            { displayName: Translation.tr("Auto"), icon: "auto_mode", value: 0 },
                            { displayName: Translation.tr("Left / top"), icon: "align_horizontal_left", value: 1 },
                            { displayName: Translation.tr("Right / bottom"), icon: "align_horizontal_right", value: 2 }
                        ]
                    }
                    HyprOptionSpinBox {
                        optionKey: "dwindle:default_split_ratio"
                        icon: "percent"
                        text: Translation.tr("Default split ratio")
                        factor: 10
                        from: 2; to: 18; stepSize: 1
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                visible: Config.options.hyprland.general.layout === "master"
                title: Translation.tr("Master")

                GroupedList {
                    HyprOptionSelection {
                        optionKey: "master:new_status"
                        icon: "add_box"
                        text: Translation.tr("New windows become")
                        fallback: "slave"
                        options: [
                            { displayName: Translation.tr("Master"), icon: "star", value: "master" },
                            { displayName: Translation.tr("Slave"), icon: "view_agenda", value: "slave" },
                            { displayName: Translation.tr("Inherit"), icon: "content_copy", value: "inherit" }
                        ]
                    }
                    HyprOptionSelection {
                        optionKey: "master:orientation"
                        icon: "screen_rotation"
                        text: Translation.tr("Master position")
                        fallback: "left"
                        options: [
                            { displayName: Translation.tr("Left"), icon: "align_horizontal_left", value: "left" },
                            { displayName: Translation.tr("Right"), icon: "align_horizontal_right", value: "right" },
                            { displayName: Translation.tr("Top"), icon: "align_vertical_top", value: "top" },
                            { displayName: Translation.tr("Bottom"), icon: "align_vertical_bottom", value: "bottom" },
                            { displayName: Translation.tr("Center"), icon: "align_horizontal_center", value: "center" }
                        ]
                    }
                    HyprOptionSpinBox {
                        optionKey: "master:mfact"
                        icon: "aspect_ratio"
                        text: Translation.tr("Master size")
                        factor: 100
                        from: 10; to: 90; stepSize: 5
                    }
                }
            }
        }

        // Input
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Input")

            ContentSubsection {
                title: Translation.tr("Keyboard")

                GroupedList {
                    ConfigTextArea {
                        id: kbLayoutField
                        Layout.fillWidth: true
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard layout")
                        placeholderText: Translation.tr("e.g., us, es, latam")
                        Component.onCompleted: value = Config.options.hyprland.input.kbLayout
                        onValueChanged: kbLayoutDebounceTimer.restart()

                        Timer {
                            id: kbLayoutDebounceTimer
                            interval: 1000
                            repeat: false
                            onTriggered: {
                                Config.options.hyprland.input.kbLayout = kbLayoutField.value
                                HyprlandConfig.set("input:kb_layout", kbLayoutField.value)
                            }
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "numbers"
                        text: Translation.tr("Numlock by default")
                        checked: Config.options.hyprland.input.numlock
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.numlock) return
                            Config.options.hyprland.input.numlock = checked
                            HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "keyboard_return"
                        text: Translation.tr("Repeat delay (ms)")
                        value: Config.options.hyprland.input.repeatDelay
                        from: 100; to: 1000; stepSize: 10
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatDelay) return
                            Config.options.hyprland.input.repeatDelay = value
                            HyprlandConfig.set("input:repeat_delay", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Repeat rate")
                        value: Config.options.hyprland.input.repeatRate
                        from: 10; to: 100; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatRate) return
                            Config.options.hyprland.input.repeatRate = value
                            HyprlandConfig.set("input:repeat_rate", value)
                        }
                    }
                    HyprOptionText {
                        optionKey: "input:kb_variant"
                        Layout.fillWidth: true
                        buttonIcon: "keyboard_alt"
                        text: Translation.tr("Keyboard variant")
                        placeholderText: Translation.tr("e.g., intl, dvorak")
                    }
                    HyprOptionText {
                        optionKey: "input:kb_options"
                        Layout.fillWidth: true
                        buttonIcon: "keyboard_command_key"
                        text: Translation.tr("Keyboard options")
                        placeholderText: Translation.tr("e.g., caps:escape, grp:alt_shift_toggle")
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Follow mouse")
                        icon: "mouse"
                        currentValue: Config.options.hyprland.input.followMouse
                        onSelected: newValue => {
                            Config.options.hyprland.input.followMouse = newValue
                            HyprlandConfig.set("input:follow_mouse", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Disabled"), icon: "mouse",     value: 0 },
                            { displayName: Translation.tr("Full"),     icon: "open_with",  value: 1 },
                            { displayName: Translation.tr("Loose"),    icon: "drag_pan",   value: 2 },
                            { displayName: Translation.tr("Explicit"), icon: "ads_click",  value: 3 },
                        ]
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse")

                GroupedList {
                    HyprOptionSpinBox {
                        optionKey: "input:sensitivity"
                        icon: "speed"
                        text: Translation.tr("Pointer sensitivity")
                        factor: 10
                        from: -10; to: 10; stepSize: 1
                    }
                    HyprOptionSelection {
                        optionKey: "input:accel_profile"
                        icon: "trending_up"
                        text: Translation.tr("Acceleration profile")
                        fallback: ""
                        options: [
                            { displayName: Translation.tr("Default"), icon: "settings_backup_restore", value: "" },
                            { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                            { displayName: Translation.tr("Adaptive"), icon: "show_chart", value: "adaptive" }
                        ]
                    }
                    HyprOptionSwitch {
                        optionKey: "input:force_no_accel"
                        buttonIcon: "mouse"
                        text: Translation.tr("Disable acceleration (raw input)")
                    }
                    HyprOptionSwitch {
                        optionKey: "input:left_handed"
                        buttonIcon: "front_hand"
                        text: Translation.tr("Left-handed buttons")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:middle_click_paste"
                        buttonIcon: "content_paste"
                        text: Translation.tr("Middle click paste")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: Config.options.hyprland.input.touchpad.naturalScroll
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.naturalScroll) return
                            Config.options.hyprland.input.touchpad.naturalScroll = checked
                            HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: Config.options.hyprland.input.touchpad.disableWhileTyping
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.disableWhileTyping) return
                            Config.options.hyprland.input.touchpad.disableWhileTyping = checked
                            HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Clickfinger behavior")
                        checked: Config.options.hyprland.input.touchpad.clickfingerBehavior
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.clickfingerBehavior) return
                            Config.options.hyprland.input.touchpad.clickfingerBehavior = checked
                            HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                        }
                    }

                    HyprOptionSwitch {
                        optionKey: "input:touchpad:tap-to-click"
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                    }
                    HyprOptionSwitch {
                        optionKey: "input:touchpad:tap-and-drag"
                        buttonIcon: "drag_pan"
                        text: Translation.tr("Tap and drag")
                    }
                    HyprOptionSwitch {
                        optionKey: "input:touchpad:middle_button_emulation"
                        buttonIcon: "mouse"
                        text: Translation.tr("Middle button emulation (3-finger tap)")
                    }
                    ConfigSpinBox {
                        icon: "swipe"
                        text: Translation.tr("Scroll factor")
                        value: Math.round(Config.options.hyprland.input.touchpad.scrollFactor * 10)
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === Config.options.hyprland.input.touchpad.scrollFactor) return
                            Config.options.hyprland.input.touchpad.scrollFactor = newVal
                            HyprlandConfig.set("input:touchpad:scroll_factor", newVal)
                        }
                    }
                }
            }
        }

        // Idle
        ContentSection {
            id: idleSection
            icon: "timer"
            shape: MaterialShape.Shape.Cookie12Sided
            title: Translation.tr("Idle")

            readonly property list<var> unitOptions: [
                { displayName: Translation.tr("Seconds"), icon: "timer",    value: 1    },
                { displayName: Translation.tr("Minutes"), icon: "av_timer", value: 60   },
                { displayName: Translation.tr("Hours"),   icon: "schedule", value: 3600 },
            ]

            component IdleTimerRow: ConfigRow {
                id: timerRow

                property string icon
                property string label
                property int seconds: 0
                property int displayValue: 60
                property int displayUnit: 60
                property bool loaded: false

                signal edited(int newSeconds)

                onSecondsChanged: {
                    const display = idleSection.toDisplay(timerRow.seconds)
                    timerRow.displayValue = display[0]
                    timerRow.displayUnit = display[1]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.leftMargin: 8
                    OptionalMaterialSymbol {
                        icon: timerRow.icon
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        Layout.preferredWidth: 160
                        text: timerRow.label
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        Layout.preferredWidth: 130
                        value: timerRow.displayValue
                        from: 0
                        to: 9999
                        stepSize: 1
                        onValueChanged: {
                            if (!timerRow.loaded) return
                            timerRow.displayValue = value
                            timerRow.edited(value * timerRow.displayUnit)
                        }
                    }
                }
                StyledComboBox {
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                    textRole: "displayName"
                    model: idleSection.unitOptions
                    currentIndex: idleSection.unitOptions.findIndex(o => o.value === timerRow.displayUnit)
                    onActivated: index => {
                        timerRow.displayUnit = idleSection.unitOptions[index].value
                        timerRow.edited(timerRow.displayValue * timerRow.displayUnit)
                    }
                }
            }

            function toDisplay(seconds) {
                if (seconds <= 0)
                    return [0, 60]
                if (seconds % 3600 === 0)
                    return [seconds / 3600, 3600]
                if (seconds % 60 === 0)
                    return [seconds / 60, 60]
                return [seconds, 1]
            }

            function applyIdle() {
                HyprlandConfig.setIdle(
                    Config.options.hyprland.idle.lock,
                    Config.options.hyprland.idle.screenOff,
                    Config.options.hyprland.idle.suspend
                )
            }

            GroupedList {
                IdleTimerRow {
                    icon: "lock_clock"
                    label: Translation.tr("Lock screen")
                    seconds: Config.options.hyprland.idle.lock
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.lock = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
                IdleTimerRow {
                    icon: "monitor"
                    label: Translation.tr("Screen off")
                    seconds: Config.options.hyprland.idle.screenOff
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.screenOff = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
                IdleTimerRow {
                    icon: "bedtime"
                    label: Translation.tr("Standby")
                    seconds: Config.options.hyprland.idle.suspend
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.suspend = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
            }
        }

        // Visual & Aesthetics
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Visual & Aesthetics")

            GroupedList {
                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Window Rounding")
                    value: Config.options.hyprland.decoration.rounding
                    from: 0; to: 30; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.rounding) return
                        Config.options.hyprland.decoration.rounding = value
                        HyprlandConfig.set("decoration:rounding", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Blur")
                    checked: Config.options.hyprland.decoration.blur.enabled
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.decoration.blur.enabled) return
                        Config.options.hyprland.decoration.blur.enabled = checked
                        HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "blur_circular"
                    text: Translation.tr("Blur Size")
                    value: Config.options.hyprland.decoration.blur.size
                    from: 1; to: 20; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.size) return
                        Config.options.hyprland.decoration.blur.size = value
                        HyprlandConfig.set("decoration:blur:size", value)
                    }
                }

                ConfigSpinBox {
                    icon: "layers"
                    text: Translation.tr("Blur Passes")
                    value: Config.options.hyprland.decoration.blur.passes
                    from: 1; to: 6; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.passes) return
                        Config.options.hyprland.decoration.blur.passes = value
                        HyprlandConfig.set("decoration:blur:passes", value)
                    }
                }

                ConfigSpinBox {
                    icon: "margin"
                    text: Translation.tr("Gaps In")
                    value: Config.options.hyprland.general.gapsIn
                    from: 0; to: 40; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsIn) return
                        Config.options.hyprland.general.gapsIn = value
                        HyprlandConfig.set("general:gaps_in", value)
                    }
                }

                ConfigSpinBox {
                    icon: "open_in_full"
                    text: Translation.tr("Gaps Out")
                    value: Config.options.hyprland.general.gapsOut
                    from: 0; to: 60; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsOut) return
                        Config.options.hyprland.general.gapsOut = value
                        HyprlandConfig.set("general:gaps_out", value)
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Active Opacity")
                    value: Math.round(Config.options.hyprland.decoration.activeOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.activeOpacity) return
                        Config.options.hyprland.decoration.activeOpacity = newVal
                        HyprlandConfig.set("decoration:active_opacity", newVal)
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Inactive Opacity")
                    value: Math.round(Config.options.hyprland.decoration.inactiveOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.inactiveOpacity) return
                        Config.options.hyprland.decoration.inactiveOpacity = newVal
                        HyprlandConfig.set("decoration:inactive_opacity", newVal)
                    }
                }
                ConfigSpinBox {
                    icon: "border_outer"
                    text: Translation.tr("Border Size")
                    value: Config.options.hyprland.general.borderSize
                    from: 0; to: 10; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.borderSize) return
                        Config.options.hyprland.general.borderSize = value
                        HyprlandConfig.set("general:border_size", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "format_paint"
                    text: Translation.tr("Custom border colors")
                    checked: Config.options.hyprland.general.borderColor.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.general.borderColor.enable) return
                        Config.options.hyprland.general.borderColor.enable = checked
                        if (checked) HyprlandConfig.applyBorderColors()
                        else HyprlandConfig.resetBorderColors()
                    }
                }
            }
            

            ContentSubsection {
                Layout.topMargin: 10
                visible: Config.options.hyprland.general.borderColor.enable
                title: Translation.tr("Border Color Management")
                GroupedList {
                    visible: Config.options.hyprland.general.borderColor.enable

                    ColorSelectionArray {
                        icon: "border_color"
                        text: Translation.tr("Active border")
                        options: page.borderColorRoles
                        currentValue: Config.options.hyprland.general.borderColor.activeRole
                        onSelected: newValue => {
                            Config.options.hyprland.general.borderColor.activeRole = newValue
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Active border opacity")
                        value: Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100)
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            // Compared as integers: the spin box only holds whole percents.
                            if (value === Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100)) return
                            Config.options.hyprland.general.borderColor.activeOpacity = value / 100.0
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ColorSelectionArray {
                        icon: "border_color"
                        text: Translation.tr("Inactive border")
                        options: page.borderColorRoles
                        currentValue: Config.options.hyprland.general.borderColor.inactiveRole
                        onSelected: newValue => {
                            Config.options.hyprland.general.borderColor.inactiveRole = newValue
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Inactive border opacity")
                        value: Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100)
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            // Compared as integers: the spin box only holds whole percents.
                            if (value === Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100)) return
                            Config.options.hyprland.general.borderColor.inactiveOpacity = value / 100.0
                            HyprlandConfig.applyBorderColors()
                        }
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Shadows, dimming & blur")

                GroupedList {
                    HyprOptionSwitch {
                        optionKey: "decoration:shadow:enabled"
                        buttonIcon: "shadow"
                        text: Translation.tr("Window shadows")
                    }
                    HyprOptionSpinBox {
                        optionKey: "decoration:shadow:range"
                        icon: "blur_on"
                        text: Translation.tr("Shadow range")
                        from: 0; to: 50; stepSize: 1
                    }
                    HyprOptionSwitch {
                        optionKey: "decoration:dim_inactive"
                        buttonIcon: "brightness_low"
                        text: Translation.tr("Dim inactive windows")
                    }
                    HyprOptionSpinBox {
                        optionKey: "decoration:dim_strength"
                        icon: "contrast"
                        text: Translation.tr("Dim strength")
                        factor: 100
                        from: 0; to: 100; stepSize: 5
                    }
                    HyprOptionSpinBox {
                        optionKey: "decoration:blur:noise"
                        icon: "grain"
                        text: Translation.tr("Blur noise")
                        factor: 100
                        from: 0; to: 50; stepSize: 1
                    }
                    HyprOptionSpinBox {
                        optionKey: "decoration:blur:vibrancy"
                        icon: "palette"
                        text: Translation.tr("Blur vibrancy")
                        factor: 100
                        from: 0; to: 100; stepSize: 5
                    }
                }
            }
        }

        // Misc
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Misc")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "center_focus_strong"
                    text: Translation.tr("Focus on activate")
                    checked: Config.options.hyprland.misc.focusOnActivate
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.misc.focusOnActivate) return
                        Config.options.hyprland.misc.focusOnActivate = checked
                        HyprlandConfig.set("misc:focus_on_activate", checked ? 1 : 0)
                    }
                }
                    HyprOptionSelection {
                        optionKey: "misc:vrr"
                        icon: "slow_motion_video"
                        text: Translation.tr("Variable refresh rate (VRR)")
                        fallback: 0
                        options: [
                            { displayName: Translation.tr("Off"), icon: "block", value: 0 },
                            { displayName: Translation.tr("On"), icon: "check_circle", value: 1 },
                            { displayName: Translation.tr("Fullscreen only"), icon: "fullscreen", value: 2 }
                        ]
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:enable_swallow"
                        buttonIcon: "call_merge"
                        text: Translation.tr("Window swallowing (terminal swallows launched apps)")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:animate_manual_resizes"
                        buttonIcon: "animation"
                        text: Translation.tr("Animate manual resizes")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:close_special_on_empty"
                        buttonIcon: "close_fullscreen"
                        text: Translation.tr("Close empty special workspace")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:disable_hyprland_logo"
                        buttonIcon: "hide_image"
                        text: Translation.tr("Hide the Hyprland logo")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:disable_splash_rendering"
                        buttonIcon: "subtitles_off"
                        text: Translation.tr("Hide the splash text")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:mouse_move_enables_dpms"
                        buttonIcon: "mouse"
                        text: Translation.tr("Mouse wakes the screen")
                    }
                    HyprOptionSwitch {
                        optionKey: "misc:key_press_enables_dpms"
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keys wake the screen")
                    }
                    HyprOptionSwitch {
                        optionKey: "xwayland:force_zero_scaling"
                        buttonIcon: "zoom_out_map"
                        text: Translation.tr("XWayland: sharp apps (force zero scaling)")
                    }
                    HyprOptionSwitch {
                        optionKey: "group:auto_group"
                        buttonIcon: "tab_group"
                        text: Translation.tr("Auto-group dragged windows")
                    }
                    HyprOptionSwitch {
                        optionKey: "binds:workspace_back_and_forth"
                        buttonIcon: "swap_horiz"
                        text: Translation.tr("Switching to the current workspace goes back")
                    }
                    HyprOptionSwitch {
                        optionKey: "binds:allow_workspace_cycles"
                        buttonIcon: "cached"
                        text: Translation.tr("Allow workspace cycles")
                    }
                    HyprOptionSelection {
                        optionKey: "render:direct_scanout"
                        icon: "speed"
                        text: Translation.tr("Direct scanout (fullscreen apps)")
                        fallback: 0
                        options: [
                            { displayName: Translation.tr("Off"), icon: "block", value: 0 },
                            { displayName: Translation.tr("On"), icon: "check_circle", value: 1 },
                            { displayName: Translation.tr("Auto"), icon: "auto_mode", value: 2 }
                        ]
                    }
            }
        }

        // Windows & Cursor
        ContentSection {
            icon: "pan_tool"
            shape: MaterialShape.Shape.Cookie9Sided
            title: Translation.tr("Windows & Cursor")

            ContentSubsection {
                title: Translation.tr("Windows")

                GroupedList {
                    HyprOptionSwitch {
                        optionKey: "general:resize_on_border"
                        buttonIcon: "open_in_full"
                        text: Translation.tr("Resize windows by dragging their borders")
                    }
                    HyprOptionSpinBox {
                        optionKey: "general:extend_border_grab_area"
                        icon: "border_outer"
                        text: Translation.tr("Border grab area (px)")
                        from: 0; to: 60; stepSize: 1
                    }
                    HyprOptionSwitch {
                        optionKey: "general:allow_tearing"
                        buttonIcon: "sports_esports"
                        text: Translation.tr("Allow tearing (lower latency in games)")
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Cursor")

                GroupedList {
                    HyprOptionSelection {
                        optionKey: "cursor:no_hardware_cursors"
                        icon: "mouse"
                        text: Translation.tr("Hardware cursor")
                        fallback: 2
                        options: [
                            { displayName: Translation.tr("Auto"), icon: "auto_mode", value: 2 },
                            { displayName: Translation.tr("On"), icon: "check_circle", value: 0 },
                            { displayName: Translation.tr("Off"), icon: "block", value: 1 }
                        ]
                    }
                    HyprOptionSpinBox {
                        optionKey: "cursor:inactive_timeout"
                        icon: "hourglass_empty"
                        text: Translation.tr("Hide cursor after inactivity (s, 0 = never)")
                        from: 0; to: 60; stepSize: 1
                    }
                    HyprOptionSwitch {
                        optionKey: "cursor:hide_on_key_press"
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Hide cursor while typing")
                    }
                    HyprOptionSelection {
                        optionKey: "cursor:warp_on_change_workspace"
                        icon: "ads_click"
                        text: Translation.tr("Move cursor to the new workspace")
                        fallback: 0
                        options: [
                            { displayName: Translation.tr("Off"), icon: "block", value: 0 },
                            { displayName: Translation.tr("On"), icon: "check_circle", value: 1 },
                            { displayName: Translation.tr("Force"), icon: "bolt", value: 2 }
                        ]
                    }
                }
            }
        }

        // Autostart Apps
        ContentSection {
            icon: "app_registration"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Autostart Apps")
            Layout.fillWidth: true

            AutostartApps {}
        }

        // Animations
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.hyprland.animations.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.animations.enable) return
                        Config.options.hyprland.animations.enable = checked
                        HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Presets")
                    icon: "present_to_all"
                    currentValue: Config.options.hyprland.animations.animation
                    onSelected: newValue => {
                        Config.options.hyprland.animations.animation = newValue
                        saveAnimProc.command = [
                            "python3",
                            HyprlandConfig.configuratorScriptPath,
                            "--anim-preset", newValue
                        ]
                        saveAnimProc.running = true
                    }
                    options: [
                        { displayName: Translation.tr("Elastic"),   icon: "move_selection_right", value: "fast"   },
                        { displayName: Translation.tr("Normal"),    icon: "animation",            value: "normal" },
                        { displayName: Translation.tr("Niri Like"), icon: "mobiledata_arrows",    value: "niri"   },
                    ]
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 15
                text: Translation.tr("Animation presets require a require line in your hyprland.lua. Add the following line to enable presets:") + '\n\nrequire("hyprland/shellOverrides/animations")'

                Item { Layout.fillWidth: true }

                RippleButtonWithIcon {
                    id: copySourceButton
                    property bool justCopied: false
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: justCopied ? "check" : "content_copy"
                    mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy line")
                    onClicked: {
                        copySourceButton.justCopied = true
                        Quickshell.clipboardText = 'require("hyprland/shellOverrides/animations")'
                        revertSourceTimer.restart()
                    }
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    Timer {
                        id: revertSourceTimer
                        interval: 1500
                        onTriggered: copySourceButton.justCopied = false
                    }
                }
            }

            Process {
                id: saveAnimProc
                onRunningChanged: if (!running) reloadAnimProc.running = true
            }
            Process {
                id: reloadAnimProc
                command: ["hyprctl", "reload"]
            }
        }
    }
}