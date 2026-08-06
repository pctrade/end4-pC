import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.niri

ContentPage {
    id: page
    forceWidth: true

    // "ok" | "misplaced" | "missing"
    property string includeStatus: "ok"

    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    Component.onCompleted: includeCheckProc.running = true

    Process {
        id: includeCheckProc
        // ok = all include lines present and nothing but blanks/comments/includes after them
        command: ["sh", "-c", `cfg="$HOME/.config/niri/config.kdl"
missing=0
for f in shell outputs autostart binds; do
    grep -qs "qssettings/$f.kdl" "$cfg" || missing=1
done
if [ "$missing" = 1 ]; then echo missing
elif awk '/qssettings\\/shell.kdl/ {found=1; next} found && NF && $0 !~ /qssettings/ && $0 !~ /^[ \\t]*\\/\\// {bad=1} END {exit bad}' "$cfg"; then echo ok
else echo misplaced
fi`]
        stdout: StdioCollector {
            onStreamFinished: page.includeStatus = text.trim()
        }
    }

    Process {
        id: setupIncludesProc
        // Backs up config.kdl, strips qssettings include lines wherever they are,
        // re-appends them at the end. Writes through symlinks (stow-managed dotfiles).
        command: ["sh", "-c", `cfg="$HOME/.config/niri/config.kdl"
cp -L "$cfg" "$cfg.backup.$(date +%s)" || exit 1
tmp=$(mktemp)
grep -vE 'qssettings/(shell|outputs|autostart|binds)\\.kdl' "$cfg" > "$tmp"
printf '\\ninclude optional=true "qssettings/shell.kdl"\\ninclude optional=true "qssettings/outputs.kdl"\\ninclude optional=true "qssettings/autostart.kdl"\\ninclude optional=true "qssettings/binds.kdl"\\n' >> "$tmp"
cat "$tmp" > "$cfg"
rm -f "$tmp"`]
        onExited: includeCheckProc.running = true
    }

    MonitorConfigOption { id: monitorConfig }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        NoticeBox {
            visible: page.includeStatus !== "ok"
            Layout.fillWidth: true
            text: page.includeStatus === "misplaced"
                ? Translation.tr("The qssettings include lines are in your config.kdl but not at the end. Later config wins in niri, so your own settings currently override these. Fix moves them to the bottom (a backup of config.kdl is made first).")
                : Translation.tr("These settings are saved to ~/.config/niri/qssettings/. Setup adds the include lines at the end of your config.kdl (a backup is made first):") + "\n\n" + NiriConfig.includeLines

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                Layout.fillWidth: false
                buttonRadius: Appearance.rounding.small
                materialIcon: page.includeStatus === "misplaced" ? "build" : "auto_fix_high"
                mainText: page.includeStatus === "misplaced" ? Translation.tr("Fix") : Translation.tr("Setup")
                onClicked: setupIncludesProc.running = true
                colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
            }

            RippleButtonWithIcon {
                id: copyIncludesButton
                property bool justCopied: false
                Layout.fillWidth: false
                buttonRadius: Appearance.rounding.small
                materialIcon: justCopied ? "check" : "content_copy"
                mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy lines")
                onClicked: {
                    copyIncludesButton.justCopied = true
                    Quickshell.clipboardText = NiriConfig.includeLines
                    revertCopyTimer.restart()
                }
                colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                Timer {
                    id: revertCopyTimer
                    interval: 1500
                    onTriggered: copyIncludesButton.justCopied = false
                }
            }
        }

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

                    ConfigSwitch {
                        buttonIcon: "autoplay"
                        text: Translation.tr("Variable refresh rate (VRR)")
                        checked: monitorConfig.monitors[monitorCanvas.selectedIndex]?.vrr ?? false
                        onCheckedChanged: {
                            if (checked === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.vrr ?? false)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { vrr: checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
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
        }

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            GroupedList {
                ConfigSpinBox {
                    icon: "margin"
                    text: Translation.tr("Gaps")
                    value: NiriConfig.options.layout.gaps
                    from: 0; to: 60; stepSize: 1
                    onValueChanged: {
                        if (value === NiriConfig.options.layout.gaps) return
                        NiriConfig.options.layout.gaps = value
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Center focused column")
                    icon: "align_horizontal_center"
                    currentValue: NiriConfig.options.layout.centerFocusedColumn
                    onSelected: newValue => {
                        NiriConfig.options.layout.centerFocusedColumn = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Never"),       icon: "close",                       value: "never" },
                        { displayName: Translation.tr("On overflow"), icon: "keyboard_double_arrow_right", value: "on-overflow" },
                        { displayName: Translation.tr("Always"),      icon: "align_horizontal_center",     value: "always" },
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Default column width")
                    icon: "width"
                    currentValue: NiriConfig.options.layout.defaultColumnWidth
                    onSelected: newValue => {
                        NiriConfig.options.layout.defaultColumnWidth = newValue
                    }
                    options: [
                        { displayName: "⅓", icon: "crop_portrait", value: 0.33333 },
                        { displayName: "½", icon: "crop_square",   value: 0.5 },
                        { displayName: "⅔", icon: "crop_landscape", value: 0.66667 },
                    ]
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
                        Component.onCompleted: value = NiriConfig.options.input.kbLayout
                        onValueChanged: kbLayoutDebounceTimer.restart()

                        Timer {
                            id: kbLayoutDebounceTimer
                            interval: 1000
                            repeat: false
                            onTriggered: {
                                NiriConfig.options.input.kbLayout = kbLayoutField.value
                            }
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "numbers"
                        text: Translation.tr("Numlock by default")
                        checked: NiriConfig.options.input.numlock
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.numlock) return
                            NiriConfig.options.input.numlock = checked
                        }
                    }

                    ConfigSpinBox {
                        icon: "keyboard_return"
                        text: Translation.tr("Repeat delay (ms)")
                        value: NiriConfig.options.input.repeatDelay
                        from: 100; to: 1000; stepSize: 10
                        onValueChanged: {
                            if (value === NiriConfig.options.input.repeatDelay) return
                            NiriConfig.options.input.repeatDelay = value
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Repeat rate")
                        value: NiriConfig.options.input.repeatRate
                        from: 10; to: 100; stepSize: 1
                        onValueChanged: {
                            if (value === NiriConfig.options.input.repeatRate) return
                            NiriConfig.options.input.repeatRate = value
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "mouse"
                        text: Translation.tr("Focus follows mouse")
                        checked: NiriConfig.options.input.focusFollowsMouse
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.focusFollowsMouse) return
                            NiriConfig.options.input.focusFollowsMouse = checked
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                        checked: NiriConfig.options.input.touchpad.tap
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.touchpad.tap) return
                            NiriConfig.options.input.touchpad.tap = checked
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: NiriConfig.options.input.touchpad.naturalScroll
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.touchpad.naturalScroll) return
                            NiriConfig.options.input.touchpad.naturalScroll = checked
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: NiriConfig.options.input.touchpad.disableWhileTyping
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.touchpad.disableWhileTyping) return
                            NiriConfig.options.input.touchpad.disableWhileTyping = checked
                        }
                    }

                    ConfigSpinBox {
                        icon: "swipe"
                        text: Translation.tr("Scroll factor")
                        value: Math.round(NiriConfig.options.input.touchpad.scrollFactor * 10)
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === NiriConfig.options.input.touchpad.scrollFactor) return
                            NiriConfig.options.input.touchpad.scrollFactor = newVal
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Acceleration speed")
                        value: Math.round(NiriConfig.options.input.touchpad.accelSpeed * 10)
                        from: -10; to: 10; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === NiriConfig.options.input.touchpad.accelSpeed) return
                            NiriConfig.options.input.touchpad.accelSpeed = newVal
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: NiriConfig.options.input.mouse.naturalScroll
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.input.mouse.naturalScroll) return
                            NiriConfig.options.input.mouse.naturalScroll = checked
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Acceleration speed")
                        value: Math.round(NiriConfig.options.input.mouse.accelSpeed * 10)
                        from: -10; to: 10; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === NiriConfig.options.input.mouse.accelSpeed) return
                            NiriConfig.options.input.mouse.accelSpeed = newVal
                        }
                    }
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
                    value: NiriConfig.options.decoration.rounding
                    from: 0; to: 30; stepSize: 1
                    onValueChanged: {
                        if (value === NiriConfig.options.decoration.rounding) return
                        NiriConfig.options.decoration.rounding = value
                    }
                }

                ConfigSwitch {
                    buttonIcon: "border_outer"
                    text: Translation.tr("Border")
                    checked: NiriConfig.options.decoration.border.enable
                    onCheckedChanged: {
                        if (checked === NiriConfig.options.decoration.border.enable) return
                        NiriConfig.options.decoration.border.enable = checked
                    }
                }

                ConfigSpinBox {
                    icon: "border_outer"
                    text: Translation.tr("Border Size")
                    value: NiriConfig.options.decoration.border.width
                    from: 0; to: 10; stepSize: 1
                    onValueChanged: {
                        if (value === NiriConfig.options.decoration.border.width) return
                        NiriConfig.options.decoration.border.width = value
                    }
                }

                ConfigSwitch {
                    buttonIcon: "center_focus_strong"
                    text: Translation.tr("Focus ring")
                    checked: NiriConfig.options.decoration.focusRing.enable
                    onCheckedChanged: {
                        if (checked === NiriConfig.options.decoration.focusRing.enable) return
                        NiriConfig.options.decoration.focusRing.enable = checked
                    }
                }

                ConfigSpinBox {
                    icon: "center_focus_weak"
                    text: Translation.tr("Focus ring width")
                    value: NiriConfig.options.decoration.focusRing.width
                    from: 0; to: 10; stepSize: 1
                    onValueChanged: {
                        if (value === NiriConfig.options.decoration.focusRing.width) return
                        NiriConfig.options.decoration.focusRing.width = value
                    }
                }

                ConfigSwitch {
                    buttonIcon: "ev_shadow"
                    text: Translation.tr("Shadows")
                    checked: NiriConfig.options.decoration.shadow.enable
                    onCheckedChanged: {
                        if (checked === NiriConfig.options.decoration.shadow.enable) return
                        NiriConfig.options.decoration.shadow.enable = checked
                    }
                }

                ConfigSpinBox {
                    icon: "blur_linear"
                    text: Translation.tr("Shadow softness")
                    value: NiriConfig.options.decoration.shadow.softness
                    from: 0; to: 100; stepSize: 5
                    onValueChanged: {
                        if (value === NiriConfig.options.decoration.shadow.softness) return
                        NiriConfig.options.decoration.shadow.softness = value
                    }
                }

                ConfigSpinBox {
                    icon: "expand_all"
                    text: Translation.tr("Shadow spread")
                    value: NiriConfig.options.decoration.shadow.spread
                    from: 0; to: 50; stepSize: 1
                    onValueChanged: {
                        if (value === NiriConfig.options.decoration.shadow.spread) return
                        NiriConfig.options.decoration.shadow.spread = value
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Blur")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "blur_on"
                        text: Translation.tr("Blur")
                        checked: NiriConfig.options.decoration.blur.enable
                        onCheckedChanged: {
                            if (checked === NiriConfig.options.decoration.blur.enable) return
                            NiriConfig.options.decoration.blur.enable = checked
                        }
                    }

                    ConfigSpinBox {
                        icon: "layers"
                        text: Translation.tr("Blur Passes")
                        value: NiriConfig.options.decoration.blur.passes
                        from: 1; to: 6; stepSize: 1
                        onValueChanged: {
                            if (value === NiriConfig.options.decoration.blur.passes) return
                            NiriConfig.options.decoration.blur.passes = value
                        }
                    }

                    ConfigSpinBox {
                        icon: "blur_circular"
                        text: Translation.tr("Blur Offset")
                        value: Math.round(NiriConfig.options.decoration.blur.offset * 10)
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === NiriConfig.options.decoration.blur.offset) return
                            NiriConfig.options.decoration.blur.offset = newVal
                        }
                    }

                    ConfigSpinBox {
                        icon: "grain"
                        text: Translation.tr("Blur Noise (%)")
                        value: Math.round(NiriConfig.options.decoration.blur.noise * 100)
                        from: 0; to: 20; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === NiriConfig.options.decoration.blur.noise) return
                            NiriConfig.options.decoration.blur.noise = newVal
                        }
                    }

                    ConfigSpinBox {
                        icon: "palette"
                        text: Translation.tr("Blur Saturation (%)")
                        value: Math.round(NiriConfig.options.decoration.blur.saturation * 100)
                        from: 0; to: 300; stepSize: 10
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === NiriConfig.options.decoration.blur.saturation) return
                            NiriConfig.options.decoration.blur.saturation = newVal
                        }
                    }
                }
            }
        }

        // Cursor
        ContentSection {
            icon: "mouse"
            shape: MaterialShape.Shape.Arrow
            title: Translation.tr("Cursor")
            GroupedList {
                ConfigComboBox {
                    buttonIcon: "mouse"
                    fieldWidth: 70
                    text: Translation.tr("Cursor theme")
                    model: [{ displayName: Translation.tr("Default"), value: "" }]
                        .concat(SystemTheming.cursorThemes.map(t => ({ displayName: t, value: t })))
                    currentValue: NiriConfig.options.cursor.theme
                    onSelected: newValue => SystemTheming.applyCursorTheme(newValue, NiriConfig.options.cursor.size)
                }

                ConfigSpinBox {
                    id: cursorSizeSpin
                    icon: "zoom_in"
                    text: Translation.tr("Cursor size")
                    value: NiriConfig.options.cursor.size
                    from: 16; to: 64; stepSize: 2
                    onValueChanged: {
                        if (value === NiriConfig.options.cursor.size) return
                        NiriConfig.options.cursor.size = value
                        cursorSizeApplyTimer.restart()
                    }
                    Timer {
                        id: cursorSizeApplyTimer
                        interval: 500
                        repeat: false
                        onTriggered: SystemTheming.applyCursorTheme(NiriConfig.options.cursor.theme, cursorSizeSpin.value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "keyboard_hide"
                    text: Translation.tr("Hide while typing")
                    checked: NiriConfig.options.cursor.hideWhenTyping
                    onCheckedChanged: {
                        if (checked === NiriConfig.options.cursor.hideWhenTyping) return
                        NiriConfig.options.cursor.hideWhenTyping = checked
                    }
                }
            }
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
                    checked: NiriConfig.options.animations.enable
                    onCheckedChanged: {
                        if (checked === NiriConfig.options.animations.enable) return
                        NiriConfig.options.animations.enable = checked
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Slowdown (×10)")
                    value: Math.round(NiriConfig.options.animations.slowdown * 10)
                    from: 1; to: 50; stepSize: 1
                    onValueChanged: {
                        const newVal = value / 10.0
                        if (newVal === NiriConfig.options.animations.slowdown) return
                        NiriConfig.options.animations.slowdown = newVal
                    }
                }
            }
        }
    }
}
