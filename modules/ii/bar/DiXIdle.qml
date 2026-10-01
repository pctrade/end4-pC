import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Home view: clock, weather and toggles on the left, everything active on the right, shortcuts below.
ColumnLayout {
    id: xi
    required property Item di
    spacing: 10
    implicitWidth: xi.wantedWidth
    readonly property real wantedWidth: 532

    Component.onCompleted: Weather.requestForecast()

    function humanCountdown(seconds) {
        if (seconds <= 0) return ""
        const d = Math.floor(seconds / 86400)
        const h = Math.floor(seconds % 86400 / 3600)
        const m = Math.floor(seconds % 3600 / 60)
        if (d > 0) return `${d}d ${h}h`
        if (h > 0) return `${h}h ${String(m).padStart(2, "0")}min`
        return `${m}min`
    }

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

    readonly property var nowIds: {
        const ids = xi.di.persistentIds.filter(id => !["idle", "media"].includes(id))
        if (WatchRating.active && WatchRating.playing && !ids.includes("watchRating")) ids.push("watchRating")
        if (F1.enabled && !ids.includes("f1") && F1.nextSession !== null && F1.secondsToNext > 0 && F1.secondsToNext < 3 * 86400)
            ids.push("f1")
        return ids
    }

    // One list for the right column: { kind: "media" | "live" | "f1Next" | "silenced", id }
    readonly property var nowRows: {
        const rows = []
        if (xi.di.hasMedia) rows.push({ kind: "media", id: "media" })
        for (const id of xi.nowIds) rows.push({ kind: "live", id: id })
        if (F1.enabled && !xi.nowIds.includes("f1") && F1.nextSession !== null && F1.secondsToNext > 0)
            rows.push({ kind: "f1Next", id: "f1" })
        for (const id of IslandEvents.silencedIslands) rows.push({ kind: "silenced", id: id })
        return rows
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component Toggle: Rectangle {
        id: toggle
        property string icon
        property string label
        property bool active: false
        property var onTap: null
        property int order: 0
        implicitWidth: toggleRow.implicitWidth + 20
        implicitHeight: 32
        radius: 16
        color: toggle.active ? Appearance.colors.colPrimaryContainer
            : (toggleMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)

        Behavior on color {
            ColorAnimation { duration: IslandMotion.short }
        }

        RowLayout {
            id: toggleRow
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: toggle.icon
                iconSize: 16
                fill: toggle.active ? 1 : 0
                color: toggle.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                text: toggle.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: toggle.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
            }
        }

        DiCascade { target: toggle; index: toggle.order; pressed: toggleMouse.pressed }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (toggle.onTap) toggle.onTap()
        }
    }

    component Shortcut: ColumnLayout {
        id: shortcut
        property string icon
        property string label
        property var onTap: null
        property int order: 0
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 3
        DiCascade { target: shortcut; index: shortcut.order; step: 25 }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 12
            color: shortcutMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
            scale: shortcutMouse.pressed ? 0.95 : 1

            Behavior on color {
                ColorAnimation { duration: IslandMotion.micro }
            }
            Behavior on scale {
                NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutBack }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: shortcut.icon
                iconSize: 19
                fill: 1
                color: Appearance.colors.colOnLayer1
            }

            MouseArea {
                id: shortcutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (shortcut.onTap) shortcut.onTap()
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: shortcut.label
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: shortcutMouse.containsMouse ? 0.9 : 0.6
            Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 272
            Layout.maximumWidth: 272
            Layout.alignment: Qt.AlignTop
            spacing: 0

            StyledText {
                id: clock
                Layout.topMargin: -4
                text: DateTime.time
                font.family: xi.displayFont
                font.pixelSize: 48
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                DiCascade { target: clock; index: 0 }
            }

            Item {
                id: dateRow
                Layout.topMargin: -2
                implicitWidth: dateContent.implicitWidth
                implicitHeight: dateContent.implicitHeight
                DiCascade { target: dateRow; index: 1 }

                RowLayout {
                    id: dateContent
                    spacing: 2

                    StyledText {
                        text: DateTime.clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat).replace(/,?\s*(de\s)?\d{4}$/, "")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        opacity: dateArea.containsMouse ? 0.95 : 0.7
                        Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
                    }
                    MaterialSymbol {
                        text: "chevron_right"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer0
                        opacity: dateArea.containsMouse ? 0.8 : 0.35
                        Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
                    }
                }

                MouseArea {
                    id: dateArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xi.di.expand("calendar")
                }
            }

            Rectangle {
                id: weatherCard
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: (Weather.data?.temp ?? "") !== ""
                implicitHeight: 50
                radius: 14
                color: weatherMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                DiCascade { target: weatherCard; index: 2 }

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 8
                    }
                    spacing: 6

                    MaterialSymbol {
                        text: IslandEvents.weatherSymbol(Weather.data?.wCode ?? 800, Weather.data?.night)
                        iconSize: 26
                        fill: 1
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: `${parseInt(Weather.data?.temp ?? "0") || 0}°`
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                    }
                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: Math.min(4, (Weather.forecast ?? []).length)

                        ColumnLayout {
                            id: nextHour
                            required property int index
                            readonly property var step: Weather.forecast[nextHour.index] ?? ({})
                            Layout.preferredWidth: 38
                            spacing: 0
                            DiCascade { target: nextHour; index: 3 + nextHour.index; delay: 120 }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.locale().toString(new Date((nextHour.step.dt ?? 0) * 1000), DateTime.use12HourFormat ? "h AP" : "HH'h'")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.55
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 1
                                MaterialSymbol {
                                    text: IslandEvents.weatherSymbol(nextHour.step.wCode, nextHour.step.night)
                                    iconSize: 14
                                    fill: 1
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.8
                                }
                                StyledText {
                                    text: `${nextHour.step.temp ?? ""}°`
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: weatherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xi.di.expand("weather")
                }
            }

            RowLayout {
                id: toggles
                Layout.topMargin: 8
                spacing: 6

                Toggle {
                    order: 4
                    icon: Notifications.silent ? "notifications_off" : "notifications"
                    label: Translation.tr("Do not disturb")
                    active: Notifications.silent
                    onTap: () => Notifications.silent = !Notifications.silent
                }
                Toggle {
                    order: 5
                    icon: "local_cafe"
                    label: IslandEvents.caffeineOn && IslandEvents.caffeineMinutesLeft >= 0
                        ? `${IslandEvents.caffeineMinutesLeft} min` : Translation.tr("Caffeine")
                    active: IslandEvents.caffeineOn
                    onTap: () => IslandEvents.toggleCaffeine(60)
                }
                Toggle {
                    order: 6
                    icon: "psychology"
                    label: IslandEvents.focusOn ? `${IslandEvents.focusMinutes} min` : Translation.tr("Focus")
                    active: IslandEvents.focusOn
                    onTap: () => IslandEvents.toggleFocus()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                id: nowHeader
                Layout.fillWidth: true
                DiCascade { target: nowHeader; index: 0 }

                SectionLabel {
                    Layout.fillWidth: true
                    text: Translation.tr("Now")
                }
                SectionLabel {
                    visible: xi.nowRows.length > 0
                    text: xi.nowRows.length
                    font.features: { "tnum": 1 }
                    opacity: 0.4
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    id: emptyState
                    anchors.centerIn: parent
                    visible: xi.nowRows.length === 0
                    spacing: 2
                    DiCascade { target: emptyState; index: 2 }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "self_improvement"
                        iconSize: 30
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.35
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("All quiet")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Nothing running right now")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.45
                    }
                }

                Flickable {
                    id: nowList
                    anchors.fill: parent
                    clip: true
                    contentHeight: nowColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: nowList.contentHeight > nowList.height

                    ColumnLayout {
                        id: nowColumn
                        width: nowList.width
                        spacing: 4

                        Repeater {
                            model: xi.nowRows

                            delegate: Rectangle {
                                id: nowRow
                                required property var modelData
                                required property int index
                                readonly property string kind: nowRow.modelData.kind
                                readonly property string rowId: nowRow.modelData.id
                                readonly property bool agentMark: nowRow.kind === "live"
                                    && ["claude", "codex", "gemini"].includes(xi.di.iconForId(nowRow.rowId))
                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: 12
                                color: nowMouse.containsMouse ? Appearance.colors.colLayer2
                                    : nowRow.kind === "media" ? ColorUtils.mix(Appearance.colors.colLayer1, xi.di.mediaArtColor, 0.82)
                                    : Appearance.colors.colLayer1
                                DiCascade { target: nowRow; index: nowRow.index + 1 }

                                Behavior on color {
                                    ColorAnimation { duration: IslandMotion.micro }
                                }

                                Loader {
                                    id: capsule
                                    active: nowRow.kind === "live"
                                    visible: false
                                    sourceComponent: DiCapsule {
                                        di: xi.di
                                        providerId: nowRow.rowId
                                    }
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: nowRow.kind === "media" ? 5 : 10
                                        rightMargin: 8
                                    }
                                    spacing: 9

                                    Item {
                                        implicitWidth: nowRow.kind === "media" ? 28 : 20
                                        implicitHeight: implicitWidth

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: nowRow.kind === "media"
                                            radius: 8
                                            clip: true
                                            color: Appearance.colors.colLayer2

                                            StyledImage {
                                                anchors.fill: parent
                                                source: nowRow.kind === "media" ? (xi.di.activePlayer?.trackArtUrl ?? "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize.width: 56
                                                sourceSize.height: 56
                                            }
                                        }
                                        DiClaudeIcon {
                                            anchors.centerIn: parent
                                            visible: nowRow.agentMark
                                            agent: nowRow.agentMark ? xi.di.iconForId(nowRow.rowId) : "claude"
                                            size: 16
                                        }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: nowRow.kind !== "media" && !nowRow.agentMark
                                            text: nowRow.kind === "silenced" ? "notifications_paused"
                                                : nowRow.kind === "f1Next" ? "sports_motorsports"
                                                : xi.di.iconForId(nowRow.rowId)
                                            iconSize: 17
                                            fill: 1
                                            color: nowRow.kind === "silenced" ? IslandEvents.colorAttention
                                                : (capsule.item?.accent ?? Appearance.colors.colOnLayer1)
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: {
                                            switch (nowRow.kind) {
                                                case "media": return xi.di.activePlayer?.trackTitle ?? ""
                                                case "f1Next": return `F1 · ${F1.nextSession?.name ?? ""}`
                                                case "silenced": return xi.pinLabels[nowRow.rowId]?.[0] ?? xi.di.nameForId(nowRow.rowId)
                                                default: return xi.di.longNameForId(nowRow.rowId)
                                            }
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        id: rowValue
                                        Layout.maximumWidth: 110
                                        visible: text !== "" && text !== xi.di.longNameForId(nowRow.rowId)
                                        text: {
                                            switch (nowRow.kind) {
                                                case "media": return xi.di.activePlayer?.trackArtist ?? ""
                                                case "f1Next": return xi.humanCountdown(F1.secondsToNext)
                                                case "silenced": return Translation.tr("bring back")
                                                default: return nowRow.rowId === "f1" && !F1.sessionLive
                                                    ? xi.humanCountdown(F1.secondsToNext) : (capsule.item?.label ?? "")
                                            }
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.features: { "tnum": 1 }
                                        color: nowRow.kind === "silenced" ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
                                        opacity: nowRow.kind === "silenced" ? 1 : 0.65
                                        elide: Text.ElideRight
                                    }

                                    MaterialSymbol {
                                        text: nowRow.kind !== "media" ? "chevron_right"
                                            : (xi.di.activePlayer?.isPlaying ? "pause" : "play_arrow")
                                        iconSize: nowRow.kind === "media" ? 20 : 16
                                        fill: 1
                                        color: Appearance.colors.colOnLayer1
                                        opacity: nowRow.kind === "media" ? 0.9 : (nowMouse.containsMouse ? 0.8 : 0.35)
                                        Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            enabled: nowRow.kind === "media"
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: xi.di.activePlayer?.togglePlaying()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nowMouse
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        switch (nowRow.kind) {
                                            case "silenced":
                                                IslandEvents.restoreIsland(nowRow.rowId)
                                                return
                                            case "media":
                                            case "f1Next":
                                                xi.di.expand(nowRow.rowId)
                                                return
                                        }
                                        if (xi.di.hasDetails(nowRow.rowId)) {
                                            xi.di.expand(nowRow.rowId)
                                            return
                                        }
                                        xi.di.focusIsland(nowRow.rowId)
                                        xi.di.collapse()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: shortcuts
        Layout.fillWidth: true
        spacing: 6

        Shortcut {
            order: 6
            icon: "apps"
            label: Translation.tr("Overview")
            onTap: () => xi.di.expand("overview")
        }
        Shortcut {
            order: 7
            icon: "inventory_2"
            label: Translation.tr("Drawer")
            onTap: () => xi.di.expand("shelf")
        }
        Shortcut {
            order: 8
            icon: "content_paste"
            label: Translation.tr("Clips")
            onTap: () => xi.di.expand("clipboard")
        }
        Shortcut {
            order: 9
            icon: "smart_toy"
            label: Translation.tr("Agents")
            onTap: () => xi.di.expand("agents")
        }
        Shortcut {
            order: 10
            icon: "monitoring"
            label: Translation.tr("System")
            onTap: () => xi.di.expand("system")
        }
        Shortcut {
            order: 11
            icon: "history"
            label: Translation.tr("History")
            onTap: () => xi.di.expand("history")
        }
        Shortcut {
            visible: IslandEvents.ztAvailable
            order: 12
            icon: "vpn_lock"
            label: "ZeroTier"
            onTap: () => xi.di.expand("zerotier")
        }
        Shortcut {
            order: 13
            icon: "tune"
            label: Translation.tr("Tweaks")
            onTap: () => {
                xi.di.collapse()
                GlobalStates.openSettingsAt("bar")
            }
        }
    }
}
