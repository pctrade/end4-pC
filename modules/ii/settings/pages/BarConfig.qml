import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Hyprland

ContentPage {
    id: rootPage
    forceWidth: true

    property var allWidgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button") },
        { id: "workspaces",        name: Translation.tr("Workspaces") },
        { id: "weatherBar",        name: Translation.tr("Weather") },
        { id: "media",             name: Translation.tr("Media") },
        { id: "resources",         name: Translation.tr("Resources") },
        { id: "systemIcons",       name: Translation.tr("System Icons") },
        { id: "clockWidget",       name: Translation.tr("Clock") },
        { id: "utilButtons",       name: Translation.tr("Util Buttons") },
        { id: "sysTray",           name: Translation.tr("Tray") },
        { id: "batteryIndicator",  name: Translation.tr("Battery") },
        { id: "activeWindow",      name: Translation.tr("Active Window") }
    ]

    function availableFor() {
        let used = [
            ...Config.options.bar.layouts.leftLayout,
            ...Config.options.bar.layouts.middleLayout,
            ...Config.options.bar.layouts.rightLayout
        ]
        return allWidgets.filter(w => !used.includes(w.id))
    }

    function getWidgetName(id) {
        const w = allWidgets.find(w => w.id === id)
        return w ? w.name : id
    }

    ContentSection {
        icon: "monitor"
        shape: MaterialShape.Shape.ClamShell
        visible: Hyprland.monitors.values.length > 1
        title: Translation.tr("Screens")
        ContentSubsection {
            title: Translation.tr("Show bar on")
            Flow {
                Layout.fillWidth: true; spacing: 2
                SelectionGroupButton {
                    leftmost: true; rightmost: Hyprland.monitors.length === 0
                    buttonIcon: "tv_displays"; buttonText: Translation.tr("All")
                    toggled: Config.options.bar.screenList.length === 0
                    onClicked: Config.options.bar.screenList = []
                }
                Repeater {
                    model: Hyprland.monitors
                    delegate: SelectionGroupButton {
                        required property var modelData; required property int index
                        leftmost: false; rightmost: index === Hyprland.monitors.length - 1
                        buttonIcon: "monitor"; buttonText: modelData.name
                        toggled: Config.options.bar.screenList.includes(modelData.name)
                        onClicked: {
                            const allNames = Array.from({length: Hyprland.monitors.length}, (_, i) => Hyprland.monitors[i].name)
                            let list = Config.options.bar.screenList.length === 0 ? allNames.slice() : Config.options.bar.screenList.slice()
                            if (toggled) list = list.filter(s => s !== modelData.name)
                            else list.push(modelData.name)
                            Config.options.bar.screenList = list.length === allNames.length ? [] : list
                        }
                    }
                }
                SelectionGroupButton {
                    leftmost: false
                    rightmost: true
                    buttonIcon: "page_footer"
                    buttonText: Translation.tr("")
                }
            }
        }
    }

    ContentSection {
        icon: "splitscreen_add"
        shape: MaterialShape.Shape.Cookie6Sided
        title: Translation.tr("Bar layout")

        LayoutSection {
            sectionTitle: Config.options.bar.vertical ? Translation.tr("Top") : Translation.tr("Left")
            layout: Config.options.bar.layouts.leftLayout
            availableWidgets: rootPage.availableFor()
            getWidgetName: rootPage.getWidgetName
            onUpdate: list => Config.options.bar.layouts.leftLayout = list
        }

        LayoutSection {
            sectionTitle: Translation.tr("Center")
            layout: Config.options.bar.layouts.middleLayout
            availableWidgets: rootPage.availableFor()
            getWidgetName: rootPage.getWidgetName
            onUpdate: list => Config.options.bar.layouts.middleLayout = list
        }

        LayoutSection {
            sectionTitle: Config.options.bar.vertical ? Translation.tr("Bottom") : Translation.tr("Right")
            layout: Config.options.bar.layouts.rightLayout
            availableWidgets: rootPage.availableFor()
            getWidgetName: rootPage.getWidgetName
            onUpdate: list => Config.options.bar.layouts.rightLayout = list
        }
    }

    ContentSection {
        icon: "pivot_table_chart"
        shape: MaterialShape.Shape.Gem
        title: Translation.tr("Positioning")
        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position"); Layout.fillWidth: true
                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        { displayName: Translation.tr("Top"),    icon: "arrow_upward",  value: 0 },
                        { displayName: Translation.tr("Left"),   icon: "arrow_back",    value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"),  icon: "arrow_forward", value: 3 }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Automatically hide"); Layout.fillWidth: false
                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: newValue => { Config.options.bar.autoHide.enable = newValue; }
                    options: [
                        { displayName: Translation.tr("No"),  icon: "close", value: false },
                        { displayName: Translation.tr("Yes"), icon: "check", value: true }
                    ]
                }
            }
        }
        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Corner style"); Layout.fillWidth: true
                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => { Config.options.bar.cornerStyle = newValue; }
                    options: [
                        { displayName: Translation.tr("Hug"),     icon: "line_curve",  value: 0 },
                        { displayName: Translation.tr("Float"),   icon: "view_day", value: 1 },
                        { displayName: Translation.tr("Islands"), icon: "crop_3_2",    value: 2 }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Group style"); Layout.fillWidth: false
                ConfigSelectionArray {
                    currentValue: Config.options.bar.borderless
                    onSelected: newValue => { Config.options.bar.borderless = newValue; }
                    options: [
                        { displayName: Translation.tr("Pills"),          icon: "pill", value: false },
                        { displayName: Translation.tr("Separated"), icon: "split_scene",   value: true }
                    ]
                }
            }
        }
    }

    ContentSection {
        icon: "notifications"
        shape: MaterialShape.Shape.Bun
        title: Translation.tr("Notifications")
        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: { Config.options.bar.indicators.notifications.showUnreadCount = checked; }
        }
    }

    ContentSection {
        shape: MaterialShape.Shape.Square
        icon: "inbox_customize"
        title: Translation.tr("Tray")
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

    ContentSection {
        icon: "buttons_alt"
        shape: MaterialShape.Shape.SoftBurst
        title: Translation.tr("Utility buttons")
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "screenshot_region"; text: Translation.tr("Screen snip")
                checked: Config.options.bar.utilButtons.showScreenSnip
                onCheckedChanged: { Config.options.bar.utilButtons.showScreenSnip = checked; }
            }
            ConfigSwitch {
                buttonIcon: "colorize"; text: Translation.tr("Color picker")
                checked: Config.options.bar.utilButtons.showColorPicker
                onCheckedChanged: { Config.options.bar.utilButtons.showColorPicker = checked; }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "keyboard"; text: Translation.tr("Keyboard toggle")
                checked: Config.options.bar.utilButtons.showKeyboardToggle
                onCheckedChanged: { Config.options.bar.utilButtons.showKeyboardToggle = checked; }
            }
            ConfigSwitch {
                buttonIcon: "mic"; text: Translation.tr("Mic toggle")
                checked: Config.options.bar.utilButtons.showMicToggle
                onCheckedChanged: { Config.options.bar.utilButtons.showMicToggle = checked; }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "dark_mode"; text: Translation.tr("Dark/Light toggle")
                checked: Config.options.bar.utilButtons.showDarkModeToggle
                onCheckedChanged: { Config.options.bar.utilButtons.showDarkModeToggle = checked; }
            }
            ConfigSwitch {
                buttonIcon: "speed"; text: Translation.tr("Performance Profile toggle")
                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                onCheckedChanged: { Config.options.bar.utilButtons.showPerformanceProfileToggle = checked; }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "screen_record"; text: Translation.tr("Record")
                checked: Config.options.bar.utilButtons.showScreenRecord
                onCheckedChanged: { Config.options.bar.utilButtons.showScreenRecord = checked; }
            }
        }
    }

    ContentSection {
        shape: MaterialShape.Shape.Cookie12Sided
        icon: "steppers"; title: Translation.tr("Workspaces")
        ConfigSwitch {
            buttonIcon: "counter_1"; text: Translation.tr("Always show numbers")
            checked: Config.options.bar.workspaces.alwaysShowNumbers
            onCheckedChanged: { Config.options.bar.workspaces.alwaysShowNumbers = checked; }
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
    }

    ContentSubsection {
        title: Translation.tr("Number style")
        ConfigSelectionArray {
            currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap)
            onSelected: newValue => {
                Config.options.bar.workspaces.numberMap = JSON.parse(newValue)
            }
            options: [
                { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                { displayName: Translation.tr("Han chars"), icon: "glyphs",      value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
            ]
        }
    }

    ContentSection {
        shape: MaterialShape.Shape.Puffy
        icon: "tooltip"; title: Translation.tr("Tooltips")
        ConfigSwitch {
            buttonIcon: "ads_click"; text: Translation.tr("Click to show")
            checked: Config.options.bar.tooltips.clickToShow
            onCheckedChanged: { Config.options.bar.tooltips.clickToShow = checked; }
        }
    }
}