import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    forceWidth: true

    // ── Options ──────────────────────────────────────────────────────────────
    HyprlandConfigOption { id: rounding;         key: "decoration:rounding" }
    HyprlandConfigOption { id: blurEnabled;      key: "decoration:blur:enabled" }
    HyprlandConfigOption { id: blurSize;         key: "decoration:blur:size" }
    HyprlandConfigOption { id: blurPasses;       key: "decoration:blur:passes" }
    HyprlandConfigOption { id: shadowEnabled;    key: "decoration:shadow:enabled" }
    HyprlandConfigOption { id: shadowRange;      key: "decoration:shadow:range" }
    HyprlandConfigOption { id: borderSize;       key: "general:border_size" }
    HyprlandConfigOption { id: gapsIn;           key: "general:gaps_in" }
    HyprlandConfigOption { id: gapsOut;          key: "general:gaps_out" }
    HyprlandConfigOption { id: animEnabled;      key: "animations:enabled" }
    HyprlandConfigOption { id: activeBorder;     key: "general:col.active_border" }
    HyprlandConfigOption { id: inactiveBorder;   key: "general:col.inactive_border" }
    HyprlandConfigOption { id: activeOpacity;    key: "decoration:active_opacity" }
    HyprlandConfigOption { id: inactiveOpacity;  key: "decoration:inactive_opacity" }
    HyprlandConfigOption { id: layout;           key: "general:layout" }
    MonitorConfigOption  { id: monitorConfig }

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
            title: monitorConfig.monitors[monitorCanvas.selectedIndex]?.name
                + " · "
                + monitorConfig.monitors[monitorCanvas.selectedIndex]?.description ?? ""

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
                        { displayName: "90°",                   icon: "rotate_90_degrees_cw",  value: 1 },
                        { displayName: "180°",                  icon: "screen_rotation",       value: 2 },
                        { displayName: "270°",                  icon: "rotate_90_degrees_ccw", value: 3 },
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

    ContentSection {
        icon: "animation"
        shape: MaterialShape.Shape.Oval
        title: Translation.tr("Animations")

        ConfigSwitch {
            buttonIcon: "animation"
            text: Translation.tr("Enable Animations")
            checked: animEnabled.value ?? true
            onCheckedChanged: HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
        }
    }
}