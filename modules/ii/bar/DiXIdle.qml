import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Home. It is a place, not a dashboard: the compact already told you what is happening now, so this only
// answers "what time/day is it, and where do I want to go" — clock, weather, and the Tool Dock. Anything that
// used to live here permanently (battery, network, updates, notifications, agents, F1, privacy) has its own
// Live/Peek surface now and only shows up on the island when it is actually true.
ColumnLayout {
    id: xi
    required property Item di
    spacing: 14
    implicitWidth: 360

    property bool moreOpen: false

    readonly property var pinLabels: ({
        weather: [Translation.tr("Weather"), "partly_cloudy_day"],
        shelf: [Translation.tr("Drawer"), "inventory_2"],
        clipboard: [Translation.tr("Clipboard"), "content_paste"],
        media: [Translation.tr("Media"), "music_note"],
        f1: ["F1", "sports_motorsports"],
        system: [Translation.tr("System"), "monitoring"],
        agents: [Translation.tr("AI agents"), "smart_toy"],
        download: [Translation.tr("Download"), "download"],
        zerotier: ["ZeroTier", "vpn_lock"]
    })

    readonly property string displayFont: {
        switch (xi.di.cfg.anchorFont ?? "expressive") {
            case "numbers":   return Appearance.font.family.numbers
            case "monospace": return Appearance.font.family.monospace
            case "main":      return Appearance.font.family.main
            default:          return Appearance.font.family.expressive
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        property color accent: Appearance.colors.colOnLayer1
        property bool active: false
        property var onTap: null
        implicitWidth: chipRow.implicitWidth + 22
        implicitHeight: 32
        radius: 16
        color: chip.active ? Appearance.colors.colPrimaryContainer
            : (chipMouse.containsMouse && chip.onTap ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)
        scale: chipMouse.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation { duration: 160 }
        }
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: chip.icon
                iconSize: 16
                fill: 1
                color: chip.active ? Appearance.colors.colOnPrimaryContainer : chip.accent
            }
            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: chip.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: chip.onTap ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (chip.onTap) chip.onTap()
        }
    }

    // Dock button: an icon, a one-word label, nothing else. Tools live behind intent, not in the queue.
    component DockButton: ColumnLayout {
        id: dock
        property string icon
        property string label
        property var onTap: null
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: 14
            color: dockMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
            scale: dockMouse.pressed ? 0.94 : 1

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
            Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutBack }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: dock.icon
                iconSize: 20
                fill: 1
                color: Appearance.colors.colOnLayer1
            }

            MouseArea {
                id: dockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (dock.onTap) dock.onTap()
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: dock.label
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer1
            opacity: 0.7
        }
    }

    // Header: the day, the clock, and the weather as one tappable line — the only things worth knowing
    // before you have asked for anything.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${Qt.locale().toString(new Date(), "dddd")}, ${DateTime.time}`
            font.family: xi.displayFont
            font.pixelSize: 22
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: xi.di.expand("calendar")
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            spacing: 5

            StyledText {
                text: DateTime.longDate
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
            }

            StyledText {
                visible: (Weather.data?.temp ?? "") !== ""
                text: "·"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.5
            }

            MaterialSymbol {
                visible: (Weather.data?.temp ?? "") !== ""
                text: IslandEvents.weatherSymbol(Weather.data?.wCode ?? 800)
                iconSize: 14
                fill: 1
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
            }

            StyledText {
                visible: (Weather.data?.temp ?? "") !== ""
                text: Weather.data?.temp ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.65

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xi.di.expand("weather")
                }
            }
        }
    }

    // Mini player: not invented content, just the direct answer to "what's happening now" when it applies
    Rectangle {
        Layout.fillWidth: true
        visible: xi.di.hasMedia
        implicitHeight: 52
        radius: 16
        color: ColorUtils.mix(Appearance.colors.colLayer1, xi.di.mediaArtColor, 0.82)

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 6
                rightMargin: 8
            }
            spacing: 10

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 10
                clip: true
                color: Appearance.colors.colLayer2

                StyledImage {
                    anchors.fill: parent
                    source: xi.di.activePlayer?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 80
                    sourceSize.height: 80
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: xi.di.activePlayer?.trackTitle ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: xi.di.activePlayer?.trackArtist ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: [
                    { icon: "skip_previous", action: () => xi.di.activePlayer?.previous() },
                    { icon: xi.di.activePlayer?.isPlaying ? "pause" : "play_arrow", action: () => xi.di.activePlayer?.togglePlaying() },
                    { icon: "skip_next", action: () => xi.di.activePlayer?.next() }
                ]
                delegate: MaterialSymbol {
                    required property var modelData
                    text: modelData.icon
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colOnLayer1

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }
                }
            }
        }
    }

    // What you pushed away lives here: silencing an island must be undoable from one obvious place,
    // and it is rare enough that it never competes with the dock below.
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: IslandEvents.silencedIslands.length > 0

        Repeater {
            model: IslandEvents.silencedIslands

            delegate: Chip {
                required property string modelData
                icon: "notifications_paused"
                label: `${xi.pinLabels[modelData]?.[0] ?? xi.di.nameForId(modelData)} · ${Translation.tr("bring back")}`
                accent: IslandEvents.colorAttention
                onTap: () => IslandEvents.restoreIsland(modelData)
            }
        }
    }

    // Tool Dock: four favorites, then More. This is the only way into Tools — they never compete for the
    // compact pill or the scroll wheel.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 4

        DockButton {
            icon: "apps"
            label: Translation.tr("Now")
            onTap: () => xi.di.expand("overview")
        }
        DockButton {
            icon: "inventory_2"
            label: Translation.tr("Drawer")
            onTap: () => xi.di.expand("shelf")
        }
        DockButton {
            icon: "content_paste"
            label: Translation.tr("Clipboard")
            onTap: () => xi.di.expand("clipboard")
        }
        DockButton {
            icon: "smart_toy"
            label: Translation.tr("Agents")
            onTap: () => xi.di.expand("agents")
        }
        DockButton {
            icon: xi.moreOpen ? "expand_less" : "more_horiz"
            label: Translation.tr("More")
            onTap: () => xi.moreOpen = !xi.moreOpen
        }
    }

    // More: everything else, behind one extra tap instead of permanently on screen.
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: xi.moreOpen

        Chip {
            icon: "partly_cloudy_day"
            label: Translation.tr("Weather")
            onTap: () => xi.di.expand("weather")
        }
        Chip {
            icon: "monitoring"
            label: Translation.tr("System")
            onTap: () => xi.di.expand("system")
        }
        Chip {
            icon: "vpn_lock"
            label: "ZeroTier"
            onTap: () => xi.di.expand("zerotier")
        }
        Chip {
            icon: "history"
            label: Translation.tr("History")
            onTap: () => xi.di.expand("history")
        }
        Chip {
            icon: IslandEvents.caffeineOn ? "local_cafe" : "bedtime"
            label: IslandEvents.caffeineOn
                ? (IslandEvents.caffeineMinutesLeft >= 0 ? Translation.tr("Awake · %1 min").arg(IslandEvents.caffeineMinutesLeft) : Translation.tr("Awake"))
                : Translation.tr("Stay awake")
            active: IslandEvents.caffeineOn
            accent: IslandEvents.caffeineOn ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
            onTap: () => IslandEvents.toggleCaffeine(60)
        }
        Chip {
            icon: Notifications.silent ? "notifications_off" : "notifications_active"
            label: Notifications.silent ? Translation.tr("Do not disturb") : Translation.tr("Mute notifications")
            active: Notifications.silent
            accent: Notifications.silent ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
            onTap: () => Notifications.silent = !Notifications.silent
        }
        Chip {
            icon: "psychology"
            label: IslandEvents.focusOn ? Translation.tr("Focus · %1 min").arg(IslandEvents.focusMinutes) : Translation.tr("Focus")
            active: IslandEvents.focusOn
            accent: IslandEvents.focusOn ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
            onTap: () => IslandEvents.toggleFocus()
        }
        Chip {
            icon: "tune"
            label: Translation.tr("Island settings")
            onTap: () => {
                xi.di.collapse()
                GlobalStates.settingsPage = "Bar"
                GlobalStates.settingsOpen = true
            }
        }
    }
}
