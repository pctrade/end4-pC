import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

// Displays section: monitor canvas + one dropdown row per monitor.
// Shared by the default Hyprland settings page and the dashboard Displays card.
ContentSection {
    id: root
    icon: "monitor"
    shape: MaterialShape.Shape.ClamShell
    title: Translation.tr("Displays")
    visible: monitorConfig.monitors.length > 0

    // Dropdown menus tracked per monitor name, so several can be open at
    // once and a hotplug reorder doesn't shuffle them.
    property var openMonitors: ({})
    function toggleAdvanced(monName) {
        const next = Object.assign({}, root.openMonitors)
        next[monName] = !next[monName]
        root.openMonitors = next
    }

    MonitorConfigOption { id: monitorConfig }

        MonitorCanvas {
            id: monitorCanvas
            Layout.fillWidth: true
            monitorConfig: monitorConfig
        }

        // One dropdown row per connected monitor. The chevron selects that
        // monitor on the canvas and expands its options directly under the
        // row, so several menus can be open at the same time.
        Repeater {
            model: monitorConfig.monitors
            delegate: ColumnLayout {
                id: monCol
                required property int index
                Layout.fillWidth: true
                spacing: 0

                readonly property string monName: monitorConfig.monitors[index]?.name ?? ""
                readonly property bool open: root.openMonitors[monName] === true
                // The last display still showing the desktop can never be
                // switched off, so there is always something to look at.
                readonly property bool monOn: !(monitorConfig.monitors[index]?.disabled ?? false)
                readonly property bool canTurnOff: monitorConfig.monitors
                    .some((m, i) => i !== index && !(m.disabled ?? false))

                GroupedList {
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        // The label row opens this monitor's options; only
                        // the switch changes the monitor's state.
                        RippleButton {
                            id: monRow
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            implicitHeight: contentItem.implicitHeight + 8
                            font.pixelSize: Appearance.font.pixelSize.small
                            colBackgroundHover: "transparent"
                            onClicked: {
                                monitorCanvas.selectedIndex = index
                                root.toggleAdvanced(monCol.monName)
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                MaterialSymbol {
                                    text: "tv_off"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: monCol.monOn ? 1 : 0.4
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: (monitorConfig.monitors[index]?.name ?? "")
                                        + (monitorConfig.monitors[index]?.description ? " \u00b7 " + monitorConfig.monitors[index]?.description : "")
                                    font: monRow.font
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }
                        }
                        // The pin marks the one monitor every Mirror
                        // display copies. Only one can hold it.
                        RippleButton {
                            implicitWidth: 36; implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            onClicked: monitorConfig.pinSource(monCol.monName)
                            StyledToolTip { text: Translation.tr("set as main monitor") }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "keep"
                                iconSize: 20
                                // Filled when pinned, outline otherwise — same colour either way.
                                fill: monCol.monName === monitorConfig.mirrorSource ? 1 : 0
                                color: Appearance.colors.colPrimary
                            }
                        }
                        StyledSwitch {
                            checked: monCol.monOn
                            enabled: !monCol.monOn || monCol.canTurnOff
                            onClicked: {
                                if (!checked && !monCol.canTurnOff) return
                                if (checked === monCol.monOn) return
                                monitorConfig.updateMonitor(index, { disabled: !checked })
                                monitorConfig.applyAndSave(index)
                            }
                        }
                        RippleButton {
                            implicitWidth: 36; implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            onClicked: {
                                monitorCanvas.selectedIndex = index
                                root.toggleAdvanced(monCol.monName)
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: monCol.open ? "expand_less" : "expand_more"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                // Advanced options for this monitor, right under its row.
                // Scroll-down animation, no empty column when collapsed.
                GroupedList {
                    visible: monCol.open || implicitHeight > 0
                    Layout.topMargin: 1
                    Layout.bottomMargin: monCol.open ? 24 : 0
                    implicitHeight: monCol.open ? advancedCol.implicitHeight : 0
                    opacity: monCol.open ? 1 : 0
                    clip: false
                    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on Layout.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: advancedCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ConfigComboBox {
                            Layout.fillWidth: true
                            buttonIcon: "aspect_ratio"
                            text: Translation.tr("Resolution & Refresh Rate")
                            textRole: "display"
                            model: (monitorConfig.monitors[index]?.availableModes ?? [])
                                .map(mode => ({ display: mode, value: mode }))
                            currentValue: monitorConfig.monitors[index]?.currentMode ?? ""
                            onSelected: newValue => {
                                const mode = newValue
                                const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                                monitorConfig.updateMonitor(index, {
                                    currentMode: mode,
                                    width: parseInt(parts[1]),
                                    height: parseInt(parts[2]),
                                    refreshRate: parseFloat(parts[3])
                                })
                                monitorConfig.applyAndSave(index)
                            }
                        }

                        ConfigSelectionArray {
                            visible: monitorConfig.monitors.length > 1
                            text: Translation.tr("Display mode")
                            icon: "screenshot_monitor"
                            currentValue: (monitorConfig.monitors[index]?.mirror ?? "") !== "" ? "mirror" : "extended"
                            onSelected: newValue => {
                                monitorConfig.setMirroring(index, newValue === "mirror")
                                monitorConfig.applyAndSave(index)
                            }
                            options: [
                                { displayName: Translation.tr("Mirror"),   icon: "screenshot_monitor", value: "mirror" },
                                { displayName: Translation.tr("Extended"), icon: "desktop_windows",   value: "extended" },
                            ]
                        }

                        ConfigSelectionArray {
                            text: Translation.tr("Orientation")
                            icon: "mobile_rotate"
                            currentValue: monitorConfig.monitors[index]?.transform ?? 0
                            onSelected: newValue => {
                                monitorConfig.updateMonitor(index, { transform: newValue })
                                monitorConfig.applyAndSave(index)
                            }
                            options: [
                                { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                                { displayName: "90\u00b0",                    icon: "rotate_90_degrees_cw",  value: 1 },
                                { displayName: "180\u00b0",                   icon: "screen_rotation",       value: 2 },
                                { displayName: "270\u00b0",                   icon: "rotate_90_degrees_ccw", value: 3 },
                            ]
                        }

                        ConfigSpinBox {
                            icon: "zoom_in"
                            text: Translation.tr("Scale")
                            value: Math.round((monitorConfig.monitors[index]?.scale ?? 1.0) * 100)
                            from: 50; to: 300; stepSize: 25
                            onValueChanged: {
                                const newVal = value / 100.0
                                if (newVal === (monitorConfig.monitors[index]?.scale ?? 1.0)) return
                                monitorConfig.updateMonitor(index, { scale: newVal })
                                monitorConfig.applyAndSave(index)
                            }
                        }

                        ConfigSpinBox {
                            icon: "swap_horiz"
                            text: Translation.tr("Position X")
                            value: monitorConfig.monitors[index]?.x ?? 0
                            from: 0; to: 65535; stepSize: 1
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[index]?.x ?? 0)) return
                                monitorConfig.updateMonitor(index, { x: value })
                                monitorConfig.applyAndSave(index)
                            }
                        }

                        ConfigSpinBox {
                            icon: "swap_vert"
                            text: Translation.tr("Position Y")
                            value: monitorConfig.monitors[index]?.y ?? 0
                            from: 0; to: 65535; stepSize: 1
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[index]?.y ?? 0)) return
                                monitorConfig.updateMonitor(index, { y: value })
                                monitorConfig.applyAndSave(index)
                            }
                        }
                    }
                }
            }
        }

        // Staged edits only: sits right under the options, before the HDR
        // block, and vanishes once reverted or applied so the section
        // tightens again.
        RippleButton {
            visible: monitorConfig.dirty
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: monitorConfig.dirty ? 44 : 0
            buttonText: Translation.tr("Apply")
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            downAction: () => monitorConfig.applyAll()
            contentItem: StyledText {
                text: parent.buttonText
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnPrimary
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
