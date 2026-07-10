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

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20
            
        ContentSection {
            icon: "panorama"
            title: Translation.tr("Wallpaper")
            shape: MaterialShape.Shape.Clover4Leaf

            ContentSubsection {
                title: Translation.tr("Transition")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.background.wallpaperAnimation
                    onSelected: newValue => {
                        Config.options.background.wallpaperAnimation = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr(""),
                            icon: "block",
                            value: ""
                        },
                        {
                            displayName: Translation.tr("Circle"),
                            icon: "circle",
                            value: "circleSelect"
                        },
                        {
                            displayName: Translation.tr("Circle Pit"),
                            icon: "blur_circular",
                            value: "circlePit"
                        },
                        {
                            displayName: Translation.tr("Magic"),
                            icon: "auto_awesome",
                            value: "magic"
                        },
                        {
                            displayName: Translation.tr("Doom"),
                            icon: "whatshot",
                            value: "Doom"
                        },
                        {
                            displayName: Translation.tr("Peel"),
                            icon: "layers",
                            value: "Peel"
                        },
                        {
                            displayName: Translation.tr("Fade"),
                            icon: "gradient",
                            value: "transition"
                        },
                        {
                            displayName: Translation.tr("Pixelate"),
                            icon: "grain",
                            value: "pixelate"
                        },
                        {
                            displayName: Translation.tr("Stripes"),
                            icon: "texture_minus",
                            value: "stripes"
                        },
                        {
                            displayName: Translation.tr("Random"),
                            icon: "shuffle",
                            value: "random"
                        },
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Centered wallpaper")
                Layout.fillWidth: true

                GroupedList {
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.background.centeredWallpaper
                        onCheckedChanged: {
                            Config.options.background.centeredWallpaper = checked;
                        }
                    }
                    ConfigSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "lock"
                        text: Translation.tr("Show only when locked")
                        checked: Config.options.background.centeredWallpaperOnlyWhenLocked
                        onCheckedChanged: {
                            Config.options.background.centeredWallpaperOnlyWhenLocked = checked;
                        }
                        enabled: Config.options.background.centeredWallpaper
                    }
                }

                ContentSubsection {
                    visible: Config.options.background.centeredWallpaper
                    title: Translation.tr("Shape")

                    ConfigSelectionShapeArray {
                        currentValue: Config.options.background.centeredWallpaperShape
                        shapeColor: Appearance.colors.colPrimary
                        backgroundColor: Appearance.colors.colPrimaryContainer
                        options: [
                            "Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill",
                            "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny",
                            "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided",
                            "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower",
                            "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"
                        ]
                        onSelected: newValue => {
                            Config.options.background.centeredWallpaperShape = newValue
                        }
                    }
                }
                GroupedList {
                    Layout.topMargin: 10
                    visible: Config.options.background.centeredWallpaper
                    ColorSelectionArray {
                        visible: Config.options.background.centeredWallpaper
                        icon: "palette"
                        text: Translation.tr("Background Color")
                        currentValue: Config.options.background.centeredWallpaperColor
                        onSelected: newValue => {
                            Config.options.background.centeredWallpaperColor = newValue
                        }
                    }
                    ConfigSlider {
                        visible: Config.options.background.centeredWallpaper
                        text: Translation.tr("Size")
                        value: Config.options.background.centeredWallpaperSize
                        usePercentTooltip: false
                        buttonIcon: "aspect_ratio"
                        from: 400
                        to: 800
                        stopIndicatorValues: [400]
                        onValueChanged: {
                            Config.options.background.centeredWallpaperSize = value;
                        }
                    }
                }
            }
        }

        ContentSection {
            id: settingsClock
            icon: "clock_loader_40"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Clock")

            function stylePresent(styleName) {
                if (!Config.options.background.widgets.clock.showOnlyWhenLocked && Config.options.background.widgets.clock.style === styleName) {
                    return true;
                }
                if (Config.options.background.widgets.clock.styleLocked === styleName) {
                    return true;
                }
                return false;
            }

            readonly property bool digitalPresent: stylePresent("digital")
            readonly property bool cookiePresent: stylePresent("cookie")

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.enable = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "lock_clock"
                    text: Translation.tr("Show only when locked")
                    checked: Config.options.background.widgets.clock.showOnlyWhenLocked
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.showOnlyWhenLocked = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Placement strategy")
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.clock.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }

            ConfigRow {
                ContentSubsection {
                    visible: !Config.options.background.widgets.clock.showOnlyWhenLocked
                    title: Translation.tr("Clock style")
                    Layout.fillWidth: true
                    ConfigSelectionArray {
                        currentValue: Config.options.background.widgets.clock.style
                        onSelected: newValue => {
                            Config.options.background.widgets.clock.style = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Digital"),
                                icon: "timer_10",
                                value: "digital"
                            },
                            {
                                displayName: Translation.tr("Cookie"),
                                icon: "cookie",
                                value: "cookie"
                            }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Clock style (locked)")
                    Layout.fillWidth: false
                    ConfigSelectionArray {
                        currentValue: Config.options.background.widgets.clock.styleLocked
                        onSelected: newValue => {
                            Config.options.background.widgets.clock.styleLocked = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Digital"),
                                icon: "timer_10",
                                value: "digital"
                            },
                            {
                                displayName: Translation.tr("Cookie"),
                                icon: "cookie",
                                value: "cookie"
                            }
                        ]
                    }
                }
            }

            ContentSubsection {
                visible: settingsClock.digitalPresent
                title: Translation.tr("Digital clock settings")

                ConfigRow {
                    uniform: true

                    GroupedList {
                        ConfigSwitch {
                            buttonIcon: "vertical_distribute"
                            text: Translation.tr("Vertical")
                            checked: Config.options.background.widgets.clock.digital.vertical
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.vertical = checked }
                        }
                        ConfigSwitch {
                            buttonIcon: "date_range"
                            text: Translation.tr("Show date")
                            checked: Config.options.background.widgets.clock.digital.showDate
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.showDate = checked }
                        }
                    }

                    GroupedList {
                        ConfigSwitch {
                            buttonIcon: "animation"
                            text: Translation.tr("Animate time change")
                            checked: Config.options.background.widgets.clock.digital.animateChange
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.animateChange = checked }
                        }
                        ConfigSwitch {
                            buttonIcon: "activity_zone"
                            text: Translation.tr("Use adaptive alignment")
                            checked: Config.options.background.widgets.clock.digital.adaptiveAlignment
                            onCheckedChanged: { Config.options.background.widgets.clock.digital.adaptiveAlignment = checked }
                        }
                    }
                }

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Font family")
                    text: Config.options.background.widgets.clock.digital.font.family
                    wrapMode: TextEdit.Wrap

                    Timer {
                        id: debounceTimer
                        interval: 500
                        repeat: false
                        onTriggered: {
                            Config.options.background.widgets.clock.digital.font.family = parent.text
                        }
                    }

                    onTextChanged: {
                        debounceTimer.restart()
                    }
                }
                GroupedList {
                    Layout.topMargin: 10
                    ConfigSlider {
                        text: Translation.tr("Font weight")
                        value: Config.options.background.widgets.clock.digital.font.weight
                        usePercentTooltip: false
                        buttonIcon: "format_bold"
                        from: 1
                        to: 1000
                        stopIndicatorValues: [350]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.weight = value;
                        }
                    }

                    ConfigSlider {
                        text: Translation.tr("Font size")
                        value: Config.options.background.widgets.clock.digital.font.size
                        usePercentTooltip: false
                        buttonIcon: "format_size"
                        from: 50
                        to: 700
                        stopIndicatorValues: [90]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.size = value;
                        }
                    }

                    ConfigSlider {
                        text: Translation.tr("Font width")
                        value: Config.options.background.widgets.clock.digital.font.width
                        usePercentTooltip: false
                        buttonIcon: "fit_width"
                        from: 25
                        to: 125
                        stopIndicatorValues: [100]
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.width = value;
                        }
                    }
                    ConfigSlider {
                        text: Translation.tr("Font roundness")
                        value: Config.options.background.widgets.clock.digital.font.roundness
                        usePercentTooltip: false
                        buttonIcon: "line_curve"
                        from: 0
                        to: 100
                        onValueChanged: {
                            Config.options.background.widgets.clock.digital.font.roundness = value;
                        }
                    }
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Cookie clock settings")
                GroupedList {    
                    ConfigSwitch {  
                        buttonIcon: "wand_stars"
                        text: Translation.tr("Auto styling with Gemini")
                        checked: Config.options.background.widgets.clock.cookie.aiStyling
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.aiStyling = checked;
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "airwave"
                        text: Translation.tr("Use old sine wave cookie implementation")
                        checked: Config.options.background.widgets.clock.cookie.useSineCookie
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.useSineCookie = checked;
                        }
                    }

                    ConfigSpinBox {
                        icon: "add_triangle"
                        text: Translation.tr("Sides")
                        value: Config.options.background.widgets.clock.cookie.sides
                        from: 0
                        to: 40
                        stepSize: 1
                        onValueChanged: {
                            Config.options.background.widgets.clock.cookie.sides = value;
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "autoplay"
                        text: Translation.tr("Constantly rotate")
                        checked: Config.options.background.widgets.clock.cookie.constantlyRotate
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.constantlyRotate = checked;
                        }
                    }

                    ConfigRow {

                        ConfigSwitch {
                            enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle === "dots" || Config.options.background.widgets.clock.cookie.dialNumberStyle === "full"
                            buttonIcon: "brightness_7"
                            text: Translation.tr("Hour marks")
                            checked: Config.options.background.widgets.clock.cookie.hourMarks
                            onEnabledChanged: {
                                checked = Config.options.background.widgets.clock.cookie.hourMarks;
                            }
                            onCheckedChanged: {
                                Config.options.background.widgets.clock.cookie.hourMarks = checked;
                            }
                        }

                        ConfigSwitch {
                            enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                            buttonIcon: "timer_10"
                            text: Translation.tr("Digits in the middle")
                            checked: Config.options.background.widgets.clock.cookie.timeIndicators
                            onEnabledChanged: {
                                checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                            }
                            onCheckedChanged: {
                                Config.options.background.widgets.clock.cookie.timeIndicators = checked;
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Dial style")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dialNumberStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dialNumberStyle = newValue;
                        if (newValue !== "dots" && newValue !== "full") {
                            Config.options.background.widgets.clock.cookie.hourMarks = false;
                        }
                        if (newValue === "numbers") {
                            Config.options.background.widgets.clock.cookie.timeIndicators = false;
                        }
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "none"
                        },
                        {
                            displayName: Translation.tr("Dots"),
                            icon: "graph_6",
                            value: "dots"
                        },
                        {
                            displayName: Translation.tr("Full"),
                            icon: "history_toggle_off",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Numbers"),
                            icon: "counter_1",
                            value: "numbers"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Hour hand")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.hourHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.hourHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Hollow"),
                            icon: "circle",
                            value: "hollow"
                        },
                        {
                            displayName: Translation.tr("Fill"),
                            icon: "eraser_size_5",
                            value: "fill"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Minute hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.minuteHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.minuteHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Thin"),
                            icon: "line_end",
                            value: "thin"
                        },
                        {
                            displayName: Translation.tr("Medium"),
                            icon: "eraser_size_2",
                            value: "medium"
                        },
                        {
                            displayName: Translation.tr("Bold"),
                            icon: "eraser_size_4",
                            value: "bold"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Second hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.secondHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.secondHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Line"),
                            icon: "line_end",
                            value: "line"
                        },
                        {
                            displayName: Translation.tr("Dot"),
                            icon: "adjust",
                            value: "dot"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: settingsClock.cookiePresent
                title: Translation.tr("Date style")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dateStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dateStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Bubble"),
                            icon: "bubble_chart",
                            value: "bubble"
                        },
                        {
                            displayName: Translation.tr("Border"),
                            icon: "rotate_right",
                            value: "border"
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "rectangle",
                            value: "rect"
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Quote")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.background.widgets.clock.quote.enable
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.quote.enable = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "font_download"
                        text: Translation.tr("Clock Font")
                        checked: Config.options.background.widgets.clock.quote.followClock
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.quote.followClock = checked;
                        }
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Quote")
                    text: Config.options.background.widgets.clock.quote.text
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.background.widgets.clock.quote.text = text;
                    }
                }
            }
        }

        ContentSection {
            icon: "panorama"
            shape: MaterialShape.Shape.SoftBoom 
            title: Translation.tr("Custom Image")
            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.customImage.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.customImage.enable = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Background shape")
                            
                ConfigSelectionShapeArray {
                    currentValue: Config.options.background.widgets.customImage.shape
                    shapeColor: Appearance.colors.colPrimary
                    backgroundColor: Appearance.colors.colPrimaryContainer
                    options: [
                        "Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill",
                        "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny",
                        "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided",
                        "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower",
                        "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"
                    ]
                    onSelected: newValue => {
                        Config.options.background.widgets.customImage.shape = newValue
                    }
                }
            }
        }

        ContentSection {
            icon: "widgets"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Widgets")

            ContentSubsection {
                title: Translation.tr("Show widgets on")
                visible: Hyprland.monitors.values.length > 1
                Layout.bottomMargin: 10

                WidgetsMonitorSelector {
                    configEntry: Config.options.background
                }
            }

            
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: [
                        {
                            icon: "weather_mix",
                            name: Translation.tr("Weather"),
                            enabled: Config.options.background.widgets.weather.enable
                        },
                        {
                            icon: "image",
                            name: Translation.tr("Image converter"),
                            enabled: Config.options.background.widgets.images.enable
                        },
                        {
                            icon: "music_note",
                            name: Translation.tr("Media Player"),
                            enabled: Config.options.background.widgets.media.enable
                        },
                        {
                            icon: "memory",
                            name: Translation.tr("Resources"),
                            enabled: Config.options.background.widgets.resources.enable
                        },
                        {
                            icon: "graphic_eq",
                            name: Translation.tr("Visualizer"),
                            enabled: Config.options.background.widgets.visualizer.enable
                        },
                        {
                            icon: "calendar_month",
                            name: Translation.tr("Calendar"),
                            enabled: Config.options.background.widgets.calendar.enable
                        },
                        {
                            icon: "public",
                            name: Translation.tr("World Clock"),
                            enabled: Config.options.background.widgets.worldClock.enable
                        },
                        {
                            icon: "person",
                            name: Translation.tr("User Card"),
                            enabled: Config.options.background.widgets.userCard.enable
                        }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 105
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        ColumnLayout {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                margins: 12
                            }
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal + 5
                                    color: Appearance.colors.colPrimary
                                }
                                Item { Layout.fillWidth: true }
                                ConfigSwitch {
                                    Layout.fillWidth: false
                                    checked: modelData.enabled
                                    onCheckedChanged: {
                                        if (modelData.icon === "weather_mix")
                                            Config.options.background.widgets.weather.enable = checked
                                        else if (modelData.icon === "image")
                                            Config.options.background.widgets.images.enable = checked
                                        else if (modelData.icon === "music_note")
                                            Config.options.background.widgets.media.enable = checked
                                        else if (modelData.icon === "memory")
                                            Config.options.background.widgets.resources.enable = checked
                                        else if (modelData.icon === "graphic_eq")
                                            Config.options.background.widgets.visualizer.enable = checked
                                        else if (modelData.icon === "calendar_month")
                                            Config.options.background.widgets.calendar.enable = checked
                                        else if (modelData.icon === "public")
                                            Config.options.background.widgets.worldClock.enable = checked
                                        else if (modelData.icon === "person")
                                            Config.options.background.widgets.userCard.enable = checked
                                    }
                                }
                            }
                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: modelData.enabled ? Translation.tr("Enabled") : Translation.tr("Disabled")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }
    }
}
