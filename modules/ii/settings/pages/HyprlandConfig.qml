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

    // ── Options ──────────────────────────────────────────────────────────────
    HyprlandConfigOption { id: rounding;      key: "decoration:rounding" }
    HyprlandConfigOption { id: blurEnabled;   key: "decoration:blur:enabled" }
    HyprlandConfigOption { id: blurSize;      key: "decoration:blur:size" }
    HyprlandConfigOption { id: blurPasses;    key: "decoration:blur:passes" }
    HyprlandConfigOption { id: shadowEnabled; key: "decoration:shadow:enabled" }
    HyprlandConfigOption { id: shadowRange;   key: "decoration:shadow:range" }
    HyprlandConfigOption { id: borderSize;    key: "general:border_size" }
    HyprlandConfigOption { id: gapsIn;        key: "general:gaps_in" }
    HyprlandConfigOption { id: gapsOut;       key: "general:gaps_out" }
    HyprlandConfigOption { id: animEnabled;   key: "animations:enabled" }
    HyprlandConfigOption { id: activeBorder;  key: "general:col.active_border" }
    HyprlandConfigOption { id: inactiveBorder;key: "general:col.inactive_border" }
    HyprlandConfigOption { id: activeOpacity; key: "decoration:active_opacity" }
    HyprlandConfigOption { id: inactiveOpacity; key: "decoration:inactive_opacity" }
    HyprlandConfigOption { id: layout;        key: "general:layout" }
    HyprlandConfigOption { id: kbLayout;      key: "input:kb_layout" }
    HyprlandConfigOption { id: numlock;       key: "input:numlock_by_default" }
    HyprlandConfigOption { id: repeatDelay;   key: "input:repeat_delay" }
    HyprlandConfigOption { id: repeatRate;    key: "input:repeat_rate" }
    HyprlandConfigOption { id: followMouse;   key: "input:follow_mouse" }
    HyprlandConfigOption { id: naturalScroll; key: "input:touchpad:natural_scroll" }
    HyprlandConfigOption { id: disableTyping; key: "input:touchpad:disable_while_typing" }
    HyprlandConfigOption { id: scrollFactor;  key: "input:touchpad:scroll_factor" }
    HyprlandConfigOption { id: clickfinger;   key: "input:touchpad:clickfinger_behavior" }
    MonitorConfigOption  { id: monitorConfig }

    // ── Animation presets ────────────────────────────────────────────────────
    property string presetFast: `animations {
  bezier = pc_wobble, 0.15, 1.15, 0.35, 1.0
  bezier = pc_decel, 0.05, 0.9, 0.1, 1.05
  bezier = pc_accel, 0.3, 0, 0.8, 0.15
  animation = windowsIn, 1, 5, pc_wobble, slide
  animation = windowsOut, 1, 5, pc_accel, slide
  animation = windowsMove, 1, 5, pc_decel, slide
  animation = fadeIn, 1, 4, default
  animation = fadeOut, 1, 4, default
  animation = layersIn, 1, 4, pc_decel, slide
  animation = layersOut, 1, 4, pc_accel, slide
  animation = workspaces, 1, 6, pc_decel, slide
  animation = specialWorkspaceIn, 1, 2, pc_wobble, slidevert
  animation = specialWorkspaceOut, 1, 2, pc_accel, slidevert
}`

    property string presetNormal: `animations {
  bezier = emphasizedDecel, 0.05, 0.7, 0.1, 1
  bezier = emphasizedAccel, 0.3, 0, 0.8, 0.15
  bezier = menu_decel, 0.1, 1, 0, 1
  bezier = menu_accel, 0.52, 0.03, 0.72, 0.08
  bezier = stall, 1, -0.1, 0.7, 0.85
  animation = windowsIn, 1, 3, emphasizedDecel, popin 80%
  animation = fadeIn, 1, 3, emphasizedDecel
  animation = windowsOut, 1, 2, emphasizedDecel, popin 90%
  animation = fadeOut, 1, 2, emphasizedDecel
  animation = windowsMove, 1, 3, emphasizedDecel, slide
  animation = border, 1, 10, emphasizedDecel
  animation = layersIn, 1, 2.7, emphasizedDecel, popin 93%
  animation = layersOut, 1, 2.4, menu_accel, popin 94%
  animation = fadeLayersIn, 1, 0.5, menu_decel
  animation = fadeLayersOut, 1, 2.7, stall
  animation = workspaces, 1, 7, menu_decel, slide
  animation = specialWorkspaceIn, 1, 2.8, emphasizedDecel, slidevert
  animation = specialWorkspaceOut, 1, 1.2, emphasizedAccel, slidevert
}`

    property string presetNiri: `animations {
  bezier = niri_wobble, 0.15, 1.15, 0.35, 1.0
  bezier = niri_decel, 0.05, 0.9, 0.1, 1.05
  bezier = niri_accel, 0.3, 0, 0.8, 0.15
  animation = windowsIn, 1, 5, niri_wobble, slide
  animation = windowsOut, 1, 5, niri_accel, slide
  animation = windowsMove, 1, 5, niri_decel, slide
  animation = fadeIn, 1, 4, default
  animation = fadeOut, 1, 4, default
  animation = layersIn, 1, 4, niri_decel, slide
  animation = layersOut, 1, 4, niri_accel, slide
  animation = workspaces, 1, 6, niri_decel, slidevert
  animation = specialWorkspaceIn, 1, 4, niri_wobble, slidevert
  animation = specialWorkspaceOut, 1, 4, niri_accel, slidevert
}`


    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20
        // ── Displays ─────────────────────────────────────────────────────────────
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
                title: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? "")
                    + " · "
                    + (monitorConfig.monitors[monitorCanvas.selectedIndex]?.description ?? "")

                ConfigSwitch {
                    buttonIcon: "tv_off"
                    text: Translation.tr("Enabled")
                    checked: !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)
                    onCheckedChanged: {
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Resolution & Refresh Rate")
                    StyledComboBoxSearch {
                        buttonIcon: "aspect_ratio"
                        model: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.availableModes ?? [])
                            .map(mode => ({ display: mode, value: mode }))
                        textRole: "display"
                        currentIndex: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.availableModes ?? [])
                            .indexOf(monitorConfig.monitors[monitorCanvas.selectedIndex]?.currentMode ?? "")
                        onActivated: {
                            const mon = monitorConfig.monitors[monitorCanvas.selectedIndex]
                            const mode = mon.availableModes[currentIndex]
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
                }

                ContentSubsection {
                    title: Translation.tr("Orientation")
                    ConfigSelectionArray {
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
                }

                ConfigSpinBox {
                    icon: "zoom_in"
                    text: Translation.tr("Scale")
                    value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0) * 100)
                    from: 50; to: 300; stepSize: 25
                    onValueChanged: {
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: value / 100.0 })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }

                ConfigSpinBox {
                    icon: "swap_horiz"
                    text: Translation.tr("Position X")
                    value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0
                    from: 0; to: 7680; stepSize: 1
                    onValueChanged: {
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
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { y: value })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }
            }
        }

        // ── Layout ───────────────────────────────────────────────────────────────
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            ContentSubsection {
                title: Translation.tr("Tiling Layout")
                ConfigSelectionArray {
                    currentValue: layout.value ?? "dwindle"
                    onSelected: newValue => HyprlandConfig.set("general:layout", newValue)
                    options: [
                        { displayName: Translation.tr("Dwindle"),   icon: "browse",             value: "dwindle"   },
                        { displayName: Translation.tr("Master"),    icon: "auto_awesome_mosaic", value: "master"    },
                        { displayName: Translation.tr("Scrolling"), icon: "view_carousel",       value: "scrolling" },
                    ]
                }
            }
        }

        // ── Input ────────────────────────────────────────────────────────────────
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Input")

            ContentSubsection {
                title: Translation.tr("Keyboard")

                MaterialTextArea {
                    id: kbLayoutTextArea
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Keyboard layout (e.g., us, es, latam)")
                    wrapMode: TextEdit.NoWrap
                    Component.onCompleted: text = kbLayout.value ?? "us"
                    Connections {
                        target: kbLayout
                        function onValueChanged() {
                            if (kbLayoutTextArea.text !== kbLayout.value)
                                kbLayoutTextArea.text = kbLayout.value ?? "us"
                        }
                    }
                    Timer {
                        id: kbLayoutDebounceTimer
                        interval: 1000
                        running: false
                        onTriggered: HyprlandConfig.set("input:kb_layout", kbLayoutTextArea.text)
                    }
                    onTextChanged: kbLayoutDebounceTimer.restart()
                }

                ConfigSwitch {
                    buttonIcon: "numbers"
                    text: Translation.tr("Numlock by default")
                    checked: numlock.value ?? true
                    onCheckedChanged: HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                }

                ConfigSpinBox {
                    icon: "keyboard_return"
                    text: Translation.tr("Repeat delay (ms)")
                    value: repeatDelay.value ?? 250
                    from: 100; to: 1000; stepSize: 10
                    onValueChanged: HyprlandConfig.set("input:repeat_delay", value)
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Repeat rate")
                    value: repeatRate.value ?? 35
                    from: 10; to: 100; stepSize: 1
                    onValueChanged: HyprlandConfig.set("input:repeat_rate", value)
                }

                ConfigSelectionArray {
                    currentValue: followMouse.value ?? 1
                    onSelected: newValue => HyprlandConfig.set("input:follow_mouse", newValue)
                    options: [
                        { displayName: Translation.tr("Disabled"), icon: "mouse",    value: 0 },
                        { displayName: Translation.tr("Full"),     icon: "open_with", value: 1 },
                        { displayName: Translation.tr("Loose"),    icon: "drag_pan",  value: 2 },
                        { displayName: Translation.tr("Explicit"), icon: "ads_click", value: 3 },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")

                ConfigSwitch {
                    buttonIcon: "swap_vert"
                    text: Translation.tr("Natural scroll")
                    checked: naturalScroll.value ?? false
                    onCheckedChanged: HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                }

                ConfigSwitch {
                    buttonIcon: "keyboard_hide"
                    text: Translation.tr("Disable while typing")
                    checked: disableTyping.value ?? true
                    onCheckedChanged: HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                }

                ConfigSwitch {
                    buttonIcon: "touch_app"
                    text: Translation.tr("Clickfinger behavior")
                    checked: clickfinger.value ?? false
                    onCheckedChanged: HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                }

                ConfigSpinBox {
                    icon: "swipe"
                    text: Translation.tr("Scroll factor")
                    value: Math.round((scrollFactor.value ?? 0.7) * 10)
                    from: 1; to: 30; stepSize: 1
                    onValueChanged: HyprlandConfig.set("input:touchpad:scroll_factor", value / 10.0)
                }
            }
        }

        // ── Visual & Aesthetics ──────────────────────────────────────────────────
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Visual & Aesthetics")

            ConfigSpinBox {
                icon: "rounded_corner"
                text: Translation.tr("Window Rounding")
                value: rounding.value ?? 22
                from: 0; to: 30; stepSize: 1
                onValueChanged: HyprlandConfig.set("decoration:rounding", value)
            }

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Blur")
                checked: blurEnabled.value ?? true
                onCheckedChanged: HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
            }

            ConfigSpinBox {
                icon: "blur_circular"
                text: Translation.tr("Blur Size")
                value: blurSize.value ?? 1
                from: 1; to: 20; stepSize: 1
                onValueChanged: HyprlandConfig.set("decoration:blur:size", value)
            }

            ConfigSpinBox {
                icon: "layers"
                text: Translation.tr("Blur Passes")
                value: blurPasses.value ?? 3
                from: 1; to: 6; stepSize: 1
                onValueChanged: HyprlandConfig.set("decoration:blur:passes", value)
            }

            ConfigSpinBox {
                icon: "border_outer"
                text: Translation.tr("Border Size")
                value: borderSize.value ?? 1
                from: 0; to: 10; stepSize: 1
                onValueChanged: HyprlandConfig.set("general:border_size", value)
            }

            ConfigSpinBox {
                icon: "margin"
                text: Translation.tr("Gaps In")
                value: gapsIn.value ?? 2
                from: 0; to: 40; stepSize: 1
                onValueChanged: HyprlandConfig.set("general:gaps_in", value)
            }

            ConfigSpinBox {
                icon: "open_in_full"
                text: Translation.tr("Gaps Out")
                value: gapsOut.value ?? 5
                from: 0; to: 60; stepSize: 1
                onValueChanged: HyprlandConfig.set("general:gaps_out", value)
            }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Active Opacity")
                value: Math.round((activeOpacity.value ?? 1.0) * 100)
                from: 10; to: 100; stepSize: 5
                onValueChanged: HyprlandConfig.set("decoration:active_opacity", value / 100.0)
            }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Inactive Opacity")
                value: Math.round((inactiveOpacity.value ?? 0.9) * 100)
                from: 10; to: 100; stepSize: 5
                onValueChanged: HyprlandConfig.set("decoration:inactive_opacity", value / 100.0)
            }
        }

        // ── Autostart Apps ───────────────────────────────────────────────────────────
        AutostartApps {}
        
        // ── Animations ───────────────────────────────────────────────────────────
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable Animations")
                checked: animEnabled.value ?? true
                onCheckedChanged: HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
            }

            ContentSubsection {
                title: Translation.tr("Animation Preset")

                ConfigSelectionArray {
                    currentValue: Config.options.hyprland.animations.animation
                    
                    onSelected: newValue => {
                        Config.options.hyprland.animations.animation = newValue;

                        const presets = {
                            "fast":   presetFast,
                            "normal": presetNormal,
                            "niri":   presetNiri
                        };
                        
                        const content = presets[newValue] ?? "";

                        if (content !== "") {
                            saveAnimProc.command = [
                                "bash", 
                                "-c", 
                                "echo '" + content + "' > ~/.config/hypr/hyprland/shellOverrides/animations.conf"
                            ];
                            saveAnimProc.running = true;
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Elastic"),   icon: "move_selection_right", value: "fast" },
                        { displayName: Translation.tr("Normal"), icon: "animation", value: "normal" },
                        { displayName: Translation.tr("Niri Like"),   icon: "mobiledata_arrows", value: "niri" },
                    ]
                }
            }
            
            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 15
                text: Translation.tr("Animation presets require a source line in your hyprland.conf. Add the following line to enable presets:") + "\n\nsource = ~/.config/hypr/hyprland/shellOverrides/animations.conf"

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
                        Quickshell.clipboardText = "source = ~/.config/hypr/hyprland/shellOverrides/animations.conf"
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