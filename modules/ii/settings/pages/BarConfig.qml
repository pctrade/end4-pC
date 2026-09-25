import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Hyprland

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

    property var allWidgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button"),  icon: "left_panel_open" },
        { id: "workspaces",        name: Translation.tr("Workspaces"),           icon: "steppers" },
        { id: "weatherBar",        name: Translation.tr("Weather"),              icon: "flare" },
        { id: "media",             name: Translation.tr("Media"),                icon: "music_note" },
        { id: "resources",         name: Translation.tr("Resources"),            icon: "empty_dashboard" },
        { id: "systemIcons",       name: Translation.tr("System Icons"),         icon: "info" },
        { id: "networkSpeed",      name: Translation.tr("Network Speed"),        icon: "network_check" },
        { id: "clockWidget",       name: Translation.tr("Clock"),                icon: "schedule" },
        { id: "utilButtons",       name: Translation.tr("Util Buttons"),         icon: "toggle_on" },
        { id: "sysTray",           name: Translation.tr("Tray"),                 icon: "inbox" },
        { id: "batteryIndicator",  name: Translation.tr("Battery"),              icon: "battery_android_frame_full" },
        { id: "bluetooth",         name: Translation.tr("Bluetooth"),            icon: "bluetooth" },
        { id: "activeWindow",      name: Translation.tr("Active Window"),        icon: "subtitles" },
        { id: "powerButton",       name: Translation.tr("Power Button"),         icon: "power_settings_new" },
        { id: "updatesCount",      name: Translation.tr("Updates"),              icon: "deployed_code_update" },
        { id: "docktoPanel",       name: Translation.tr("Dock to Panel"),        icon: "apps" },
        { id: "visualizer",        name: Translation.tr("Visualizer"),           icon: "graphic_eq" },
        { id: "hyprlandXkbIndicator",   name: Translation.tr("Keyboard Layout"), icon: "keyboard" },
        { id: "divisor",            name: Translation.tr("Divider"),             icon: "horizontal_distribute" },
        { id: "launcherButton",     name: Translation.tr("Launcher Button"),     icon: "search" },
        { id: "dynamicIsland",     name: Translation.tr("Dynamic Island"),     icon: "nest_wifi_pro" },
    ]

    function availableFor(section) {
        let used = [
            ...Config.options.bar.layouts.leftLayout,
            ...Config.options.bar.layouts.middleLayout,
            ...Config.options.bar.layouts.rightLayout
        ]
        if (section === "middle" && Config.options.bar.layouts.middleLayout.length > 0) {
            return Config.options.bar.layouts.middleLayout.includes("dynamicIsland") ? [] : allWidgets.filter(w => {
                if (w.id === "dynamicIsland") return false
                if (w.id === "divisor" && Config.options.bar.borderless !== "transparent") return false
                const multipleAllowed = ["visualizer", "divisor"]
                return !used.includes(w.id) || multipleAllowed.includes(w.id)
            })
        }
        const multipleAllowed = ["visualizer", "divisor"]
        return allWidgets.filter(w => {
            if (w.id === "divisor" && Config.options.bar.borderless !== "transparent") return false
            if (w.id === "dynamicIsland" && (Config.options.bar.vertical || section !== "middle")) return false
            return !used.includes(w.id) || multipleAllowed.includes(w.id)
        })
    }

    function getWidgetName(id) {
        const w = allWidgets.find(w => w.id === id)
        return w ? w.name : id
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            visible: Hyprland.monitors.values.length > 1
            title: Translation.tr("Screens")
            ContentSubsection {
                title: Translation.tr("Show bar on")

                ColumnLayout {
                    id: monitorsCol
                    Layout.fillWidth: true
                    spacing: 2

                    Rectangle {
                        id: allRow
                        Layout.fillWidth: true
                        implicitHeight: allSwitchItem.implicitHeight + 16 + 8
                        color: Appearance.colors.colLayer1
                        topLeftRadius: Appearance.rounding.normal
                        topRightRadius: Appearance.rounding.normal
                        bottomLeftRadius: Appearance.rounding.unsharpenmore
                        bottomRightRadius: Appearance.rounding.unsharpenmore

                        ConfigSwitch {
                            id: allSwitchItem
                            anchors { fill: parent; margins: 8 }
                            buttonIcon: "tv_displays"
                            text: Translation.tr("All")
                            onCheckedChanged: {
                                if (checked) Config.options.bar.screenList = []
                            }

                            Binding {
                                target: allSwitchItem
                                property: "checked"
                                value: Config.options.bar.screenList.length === 0
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Repeater {
                        model: Hyprland.monitors
                        delegate: Rectangle {
                            id: monitorRow
                            required property var modelData
                            required property int index
                            readonly property bool isLast: index === Hyprland.monitors.values.length - 1

                            Layout.fillWidth: true
                            implicitHeight: switchItem.implicitHeight + 16 + 8
                            color: Appearance.colors.colLayer1
                            topLeftRadius:     Appearance.rounding.unsharpenmore
                            topRightRadius:    Appearance.rounding.unsharpenmore
                            bottomLeftRadius:  isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore
                            bottomRightRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore

                            ConfigSwitch {
                                id: switchItem
                                anchors { fill: parent; margins: 8 }
                                buttonIcon: "monitor"
                                text: monitorRow.modelData.name
                                onCheckedChanged: {
                                    const allNames = Hyprland.monitors.values.map(m => m.name)
                                    let list = Config.options.bar.screenList.length === 0 ? allNames.slice() : Config.options.bar.screenList.slice()
                                    if (checked) {
                                        if (!list.includes(monitorRow.modelData.name)) list.push(monitorRow.modelData.name)
                                    } else {
                                        list = list.filter(s => s !== monitorRow.modelData.name)
                                    }
                                    Config.options.bar.screenList = list.length === allNames.length ? [] : list
                                }

                                Binding {
                                    target: switchItem
                                    property: "checked"
                                    value: Config.options.bar.screenList.length === 0 || Config.options.bar.screenList.includes(monitorRow.modelData.name)
                                    restoreMode: Binding.RestoreBinding
                                }
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "splitscreen_add"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Bar layout")

            GroupedList {
                LayoutSection {
                    sectionTitle: Config.options.bar.vertical ? Translation.tr("Top") : Translation.tr("Left")
                    layout: Config.options.bar.layouts.leftLayout
                    availableWidgets: page.availableFor("left")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => Config.options.bar.layouts.leftLayout = list
                }

                LayoutSection {
                    sectionTitle: Translation.tr("Center")
                    layout: Config.options.bar.layouts.middleLayout
                    availableWidgets: page.availableFor("middle")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => Config.options.bar.layouts.middleLayout = list
                }

                LayoutSection {
                    sectionTitle: Config.options.bar.vertical ? Translation.tr("Bottom") : Translation.tr("Right")
                    layout: Config.options.bar.layouts.rightLayout
                    availableWidgets: page.availableFor("right")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => Config.options.bar.layouts.rightLayout = list
                }
            }
        }

        ContentSection {
            icon: "pivot_table_chart"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Positioning & Styles")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Bar position")
                    icon: "swap_vert"
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        { displayName: Translation.tr("Top"),    icon: "arrow_upward",   value: 0 },
                        { displayName: Translation.tr("Left"),   icon: "arrow_back",     value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"),  icon: "arrow_forward",  value: 3 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Bar style")
                    icon: "style"
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => { Config.options.bar.cornerStyle = newValue; }
                    options: [
                        { displayName: Translation.tr("Hug"),     icon: "line_curve", value: 0 },
                        { displayName: Translation.tr("Float"),   icon: "view_day",   value: 1 },
                        { displayName: Translation.tr("Islands"), icon: "crop_3_2",   value: 2 },
                        { displayName: Translation.tr("M3"), icon: "interests",   value: 3 },
                        { displayName: Translation.tr("Panel"), icon: "toolbar",   value: 4 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Group style")
                    icon: "tab_group"
                    currentValue: Config.options.bar.borderless
                    onSelected: newValue => { Config.options.bar.borderless = newValue; }
                    options: [
                        { displayName: Translation.tr(""),          icon: "block",          value: "transparent" },
                        { displayName: Translation.tr("Pills"),     icon: "pill",           value: "pills" },
                        { displayName: Translation.tr("Separated"), icon: "view_column_2",  value: "separated" },
                        { displayName: Translation.tr("Segmented"), icon: "tablet",           value: "segmented" },
                    ]
                }
                ColorSelectionArray {
                    icon: "brush"
                    text: Translation.tr("Group Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"]
                    currentValue: Config.options.bar.groupColor
                    onSelected: newValue => {
                        Config.options.bar.groupColor = newValue
                    }
                }
                ConfigRow{
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "variable_insert"
                        text: Translation.tr("Show Background")
                        enabled: Config.options.bar.cornerStyle === 0 || Config.options.bar.cornerStyle === 1
                        checked: Config.options.bar.showBackground
                        onCheckedChanged: { Config.options.bar.showBackground = checked; }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Autohide")
                        icon: "preview_off"
                        currentValue: Config.options.bar.autoHide.enable
                        onSelected: newValue => { Config.options.bar.autoHide.enable = newValue; }
                        options: [
                            { displayName: Translation.tr("No"),  icon: "close", value: false },
                            { displayName: Translation.tr("Yes"), icon: "check", value: true }
                        ]
                    }
                }
                ConfigSwitch {
                    buttonIcon: "expand"
                    enabled: Config.options.bar.showFrame
                    text: Translation.tr("Overlap windows when center-only")
                    checked: Config.options.bar.centerOnlyReserveFrame
                    onCheckedChanged: { Config.options.bar.centerOnlyReserveFrame = checked; }
                }
                ConfigRow {
                    ConfigSwitch {
                        buttonIcon: "panorama_wide_angle"
                        text: Translation.tr("Show Frame")
                        checked: Config.options.bar.showFrame

                        property bool switchReady: false
                        Component.onCompleted: Qt.callLater(() => switchReady = true)

                        onCheckedChanged: {
                            if (switchReady && checked) {
                                GlobalStates.refreshBar();
                            }
                            Config.options.bar.showFrame = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "colors"
                        enabled: Config.options.bar.showFrame
                        text: Translation.tr("Follow Frame Color")
                        checked: Config.options.bar.followFrameColor
                        onCheckedChanged: { Config.options.bar.followFrameColor = checked; }
                    }
                }
                ConfigSpinBox {
                    icon: "eraser_size_1"
                    text: Translation.tr("Frame thickness")
                    value: Config.options.bar.frameThickness
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.options.bar.frameThickness = value;
                    }
                }
                ColorSelectionArray {
                    icon: "imagesearch_roller"
                    text: Translation.tr("Frame Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"] // sorry only solid colors transparency looks bad
                    currentValue: Config.options.bar.frameColor
                    onSelected: newValue => {
                        Config.options.bar.frameColor = newValue
                    }
                }
            }
        }

        ContentSection {
            icon: "nest_wifi_pro"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Dynamic Island")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Left widget")
                    icon: "right_panel_open"
                    currentValue: Config.options.bar.dynamicIsland.leftWidget
                    onSelected: newValue => { Config.options.bar.dynamicIsland.leftWidget = newValue; }
                    options: [
                        { displayName: Translation.tr(""),    icon: "block",        value: "none" },
                        { displayName: Translation.tr("Clock"),   icon: "schedule",     value: "clockWidget" },
                        { displayName: Translation.tr("Weather"), icon: "partly_cloudy_day", value: "weatherBar" },
                        { displayName: Translation.tr("Updates"), icon: "update",       value: "updatesCount" }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Right widget")
                    icon: "left_panel_open"
                    currentValue: Config.options.bar.dynamicIsland.rightWidget
                    onSelected: newValue => { Config.options.bar.dynamicIsland.rightWidget = newValue; }
                    options: [
                        { displayName: Translation.tr(""),         icon: "block",        value: "none" },
                        { displayName: Translation.tr("System icons"), icon: "settings",     value: "systemIcons" },
                        { displayName: Translation.tr("Tray"),  icon: "apps",         value: "sysTray" },
                        { displayName: Translation.tr("Util buttons"), icon: "widgets",   value: "utilButtons" }
                    ]
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("How it behaves")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "open_in_full"
                        text: Translation.tr("Expand on hover")
                        checked: Config.options.bar.dynamicIsland.expandOnHover
                        onCheckedChanged: { Config.options.bar.dynamicIsland.expandOnHover = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "notifications_active"
                        text: Translation.tr("Expand automatically for important events")
                        checked: Config.options.bar.dynamicIsland.autoExpand
                        onCheckedChanged: { Config.options.bar.dynamicIsland.autoExpand = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "bubble_chart"
                        text: Translation.tr("Split into bubbles when several things are active")
                        checked: Config.options.bar.dynamicIsland.splitMode
                        onCheckedChanged: { Config.options.bar.dynamicIsland.splitMode = checked; }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Anchor")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "schedule"
                        text: Translation.tr("Keep the time (or what is more urgent) pinned to the island")
                        checked: Config.options.bar.dynamicIsland.anchor
                        onCheckedChanged: { Config.options.bar.dynamicIsland.anchor = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "nest_clock_farsight_analog"
                        text: Translation.tr("Always show the time (urgent things become its icon)")
                        checked: Config.options.bar.dynamicIsland.anchorAlwaysTime
                        onCheckedChanged: { Config.options.bar.dynamicIsland.anchorAlwaysTime = checked; }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Anchor typeface")
                        icon: "text_fields"
                        currentValue: Config.options.bar.dynamicIsland.anchorFont
                        onSelected: newValue => { Config.options.bar.dynamicIsland.anchorFont = newValue; }
                        options: [
                            { displayName: Translation.tr("Display"),   icon: "brand_family", value: "expressive" },
                            { displayName: Translation.tr("Interface"), icon: "match_case",   value: "main" },
                            { displayName: Translation.tr("Numbers"),   icon: "123",          value: "numbers" },
                            { displayName: Translation.tr("Mono"),      icon: "code",         value: "monospace" }
                        ]
                    }
                }
            }

            // What each feature costs while it's on, heaviest first — so it's clear which ones are worth turning
            // off. Every switch here stops the work itself (process, timer, network), not just the drawing.
            ContentSubsection {
                title: Translation.tr("Background work · heaviest first")
                GroupedList {
                    IslandCostSwitch {
                        buttonIcon: "graphic_eq"
                        title: Translation.tr("Music visualizer")
                        detail: Translation.tr("A cava process analysing the sound, all the time the music plays")
                        cost: "heavy"
                        checked: Config.options.bar.dynamicIsland.visualizerStyle !== "none"
                        onCheckedChanged: {
                            if (checked === (Config.options.bar.dynamicIsland.visualizerStyle !== "none")) return
                            Config.options.bar.dynamicIsland.visualizerStyle = checked ? "dots" : "none"
                        }
                    }
                    IslandCostSwitch {
                        buttonIcon: "sports_motorsports"
                        title: Translation.tr("Formula 1 live timing")
                        detail: Translation.tr("A live-timing script during sessions only; otherwise one timer until the next one")
                        cost: "heavy"
                        checked: Config.options.bar.dynamicIsland.f1.enable
                        onCheckedChanged: { Config.options.bar.dynamicIsland.f1.enable = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "wifi"
                        title: Translation.tr("Network and downloads")
                        detail: Translation.tr("Reads the traffic every 5 s (every second during a download); finds who is downloading only then")
                        cost: "medium"
                        checked: Config.options.bar.dynamicIsland.network
                        onCheckedChanged: { Config.options.bar.dynamicIsland.network = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "lyrics"
                        title: Translation.tr("Synced lyrics")
                        detail: Translation.tr("Fetches the lyrics of each song and follows them while it plays")
                        cost: "medium"
                        checked: Config.options.bar.dynamicIsland.lyrics
                        onCheckedChanged: { Config.options.bar.dynamicIsland.lyrics = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "system_update_alt"
                        title: Translation.tr("Check for updates")
                        detail: Translation.tr("checkupdates every %1 min (network + pacman); also feeds the bar's counter").arg(Config.options.updates.checkInterval)
                        cost: "medium"
                        checked: Config.options.updates.enableCheck
                        onCheckedChanged: { Config.options.updates.enableCheck = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "memory"
                        title: Translation.tr("CPU, memory and GPU pressure")
                        detail: Translation.tr("Reuses the bar's samples; lists processes only while an alert or panel is open")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.systemLoad
                        onCheckedChanged: { Config.options.bar.dynamicIsland.systemLoad = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "cable"
                        title: Translation.tr("Hardware (monitors, drives, dock, heat, disk)")
                        detail: Translation.tr("Listens to udev and UPower events; nothing runs between them")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.hardware
                        onCheckedChanged: { Config.options.bar.dynamicIsland.hardware = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "palette"
                        title: Translation.tr("Album colors")
                        detail: Translation.tr("Reads each cover's colors once, when the song changes")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.albumColors
                        onCheckedChanged: { Config.options.bar.dynamicIsland.albumColors = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "smart_toy"
                        title: Translation.tr("AI agents (Claude, Codex, Gemini)")
                        detail: Translation.tr("Only the agents' own hooks; nothing is polled")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.claudeCode
                        onCheckedChanged: { Config.options.bar.dynamicIsland.claudeCode = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "movie"
                        title: Translation.tr("IMDb episode ratings")
                        detail: Translation.tr("One lookup per show, when an episode starts in the browser")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.watchRatings
                        onCheckedChanged: { Config.options.bar.dynamicIsland.watchRatings = checked; }
                    }
                    IslandCostSwitch {
                        buttonIcon: "call"
                        title: Translation.tr("Call controls")
                        detail: Translation.tr("Uses the microphone links PipeWire already reports; no extra work")
                        cost: "light"
                        checked: Config.options.bar.dynamicIsland.callActivity
                        onCheckedChanged: { Config.options.bar.dynamicIsland.callActivity = checked; }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Pinned islands")
                // Declared one by one on purpose: GroupedList counts each declared child as a row, and a
                // Repeater would arrive as a single zero-height entry whose rows then overlap the next section.
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "partly_cloudy_day"
                        text: Translation.tr("Weather")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("weather")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("weather")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "weather"]
                                : pinned.filter(p => p !== "weather")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "inventory_2"
                        text: Translation.tr("Drawer")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("shelf")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("shelf")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "shelf"]
                                : pinned.filter(p => p !== "shelf")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "content_paste"
                        text: Translation.tr("Clipboard")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("clipboard")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("clipboard")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "clipboard"]
                                : pinned.filter(p => p !== "clipboard")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "monitoring"
                        text: Translation.tr("System")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("system")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("system")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "system"]
                                : pinned.filter(p => p !== "system")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "music_note"
                        text: Translation.tr("Media")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("media")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("media")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "media"]
                                : pinned.filter(p => p !== "media")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "sports_motorsports"
                        text: "F1"
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("f1")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("f1")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "f1"]
                                : pinned.filter(p => p !== "f1")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "smart_toy"
                        text: Translation.tr("AI agents")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("agents")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("agents")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "agents"]
                                : pinned.filter(p => p !== "agents")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "download"
                        text: Translation.tr("Download")
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("download")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("download")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "download"]
                                : pinned.filter(p => p !== "download")
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "vpn_lock"
                        text: "ZeroTier"
                        checked: (Config.options.bar.dynamicIsland.pinned ?? []).includes("zerotier")
                        onCheckedChanged: {
                            const pinned = Array.from(Config.options.bar.dynamicIsland.pinned ?? [])
                            if (checked === pinned.includes("zerotier")) return
                            Config.options.bar.dynamicIsland.pinned = checked
                                ? [...pinned, "zerotier"]
                                : pinned.filter(p => p !== "zerotier")
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("What shows up")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "privacy_tip"
                        text: Translation.tr("Privacy indicators")
                        checked: Config.options.bar.dynamicIsland.privacyIndicators
                        onCheckedChanged: { Config.options.bar.dynamicIsland.privacyIndicators = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "content_paste"
                        text: Translation.tr("Clipboard")
                        checked: Config.options.bar.dynamicIsland.clipboard
                        onCheckedChanged: { Config.options.bar.dynamicIsland.clipboard = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "screenshot_monitor"
                        text: Translation.tr("Screenshots")
                        checked: Config.options.bar.dynamicIsland.screenshots
                        onCheckedChanged: { Config.options.bar.dynamicIsland.screenshots = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "bluetooth"
                        text: Translation.tr("Bluetooth devices")
                        checked: Config.options.bar.dynamicIsland.bluetooth
                        onCheckedChanged: { Config.options.bar.dynamicIsland.bluetooth = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "speaker"
                        text: Translation.tr("Audio output")
                        checked: Config.options.bar.dynamicIsland.audioOutput
                        onCheckedChanged: { Config.options.bar.dynamicIsland.audioOutput = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "rainy"
                        text: Translation.tr("Weather changes")
                        checked: Config.options.bar.dynamicIsland.weatherAlerts
                        onCheckedChanged: { Config.options.bar.dynamicIsland.weatherAlerts = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "system_update_alt"
                        text: Translation.tr("Updates indicator")
                        checked: Config.options.bar.dynamicIsland.updatesIndicator
                        onCheckedChanged: { Config.options.bar.dynamicIsland.updatesIndicator = checked; }
                    }
                    ConfigSwitch {
                        buttonIcon: "bolt"
                        text: Translation.tr("Live activities")
                        checked: Config.options.bar.dynamicIsland.liveActivities
                        onCheckedChanged: { Config.options.bar.dynamicIsland.liveActivities = checked; }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Integrations")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("What counts as a download")
                        icon: "download"
                        currentValue: Config.options.bar.dynamicIsland.downloadDetection
                        onSelected: newValue => { Config.options.bar.dynamicIsland.downloadDetection = newValue; }
                        options: [
                            { displayName: Translation.tr("A file arriving"), icon: "draft", value: "files" },
                            { displayName: Translation.tr("Any heavy traffic"), icon: "network_check", value: "traffic" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "fullscreen"
                        text: Translation.tr("Hairline with events while fullscreen")
                        checked: Config.options.bar.dynamicIsland.fullscreenPeek
                        onCheckedChanged: { Config.options.bar.dynamicIsland.fullscreenPeek = checked; }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Media")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Visualizer style")
                        icon: "graphic_eq"
                        currentValue: Config.options.bar.dynamicIsland.visualizerStyle
                        onSelected: newValue => { Config.options.bar.dynamicIsland.visualizerStyle = newValue; }
                        options: [
                            { displayName: Translation.tr(""),      icon: "block",       value: "none" },
                            { displayName: Translation.tr("Dots"),  icon: "steppers",     value: "dots" },
                            { displayName: Translation.tr("Wave"),  icon: "ssid_chart",   value: "wave" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "play_circle"
                        text: Translation.tr("Show media controls")
                        checked: Config.options.bar.dynamicIsland.showMediaControls
                        onCheckedChanged: { Config.options.bar.dynamicIsland.showMediaControls = checked; }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("When to warn")
                GroupedList {
                    ConfigSpinBox {
                        icon: "electric_bolt"
                        text: Translation.tr("Warn about a slow charger below (W)")
                        value: Config.options.bar.dynamicIsland.slowChargerWatts
                        from: 5
                        to: 100
                        stepSize: 5
                        onValueChanged: { Config.options.bar.dynamicIsland.slowChargerWatts = value; }
                    }
                    ConfigSpinBox {
                        icon: "device_thermostat"
                        text: Translation.tr("Warn about heat above (°C)")
                        value: Config.options.bar.dynamicIsland.hotTemperature
                        from: 60
                        to: 105
                        stepSize: 1
                        onValueChanged: { Config.options.bar.dynamicIsland.hotTemperature = value; }
                    }
                    ConfigSpinBox {
                        icon: "timer"
                        text: Translation.tr("Only announce an agent turn longer than (s)")
                        value: Config.options.bar.dynamicIsland.claudeDoneMinSeconds
                        from: 0
                        to: 300
                        stepSize: 5
                        onValueChanged: { Config.options.bar.dynamicIsland.claudeDoneMinSeconds = value; }
                    }
                    ConfigSpinBox {
                        icon: "auto_delete"
                        text: Translation.tr("Drawer keeps files for (days)")
                        value: Config.options.bar.dynamicIsland.shelfExpireDays
                        from: 0
                        to: 90
                        stepSize: 1
                        onValueChanged: { Config.options.bar.dynamicIsland.shelfExpireDays = value; }
                    }
                }
            }

            ContentSubsection {
                title: "Formula 1"
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "flag"
                        text: Translation.tr("Expand on flags and Safety Car")
                        checked: Config.options.bar.dynamicIsland.f1.autoExpandFlags
                        onCheckedChanged: { Config.options.bar.dynamicIsland.f1.autoExpandFlags = checked; }
                    }
                }
            }
        }

        ContentSection {
            icon: "notifications"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Notifications")
            
            GroupedList {
                ConfigComboBox { // too much items for configselectionarray - I know it's not the best place to put this but I can change it later
                    text: Translation.tr("Popup position")
                    buttonIcon: "my_location" 
                    currentValue: Config.options.notifications.position
                    fieldWidth: 50
                    onSelected: newValue => {
                        Config.options.notifications.position = newValue;
                    }
                    model: [
                        {
                            displayName: Translation.tr("Top left"),
                            value: "top_left"
                        },
                        {
                            displayName: Translation.tr("Top center"),
                            value: "top_center"
                        },
                        {
                            displayName: Translation.tr("Top right"),
                            value: "top_right"
                        },
                        {
                            displayName: Translation.tr("Bottom left"),
                            value: "bottom_left"
                        },
                        {
                            displayName: Translation.tr("Bottom center"),
                            value: "bottom_center"
                        },
                        {
                            displayName: Translation.tr("Bottom right"),
                            value: "bottom_right"
                        }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "counter_2"
                    text: Translation.tr("Unread indicator: show count")
                    checked: Config.options.bar.indicators.notifications.showUnreadCount
                    onCheckedChanged: { Config.options.bar.indicators.notifications.showUnreadCount = checked; }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Timeout duration (if not defined by notification) (ms)")
                    value: Config.options.notifications.timeout
                    from: 1000
                    to: 60000
                    stepSize: 1000
                    onValueChanged: {
                        Config.options.notifications.timeout = value;
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Square
            icon: "inbox_customize"
            title: Translation.tr("Tray")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Make icons pinned by default")
                    checked: Config.options.tray.invertPinnedItems
                    onCheckedChanged: { Config.options.tray.invertPinnedItems = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "colors"; text: Translation.tr("Tint icons")
                    checked: Config.options.tray.monochromeIcons
                    onCheckedChanged: { Config.options.tray.monochromeIcons = checked; }
                }
            }
        }

        ContentSection {
            icon: "vertical_align_center"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Divider")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: Config.options.bar.divider.style
                    onSelected: newValue => { Config.options.bar.divider.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Line"),  icon: "more_vert",       value: "rect" },
                        { displayName: Translation.tr("Dot"),   icon: "fiber_manual_record", value: "dot" },
                        { displayName: Translation.tr("Space"), icon: "space_bar",       value: "space" }
                    ]
                }
                ConfigSpinBox {
                    icon: "width"
                    enabled: Config.options.bar.divider.style === "space"
                    text: Translation.tr("Space width (px)")
                    value: Config.options.bar.divider.spacing
                    from: 4
                    to: 400
                    stepSize: 2
                    onValueChanged: {
                        Config.options.bar.divider.spacing = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "buttons_alt"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Utility buttons")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screenshot_region"
                        text: Translation.tr("Screen snip")
                        checked: Config.options.bar.utilButtons.showScreenSnip
                        onCheckedChanged: { Config.options.bar.utilButtons.showScreenSnip = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "colorize"
                        text: Translation.tr("Color picker")
                        checked: Config.options.bar.utilButtons.showColorPicker
                        onCheckedChanged: { Config.options.bar.utilButtons.showColorPicker = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard toggle")
                        checked: Config.options.bar.utilButtons.showKeyboardToggle
                        onCheckedChanged: { Config.options.bar.utilButtons.showKeyboardToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "mic"
                        text: Translation.tr("Mic toggle")
                        checked: Config.options.bar.utilButtons.showMicToggle
                        onCheckedChanged: { Config.options.bar.utilButtons.showMicToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "dark_mode"
                        text: Translation.tr("Dark/Light toggle")
                        checked: Config.options.bar.utilButtons.showDarkModeToggle
                        onCheckedChanged: { Config.options.bar.utilButtons.showDarkModeToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "speed"
                        text: Translation.tr("Performance Profile")
                        checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                        onCheckedChanged: { Config.options.bar.utilButtons.showPerformanceProfileToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screen_record"
                        text: Translation.tr("Record Screen")
                        checked: Config.options.bar.utilButtons.showScreenRecord
                        onCheckedChanged: { Config.options.bar.utilButtons.showScreenRecord = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "imagesmode"
                        text: Translation.tr("Wallpapers Toggle")
                        checked: Config.options.bar.utilButtons.showWallpaperToggle
                        onCheckedChanged: { Config.options.bar.utilButtons.showWallpaperToggle = checked }
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Cookie12Sided
            icon: "steppers"; title: Translation.tr("Workspaces")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "counter_1"; text: Translation.tr("Always show numbers")
                    checked: Config.options.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: { Config.options.bar.workspaces.alwaysShowNumbers = checked; }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Numbers style")
                    icon: "looks_3"
                    currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap)
                    onSelected: newValue => {
                        Config.options.bar.workspaces.numberMap = JSON.parse(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                        { displayName: Translation.tr("Han chars"), icon: "glyphs",          value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                        { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "award_star"; text: Translation.tr("Show app icons")
                    checked: Config.options.bar.workspaces.showAppIcons
                    onCheckedChanged: { Config.options.bar.workspaces.showAppIcons = checked; }
                }
                ConfigSpinBox {
                    icon: "view_column"; text: Translation.tr("Workspaces shown")
                    value: Config.options.bar.workspaces.shown
                    from: 1; to: 30
                    onValueChanged: { Config.options.bar.workspaces.shown = value; }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Indicator style")
                    icon: "page_control"
                    currentValue: Config.options.bar.workspaces.indicatorStyle ?? "icon"
                    onSelected: newValue => {
                        Config.options.bar.workspaces.indicatorStyle = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Dots"),  icon: "radio_button_checked",   value: "dot" },
                        { displayName: Translation.tr("Icons"), icon: "interests",              value: "icon" },
                    ]
                }
            }
        }

        ContentSection {
            icon: "empty_dashboard"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Resources")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "planner_review"
                        text: Translation.tr("CPU")
                        checked: Config.options.bar.resources.alwaysShowCpu
                        onCheckedChanged: { Config.options.bar.resources.alwaysShowCpu = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "thermostat"
                        text: Translation.tr("CPU Temperature")
                        checked: Config.options.bar.resources.alwaysShowCpuTemp
                        onCheckedChanged: { Config.options.bar.resources.alwaysShowCpuTemp = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "memory"
                        text: Translation.tr("RAM")
                        checked: Config.options.bar.resources.alwaysShowRam
                        onCheckedChanged: { Config.options.bar.resources.alwaysShowRam = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "storage"
                        text: Translation.tr("Disk")
                        checked: Config.options.bar.resources.alwaysShowDisk
                        onCheckedChanged: { Config.options.bar.resources.alwaysShowDisk = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "swap_horiz"
                        text: Translation.tr("Swap")
                        checked: Config.options.bar.resources.alwaysShowSwap
                        onCheckedChanged: { Config.options.bar.resources.alwaysShowSwap = checked }
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: Config.options.bar.resources.style
                    onSelected: newValue => { Config.options.bar.resources.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Filled"),    icon: "incomplete_circle",  value: "filled" },
                        { displayName: Translation.tr("Outline"),   icon: "circles",            value: "outline" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "decimal_increase"; text: Translation.tr("Show Percentage")
                    checked: Config.options.bar.resources.showValue
                    onCheckedChanged: { Config.options.bar.resources.showValue = checked; }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (ms)")
                    value: Config.options.resources.updateInterval
                    from: 100
                    to: 10000
                    stepSize: 100
                    onValueChanged: {
                        Config.options.resources.updateInterval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "music_note"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Media")

            GroupedList {
                ConfigTextArea {
                    id: preferredPlayerField
                    Layout.fillWidth: true
                    buttonIcon: "play_circle"
                    text: Translation.tr("Preferred Player")
                    placeholderText: Translation.tr("e.g. spotify, firefox")
                    value: Config.options.bar.media.preferredPlayer
                    onValueChanged: {
                        mediaDebounceTimer.restart();
                    }

                    Timer {
                        id: mediaDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.bar.media.preferredPlayer = preferredPlayerField.value;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Pin media controls")
                    checked: Config.options.bar.media.alwaysVisible
                    onCheckedChanged: { Config.options.bar.media.alwaysVisible = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "titlecase"; text: Translation.tr("Show only title")
                    checked: Config.options.bar.media.onlyTitle
                    onCheckedChanged: { Config.options.bar.media.onlyTitle = checked; }
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Max media width")
                    value: Config.options.bar.media.maxWidth
                    from: 100
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        Config.options.bar.media.maxWidth = value;
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Puffy
            icon: "tooltip"; title: Translation.tr("Tooltips")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "visibility"; text: Translation.tr("Enable")
                    checked: Config.options.bar.tooltips.enable
                    onCheckedChanged: { Config.options.bar.tooltips.enable = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "ads_click"; text: Translation.tr("Click to show")
                    checked: Config.options.bar.tooltips.clickToShow
                    onCheckedChanged: { Config.options.bar.tooltips.clickToShow = checked; }
                    enabled: Config.options.bar.tooltips.enable
                }
            }
        }
    }
}
