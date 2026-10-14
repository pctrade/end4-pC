import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Hyprland

ContentPage {
    id: page
    readonly property string selectedBarScreen: GlobalStates.dashboardBarScreen
    property var barConfig: selectedBarScreen === ""
        ? Config.options.bar
        : Config.cloneValue(Config.barForScreen(selectedBarScreen))
    readonly property bool defaultWorkspacesDesign: (page.barConfig.workspaces.style ?? "default") === "default"
    forceWidth: true

    // Legacy settings controls assign directly into their configuration object.
    // Flush a selected monitor's editable snapshot back through Config so the
    // JsonAdapter is notified and every bar on that monitor refreshes.
    Timer {
        interval: 80
        repeat: true
        running: page.selectedBarScreen !== ""
        onTriggered: {
            const edited = Config.cloneValue(page.barConfig);
            const current = Config.cloneValue(Config.barForScreen(page.selectedBarScreen));
            if (JSON.stringify(edited) !== JSON.stringify(current))
                Config.replaceBarSettingsForScreen(page.selectedBarScreen, edited);
        }
    }

    readonly property color leftIconColor: {
        const name = Config.options.custom.iconColor || "onLayer0"
        return Appearance.colors[`col${name.charAt(0).toUpperCase()}${name.slice(1)}`] ?? Appearance.colors.colOnLayer0
    }

    property var allWidgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button"),  icon: "left_panel_open" },
        { id: "workspaces",        name: Translation.tr("Workspaces"),           icon: "steppers" },
        { id: "weatherBar",        name: Translation.tr("Weather"),              icon: "flare" },
        { id: "liveWallpaper",     name: Translation.tr("Live wallpaper"),        icon: "play_pause" },
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
        { id: "aiUsage",           name: Translation.tr("AI Usage"),           icon: "neurology" },
        { id: "avatar",            name: Translation.tr("Avatar"),             icon: "account_circle" },
    ]

    function availableFor(section) {
        let used = [
            ...page.barConfig.layouts.leftLayout,
            ...page.barConfig.layouts.middleLayout,
            ...page.barConfig.layouts.rightLayout
        ]
        if (section === "middle" && page.barConfig.layouts.middleLayout.length > 0) {
            return page.barConfig.layouts.middleLayout.includes("dynamicIsland") ? [] : allWidgets.filter(w => {
                if (w.id === "dynamicIsland") return false
                if (w.id === "divisor" && page.barConfig.borderless !== "transparent") return false
                const multipleAllowed = ["visualizer", "divisor"]
                return !used.includes(w.id) || multipleAllowed.includes(w.id)
            })
        }
        const multipleAllowed = ["visualizer", "divisor"]
        return allWidgets.filter(w => {
            if (w.id === "divisor" && page.barConfig.borderless !== "transparent") return false
            if (w.id === "dynamicIsland" && (page.barConfig.vertical || section !== "middle")) return false
            return !used.includes(w.id) || multipleAllowed.includes(w.id)
        })
    }

    readonly property var usedWidgets: {
        const layouts = page.barConfig.layouts
        const used = [...layouts.leftLayout, ...layouts.middleLayout, ...layouts.rightLayout]
        if (used.includes("dynamicIsland")) {
            used.push(page.barConfig.dynamicIsland.leftWidget, page.barConfig.dynamicIsland.rightWidget)
        }
        return used
    }

    function isUsed(id) {
        return page.usedWidgets.includes(id)
    }

    readonly property var widgetSections: ({
        dynamicIsland: Translation.tr("Dynamic Island"),
        sysTray: Translation.tr("Tray"),
        leftSidebarButton: Translation.tr("Left sidebar button"),
        divisor: Translation.tr("Divider"),
        utilButtons: Translation.tr("Utility buttons"),
        workspaces: Translation.tr("Workspaces"),
        resources: Translation.tr("Resources"),
        media: Translation.tr("Media")
    })

    function openWidgetSettings(id) {
        const title = page.widgetSections[id]
        if (title) page.goTo(title, title)
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
                title: Translation.tr("Edit bar settings for")

                ConfigSelectionArray {
                    text: Translation.tr("Settings target")
                    icon: "tv_displays"
                    currentValue: page.selectedBarScreen
                    onSelected: newValue => { GlobalStates.dashboardBarScreen = newValue; }
                    options: [{ displayName: Translation.tr("All displays"), icon: "select_all", value: "" }]
                        .concat(Hyprland.monitors.values.map(monitor => ({
                            displayName: monitor.name,
                            icon: "monitor",
                            value: monitor.name
                        })))
                }

                ConfigSelectionArray {
                    visible: page.selectedBarScreen !== ""
                    text: Translation.tr("Monitor settings")
                    icon: "tune"
                    currentValue: Config.hasBarOverride(page.selectedBarScreen)
                    onSelected: custom => {
                        if (custom) Config.createBarOverride(page.selectedBarScreen);
                        else Config.resetBarForScreen(page.selectedBarScreen);
                    }
                    options: [
                        { displayName: Translation.tr("Use defaults"), icon: "restart_alt", value: false },
                        { displayName: Translation.tr("Custom"), icon: "tune", value: true }
                    ]
                }

                ConfigSelectionArray {
                    visible: page.selectedBarScreen !== "" && Config.hasBarOverride(page.selectedBarScreen)
                    text: Translation.tr("Show bar")
                    icon: "visibility"
                    currentValue: page.barConfig.enabled !== false
                    onSelected: enabled => Config.setBarEnabledForScreen(page.selectedBarScreen, enabled)
                    options: [
                        { displayName: Translation.tr("Hidden"), icon: "visibility_off", value: false },
                        { displayName: Translation.tr("Shown"), icon: "visibility", value: true }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Allow bars on")

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
            hint: Translation.tr("Right-click a widget to open its settings (not every widget has settings here)")
            hintIcon: "info"

            GroupedList {
                LayoutSection {
                    sectionTitle: page.barConfig.vertical ? Translation.tr("Top") : Translation.tr("Left")
                    layout: page.barConfig.layouts.leftLayout
                    availableWidgets: page.availableFor("left")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.barConfig.layouts.leftLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
                }

                LayoutSection {
                    sectionTitle: Translation.tr("Center")
                    layout: page.barConfig.layouts.middleLayout
                    availableWidgets: page.availableFor("middle")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.barConfig.layouts.middleLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
                }

                LayoutSection {
                    sectionTitle: page.barConfig.vertical ? Translation.tr("Bottom") : Translation.tr("Right")
                    layout: page.barConfig.layouts.rightLayout
                    availableWidgets: page.availableFor("right")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.barConfig.layouts.rightLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
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
                    currentValue: (page.barConfig.bottom ? 1 : 0) | (page.barConfig.vertical ? 2 : 0)
                    onSelected: newValue => {
                        page.barConfig.bottom = (newValue & 1) !== 0;
                        page.barConfig.vertical = (newValue & 2) !== 0;
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
                    textOnlyWhenActive: true
                    currentValue: page.barConfig.cornerStyle
                    onSelected: newValue => { page.barConfig.cornerStyle = newValue; }
                    options: [
                        { displayName: Translation.tr("Hug"),     icon: "line_curve", value: 0 },
                        { displayName: Translation.tr("Split Hug"), icon: "splitscreen", value: 6 },
                        { displayName: Translation.tr("Float"),   icon: "view_day",   value: 1 },
                        { displayName: Translation.tr("Islands"), icon: "crop_3_2",   value: 2 },
                        { displayName: Translation.tr("M3"), icon: "interests",   value: 3 },
                        { displayName: Translation.tr("M3 Hug"), icon: "category", value: 4 },
                        { displayName: Translation.tr("Panel"), icon: "toolbar",   value: 5 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Group style")
                    icon: "tab_group"
                    currentValue: page.barConfig.borderless
                    onSelected: newValue => { page.barConfig.borderless = newValue; }
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
                    currentValue: page.barConfig.groupColor
                    onSelected: newValue => {
                        page.barConfig.groupColor = newValue
                    }
                }
                ConfigRow{
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "variable_insert"
                        text: Translation.tr("Show Background")
                        enabled: page.barConfig.cornerStyle === 0 || page.barConfig.cornerStyle === 1
                        checked: page.barConfig.showBackground
                        onCheckedChanged: { page.barConfig.showBackground = checked; }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Autohide")
                        icon: "preview_off"
                        currentValue: page.barConfig.autoHide.enable
                        onSelected: newValue => { page.barConfig.autoHide.enable = newValue; }
                        options: [
                            { displayName: Translation.tr("No"),  icon: "close", value: false },
                            { displayName: Translation.tr("Yes"), icon: "check", value: true }
                        ]
                    }
                }
                ConfigSwitch {
                    buttonIcon: "expand"
                    enabled: page.barConfig.showFrame
                    text: Translation.tr("Overlap windows when center-only")
                    checked: page.barConfig.centerOnlyReserveFrame
                    onCheckedChanged: { page.barConfig.centerOnlyReserveFrame = checked; }
                }
                ConfigRow {
                    ConfigSwitch {
                        buttonIcon: "panorama_wide_angle"
                        text: Translation.tr("Show Frame")
                        checked: page.barConfig.showFrame

                        property bool switchReady: false
                        Component.onCompleted: Qt.callLater(() => switchReady = true)

                        onCheckedChanged: {
                            if (switchReady && checked) {
                                GlobalStates.refreshBar();
                            }
                            page.barConfig.showFrame = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "colors"
                        enabled: page.barConfig.showFrame
                        text: Translation.tr("Follow Frame Color")
                        checked: page.barConfig.followFrameColor
                        onCheckedChanged: { page.barConfig.followFrameColor = checked; }
                    }
                }
                ConfigSpinBox {
                    icon: "eraser_size_1"
                    text: Translation.tr("Frame thickness")
                    value: page.barConfig.frameThickness
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        page.barConfig.frameThickness = value;
                    }
                }
                ColorSelectionArray {
                    icon: "imagesearch_roller"
                    text: Translation.tr("Frame Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"] // sorry only solid colors transparency looks bad
                    currentValue: page.barConfig.frameColor
                    onSelected: newValue => {
                        page.barConfig.frameColor = newValue
                    }
                }
            }
        }

        ContentSection {
            icon: "nest_wifi_pro"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Dynamic Island")
            visible: page.isUsed("dynamicIsland")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Left widget")
                    icon: "right_panel_open"
                    currentValue: page.barConfig.dynamicIsland.leftWidget
                    onSelected: newValue => { page.barConfig.dynamicIsland.leftWidget = newValue; }
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
                    currentValue: page.barConfig.dynamicIsland.rightWidget
                    onSelected: newValue => { page.barConfig.dynamicIsland.rightWidget = newValue; }
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
                title: Translation.tr("Media")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Visualizer style")
                        icon: "graphic_eq"
                        currentValue: page.barConfig.dynamicIsland.visualizerStyle
                        onSelected: newValue => { page.barConfig.dynamicIsland.visualizerStyle = newValue; }
                        options: [
                            { displayName: Translation.tr(""),      icon: "block",       value: "none" },
                            { displayName: Translation.tr("Dots"),  icon: "steppers",     value: "dots" },
                            { displayName: Translation.tr("Wave"),  icon: "ssid_chart",   value: "wave" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "play_circle"
                        text: Translation.tr("Show media controls")
                        checked: page.barConfig.dynamicIsland.showMediaControls
                        onCheckedChanged: { page.barConfig.dynamicIsland.showMediaControls = checked; }
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
                    checked: page.barConfig.indicators.notifications.showUnreadCount
                    onCheckedChanged: { page.barConfig.indicators.notifications.showUnreadCount = checked; }
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
            visible: page.isUsed("sysTray")
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
            icon: "right_panel_open"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Left sidebar button")
            visible: page.isUsed("leftSidebarButton")

            GroupedList {
                ConfigRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 10

                    CustomIcon {
                        source: Config.options.custom.distroIcon || SystemInfo.distroIcon
                        colorize: Config.options.custom.colorizeIcon
                        color: page.leftIconColor
                        customFolder: Config.options.custom.iconsPath
                        width: Appearance.font.pixelSize.larger
                        height: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Icon")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: (Config.options.custom.distroIcon || SystemInfo.distroIcon).replace("-symbolic", "")
                        color: Appearance.colors.colSubtext
                    }
                }
                IconPickerGrid {
                    customFolder: Config.options.custom.iconsPath
                    currentValue: Config.options.custom.distroIcon
                    colorize: Config.options.custom.colorizeIcon
                    iconColor: page.leftIconColor
                    onSelected: name => { Config.options.custom.distroIcon = name }
                }
                ConfigTextArea {
                    id: iconsPathField
                    Layout.fillWidth: true
                    buttonIcon: "folder_open"
                    text: Translation.tr("Custom icons folder")
                    placeholderText: Translation.tr("Leave empty to use the built-in icons, e.g. ~/Pictures/icons")
                    value: Config.options.custom.iconsPath
                    onValueChanged: iconsPathDebounce.restart()

                    Timer {
                        id: iconsPathDebounce
                        interval: 600
                        onTriggered: Config.options.custom.iconsPath = iconsPathField.value
                    }
                }
                ConfigSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Colorize icon")
                    checked: Config.options.custom.colorizeIcon
                    onCheckedChanged: { Config.options.custom.colorizeIcon = checked }
                }
                ColorSelectionArray {
                    enabled: Config.options.custom.colorizeIcon
                    opacity: enabled ? 1 : 0.4
                    icon: "palette"
                    text: Translation.tr("Icon color")
                    options: ["onLayer0", "primary", "secondary", "tertiary", "onPrimaryContainer", "onSecondaryContainer", "onTertiaryContainer"]
                    currentValue: Config.options.custom.iconColor
                    onSelected: newValue => { Config.options.custom.iconColor = newValue }
                }
            }
        }

        ContentSection {
            icon: "vertical_align_center"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Divider")
            visible: page.isUsed("divisor")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.barConfig.divider.style
                    onSelected: newValue => { page.barConfig.divider.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Line"),  icon: "more_vert",       value: "rect" },
                        { displayName: Translation.tr("Dot"),   icon: "fiber_manual_record", value: "dot" },
                        { displayName: Translation.tr("Space"), icon: "space_bar",       value: "space" }
                    ]
                }
                ConfigSpinBox {
                    icon: "width"
                    enabled: page.barConfig.divider.style === "space"
                    text: Translation.tr("Space width (px)")
                    value: page.barConfig.divider.spacing
                    from: 4
                    to: 400
                    stepSize: 2
                    onValueChanged: {
                        page.barConfig.divider.spacing = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "buttons_alt"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Utility buttons")
            visible: page.isUsed("utilButtons")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screenshot_region"
                        text: Translation.tr("Screen snip")
                        checked: page.barConfig.utilButtons.showScreenSnip
                        onCheckedChanged: { page.barConfig.utilButtons.showScreenSnip = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "colorize"
                        text: Translation.tr("Color picker")
                        checked: page.barConfig.utilButtons.showColorPicker
                        onCheckedChanged: { page.barConfig.utilButtons.showColorPicker = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard toggle")
                        checked: page.barConfig.utilButtons.showKeyboardToggle
                        onCheckedChanged: { page.barConfig.utilButtons.showKeyboardToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "mic"
                        text: Translation.tr("Mic toggle")
                        checked: page.barConfig.utilButtons.showMicToggle
                        onCheckedChanged: { page.barConfig.utilButtons.showMicToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "dark_mode"
                        text: Translation.tr("Dark/Light toggle")
                        checked: page.barConfig.utilButtons.showDarkModeToggle
                        onCheckedChanged: { page.barConfig.utilButtons.showDarkModeToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "speed"
                        text: Translation.tr("Performance Profile")
                        checked: page.barConfig.utilButtons.showPerformanceProfileToggle
                        onCheckedChanged: { page.barConfig.utilButtons.showPerformanceProfileToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screen_record"
                        text: Translation.tr("Record Screen")
                        checked: page.barConfig.utilButtons.showScreenRecord
                        onCheckedChanged: { page.barConfig.utilButtons.showScreenRecord = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "imagesmode"
                        text: Translation.tr("Wallpapers Toggle")
                        checked: page.barConfig.utilButtons.showWallpaperToggle
                        onCheckedChanged: { page.barConfig.utilButtons.showWallpaperToggle = checked }
                    }
                }
            }
        }

        ContentSection {
            shape: MaterialShape.Shape.Cookie12Sided
            icon: "steppers"; title: Translation.tr("Workspaces")
            visible: page.isUsed("workspaces")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.barConfig.workspaces.style ?? "default"
                    onSelected: newValue => {
                        page.barConfig.workspaces.style = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "view_carousel",         value: "default" },
                        { displayName: Translation.tr("GNOME"),   icon: "more_horiz",            value: "gnome" },
                        { displayName: Translation.tr("Dots"),    icon: "hdr_weak",               value: "dots" },
                        { displayName: Translation.tr("Ticks"),   icon: "more_vert",             value: "ticks" }
                    ]
                }
                ConfigSpinBox {
                    icon: "view_column"; text: Translation.tr("Workspaces shown")
                    value: page.barConfig.workspaces.shown
                    from: 1; to: 30
                    onValueChanged: { page.barConfig.workspaces.shown = value; }
                }
                ConfigSwitch {
                    enabled: page.defaultWorkspacesDesign
                    buttonIcon: "counter_1"; text: Translation.tr("Always show numbers")
                    checked: page.barConfig.workspaces.alwaysShowNumbers
                    onCheckedChanged: { page.barConfig.workspaces.alwaysShowNumbers = checked; }
                }
                ConfigSelectionArray {
                    enabled: page.defaultWorkspacesDesign
                    opacity: page.defaultWorkspacesDesign ? 1 : 0.5
                    text: Translation.tr("Numbers style")
                    icon: "looks_3"
                    currentValue: JSON.stringify(page.barConfig.workspaces.numberMap)
                    onSelected: newValue => {
                        page.barConfig.workspaces.numberMap = JSON.parse(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                        { displayName: Translation.tr("Han chars"), icon: "glyphs",          value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                        { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                    ]
                }
                ConfigSwitch {
                    enabled: page.defaultWorkspacesDesign
                    buttonIcon: "award_star"; text: Translation.tr("Show app icons")
                    checked: page.barConfig.workspaces.showAppIcons
                    onCheckedChanged: { page.barConfig.workspaces.showAppIcons = checked; }
                }
                ConfigSelectionArray {
                    enabled: page.defaultWorkspacesDesign
                    opacity: page.defaultWorkspacesDesign ? 1 : 0.5
                    text: Translation.tr("Indicator style")
                    icon: "page_control"
                    currentValue: page.barConfig.workspaces.indicatorStyle ?? "icon"
                    onSelected: newValue => {
                        page.barConfig.workspaces.indicatorStyle = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Dots"),  icon: "radio_button_checked",   value: "dot" },
                        { displayName: Translation.tr("Icons"), icon: "interests",              value: "icon" },
                    ]
                }
            }
        }

        ContentSection {
            icon: "battery_android_full"
            title: Translation.tr("Battery")
            visible: page.isUsed("batteryIndicator")

            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "style"
                    text: Translation.tr("Battery style")
                    fieldWidth: 220
                    fixedWidth: true
                    currentValue: page.barConfig.battery.style
                    onSelected: newValue => { page.barConfig.battery.style = newValue }
                    model: [
                        { displayName: "Android", value: "bar" },
                        { displayName: "iOS", value: "ios" },
                        { displayName: "macOS", value: "macos" },
                        { displayName: "Windows", value: "windows" },
                        { displayName: Translation.tr("Ring"), value: "ring" },
                        { displayName: Translation.tr("Icon"), value: "icon" },
                        { displayName: Translation.tr("Number"), value: "number" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "percent"
                    text: Translation.tr("Show percentage")
                    checked: page.barConfig.battery.showPercentage
                    onCheckedChanged: { page.barConfig.battery.showPercentage = checked }
                }
                ConfigSwitch {
                    buttonIcon: "bolt"
                    text: Translation.tr("Charging bolt")
                    checked: page.barConfig.battery.showCharging
                    onCheckedChanged: { page.barConfig.battery.showCharging = checked }
                }
            }
        }

        ContentSection {
            icon: "empty_dashboard"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Resources")
            visible: page.isUsed("resources")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "planner_review"
                        text: Translation.tr("CPU")
                        checked: page.barConfig.resources.alwaysShowCpu
                        onCheckedChanged: { page.barConfig.resources.alwaysShowCpu = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "thermostat"
                        text: Translation.tr("CPU Temperature")
                        checked: page.barConfig.resources.alwaysShowCpuTemp
                        onCheckedChanged: { page.barConfig.resources.alwaysShowCpuTemp = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "memory"
                        text: Translation.tr("RAM")
                        checked: page.barConfig.resources.alwaysShowRam
                        onCheckedChanged: { page.barConfig.resources.alwaysShowRam = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "storage"
                        text: Translation.tr("Disk")
                        checked: page.barConfig.resources.alwaysShowDisk
                        onCheckedChanged: { page.barConfig.resources.alwaysShowDisk = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "swap_horiz"
                        text: Translation.tr("Swap")
                        checked: page.barConfig.resources.alwaysShowSwap
                        onCheckedChanged: { page.barConfig.resources.alwaysShowSwap = checked }
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.barConfig.resources.style
                    onSelected: newValue => { page.barConfig.resources.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Filled"),    icon: "incomplete_circle",  value: "filled" },
                        { displayName: Translation.tr("Outline"),   icon: "circles",            value: "outline" },
                        { displayName: Translation.tr("Text"),      icon: "text_fields",        value: "text" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "decimal_increase"; text: Translation.tr("Show Percentage")
                    checked: page.barConfig.resources.showValue
                    onCheckedChanged: { page.barConfig.resources.showValue = checked; }
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
            visible: page.isUsed("media")

            GroupedList {
                ConfigTextArea {
                    id: preferredPlayerField
                    Layout.fillWidth: true
                    buttonIcon: "play_circle"
                    text: Translation.tr("Preferred Player")
                    placeholderText: Translation.tr("e.g. spotify, firefox")
                    value: page.barConfig.media.preferredPlayer
                    onValueChanged: {
                        mediaDebounceTimer.restart();
                    }

                    Timer {
                        id: mediaDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            page.barConfig.media.preferredPlayer = preferredPlayerField.value;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Pin media controls")
                    checked: page.barConfig.media.alwaysVisible
                    onCheckedChanged: { page.barConfig.media.alwaysVisible = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "titlecase"; text: Translation.tr("Show only title")
                    checked: page.barConfig.media.onlyTitle
                    onCheckedChanged: { page.barConfig.media.onlyTitle = checked; }
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Max media width")
                    value: page.barConfig.media.maxWidth
                    from: 100
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        page.barConfig.media.maxWidth = value;
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
                    checked: page.barConfig.tooltips.enable
                    onCheckedChanged: { page.barConfig.tooltips.enable = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "ads_click"; text: Translation.tr("Click to show")
                    checked: page.barConfig.tooltips.clickToShow
                    onCheckedChanged: { page.barConfig.tooltips.clickToShow = checked; }
                    enabled: page.barConfig.tooltips.enable
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "tooltip"
                    enabled: page.barConfig.tooltips.enable
                    currentValue: page.barConfig.tooltips.style
                    onSelected: newValue => { page.barConfig.tooltips.style = newValue }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "tooltip", value: "default" },
                        { displayName: Translation.tr("Morph"), icon: "join_inner", value: "morph" }
                    ]
                }
            }
        }
    }
}
