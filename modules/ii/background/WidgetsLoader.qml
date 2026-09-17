pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.customtext
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.worldclock
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.todo
import qs.modules.ii.background.widgets.timers
import qs.modules.ii.background.widgets.customtext

Item {
    id: root

    required property var screen
    required property var wallpaperItem
    required property bool wallpaperSafetyTriggered
    required property var canvas

    readonly property bool onThisScreen: Config.options.background.screenList.length === 0
        || Config.options.background.screenList.includes(root.screen.name)

    Repeater {
        model: [
            { key: "visualizer" },
            { key: "customImage" },
            { key: "calendar" },
            { key: "weather" },
            { key: "clock", alwaysOnLock: true },
            { key: "notes" },
            { key: "media" },
            { key: "images" },
            { key: "resources" },
            { key: "worldClock" },
            { key: "userCard" },
            { key: "todo" },
            { key: "timers" },
            { key: "customText" },
        ]

        delegate: FadeLoader {
            id: loaderDelegate
            required property var modelData

            property bool enableLoading: true
            property bool wasEnabled: Config.options.background.widgets[loaderDelegate.modelData.key].enable
            // Whenever a widget is toggled ON, reset it to the default
            // depth position (above the highest wallpaper layer) — this
            // replaces the obsolete "bringToFront" enable behaviour, but now
            // relative to the depth wallpaper layers instead of other widgets.
            Connections {
                target: Config.options.background.widgets[loaderDelegate.modelData.key]
                function onEnableChanged() {
                    const now = Config.options.background.widgets[loaderDelegate.modelData.key].enable
                    if (!loaderDelegate.wasEnabled && now) {
                        Config.options.background.widgets[loaderDelegate.modelData.key].depthLayerPosition = -1
                    }
                    loaderDelegate.wasEnabled = now
                }
            }
            // Widgets are hosted in the depth wallpaper container so their z
            // can sit between wallpaper layers; the canvas is passed explicitly
            // (they are no longer children of it).
            canvas: root.canvas

            shown: Config.options.background.widgets[loaderDelegate.modelData.key].enable
                && loaderDelegate.enableLoading
                && (loaderDelegate.modelData.alwaysOnLock
                    ? (GlobalStates.screenLocked || root.onThisScreen)
                    : root.onThisScreen)

            sourceComponent: {
                switch (loaderDelegate.modelData.key) {
                    case "visualizer":  return visualizerComp
                    case "customImage": return customImageComp
                    case "calendar":    return calendarComp
                    case "weather":     return weatherComp
                    case "clock":       return clockComp
                    case "notes":       return notesComp
                    case "media":       return mediaComp
                    case "images":      return imagesComp
                    case "resources":   return resourcesComp
                    case "worldClock":  return worldClockComp
                    case "userCard":    return userCardComp
                    case "todo":        return todoComp
                    case "timers":      return timersComp
                    case "customText":  return customTextComp
                }
                return null
            }

            onLoaded: {
                if (loaderDelegate.modelData.key === "media" && loaderDelegate.item && loaderDelegate.item.requestReset) {
                    loaderDelegate.item.requestReset.connect(() => {
                        loaderDelegate.enableLoading = false
                        mediaResetTimer.restart()
                    })
                }
            }

            Timer {
                id: mediaResetTimer
                interval: 500
                onTriggered: loaderDelegate.enableLoading = true
            }
        }
    }

    // Fully independent user-defined text widgets. Each id in customWidgetIds
    // maps to an entry in widgets.customWidgets. A whole-list reassignment
    // (CustomWidgets.save) drives reactivity, so shown/enable just read the
    // resolved entry.
    Repeater {
        id: customWidgetRepeater
        model: Config.options.background.widgets.customWidgetIds

        delegate: FadeLoader {
            id: customWidgetLoader
            required property string modelData

            canvas: root.canvas
            shown: ((Config.options.background.widgets.customWidgets ?? [])
                .find(w => w?.id === customWidgetLoader.modelData)?.enable ?? false)
                && root.onThisScreen

            sourceComponent: Component {
                CustomTextWidget {
                    configEntryName: customWidgetLoader.modelData
                    screenWidth: root.screen.width
                    screenHeight: root.screen.height
                    scaledScreenWidth: root.screen.width
                    scaledScreenHeight: root.screen.height
                    wallpaperScale: 1
                    wallpaperItem: root.wallpaperItem
                    backdropHost: root
                }
            }
        }
    }

    Component {
        id: visualizerComp
        VisualizerWidget {
            showSelectionBorder: false
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            pinnedBottom: true
        }
    }
    Component {
        id: customImageComp
        CustomImage {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: calendarComp
        CalendarWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: weatherComp
        WeatherWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: clockComp
        ClockWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperSafetyTriggered: root.wallpaperSafetyTriggered
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: notesComp
        NotesWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: mediaComp
        MediaWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: imagesComp
        ImageConverterWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: resourcesComp
        ResourcesWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: worldClockComp
        WorldClockWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: userCardComp
        UserCardWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: todoComp
        TodoWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: timersComp
        TimerWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
            backdropHost: root
        }
    }
    Component {
        id: customTextComp
        CustomTextWidget {
            screenWidth: root.screen.width
            screenHeight: root.screen.height
            scaledScreenWidth: root.screen.width
            scaledScreenHeight: root.screen.height
            wallpaperScale: 1
            wallpaperItem: root.wallpaperItem
        }
    }
}