import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property bool mirrored: false

    readonly property var cfg: Config.options.bar.dynamicIsland
    readonly property real pillHeight: 32
    // The gap between the pill and a detached capsule. It has to clear pillHeight / 3.6 (~9px) or the
    // "droplet" connector below never fully thins to nothing, leaving the capsule looking glued to the pill.
    readonly property real capsuleGap: 11
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool vertical: Config.options.bar.vertical

    readonly property color surfaceColor: Config.options.bar.followFrameColor
        ? Appearance.getColorFromName(Config.options.bar.frameColor)
        : Appearance.colors.colLayer0
    readonly property color pillColor: root.isMaterial || (GlobalStates.barCenterOnly && Config.options.bar.cornerStyle === 0)
        ? "transparent" : root.surfaceColor
    readonly property color capsuleColor: root.isMaterial ? Appearance.colors.colLayer1 : root.surfaceColor

    // BarContent instantiates the middle layout twice (material + classic); only the visible island may react
    readonly property bool onFocusedScreen: root.visible && (root.QsWindow.window?.screen?.name ?? "") === (Hyprland.focusedMonitor?.name ?? "")

    // Media
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: root.activePlayer !== null
        && ((root.activePlayer.trackTitle ?? "") !== "" || root.activePlayer.isPlaying)
        && root.mediaIsMusic

    // Videos playing in a browser (YouTube, etc.) aren't worth an island; music players and music sites are
    readonly property bool mediaIsMusic: {
        const player = root.activePlayer
        if (!player) return false
        const source = `${player.dbusName ?? ""} ${player.identity ?? ""} ${player.desktopEntry ?? ""}`.toLowerCase()
        if (!/chrom|firefox|zen|brave|vivaldi|opera|edge|plasma-browser|epiphany/.test(source)) return true
        const url = String(player.metadata?.["xesam:url"] ?? "")
        return /music\.youtube\.com|open\.spotify\.com|soundcloud\.com|deezer\.com|tidal\.com|music\.apple\.com/.test(url)
    }
    property real mediaTextContentWidth: 0
    property real idleTextContentWidth: 0
    property real notifContentWidth: 0
    readonly property string lyricLine: (root.cfg.lyrics ?? true) && LyricsService.status === "ok"
        && LyricsService.activeIndex >= 0 && (root.activePlayer?.isPlaying ?? false)
        ? (LyricsService.slots[LyricsService.before] ?? "") : ""
    readonly property bool mediaTrackInfoVisible: root.hoverRevealed || mediaTrackChangeTimer.running
    readonly property real mediaWidth: root.mediaTrackInfoVisible
        ? Math.max(140, Math.min(260, root.mediaTextContentWidth))
        : (root.lyricLine !== "" ? 250 : 140)

    Timer {
        id: mediaTrackChangeTimer
        interval: 3000
    }

    // MPRIS position isn't pushed; poll while playing
    Timer {
        interval: 1000
        repeat: true
        running: root.activePlayer?.isPlaying ?? false
        onTriggered: root.activePlayer?.positionChanged()
    }

    readonly property string mediaArtUrl: root.activePlayer?.trackArtUrl ?? ""
    readonly property string mediaArtPath: root.mediaArtUrl.startsWith("file://")
        ? decodeURIComponent(root.mediaArtUrl.slice(7))
        : `${Directories.coverArt}/${Qt.md5(root.mediaArtUrl)}`
    property bool mediaArtReady: false
    readonly property color mediaArtColor: (root.cfg.albumColors ?? true) && root.mediaArtReady && artQuantizer.colors.length > 0
        ? artQuantizer.colors[0] : Appearance.colors.colPrimary

    onMediaArtUrlChanged: {
        root.mediaArtReady = false
        if (root.mediaArtUrl === "") return
        if (root.mediaArtUrl.startsWith("file://")) {
            root.mediaArtReady = true
            return
        }
        artDownloader.running = false
        artDownloader.command = ["bash", "-c", `mkdir -p '${Directories.coverArt}' && ([ -f '${root.mediaArtPath}' ] || curl -4 -sSL '${root.mediaArtUrl}' -o '${root.mediaArtPath}')`]
        artDownloader.running = true
    }

    Process {
        id: artDownloader
        onExited: (exitCode, exitStatus) => root.mediaArtReady = exitCode === 0
    }

    ColorQuantizer {
        id: artQuantizer
        source: root.mediaArtReady ? `file://${root.mediaArtPath}` : ""
        depth: 0
        rescaleSize: 1
    }

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() { mediaTrackChangeTimer.restart() }
        function onTrackArtistChanged() { mediaTrackChangeTimer.restart() }
    }

    // Notifications
    readonly property var visibleNotifications: Notifications.popupList.filter(n => !IslandEvents.isMuted(n))
    // Loads the Claude Code service (its IPC target) with the island
    readonly property int claudeSessionCount: ClaudeCode.openCount
    readonly property var latestNotification: root.visibleNotifications.length > 0
        ? root.visibleNotifications[root.visibleNotifications.length - 1]
        : null
    readonly property bool latestNotificationCritical: (root.latestNotification?.urgency ?? "").toLowerCase() === "critical"

    Connections {
        target: Notifications
        function onNotify(notif) {
            if (Notifications.popupInhibited || IslandEvents.isMuted(notif)) return
            // Critical ones always; otherwise only apps with priority (WhatsApp by default)
            if ((notif.urgency ?? "").toLowerCase() === "critical"
                    || (notif.image !== "" && IslandEvents.isPriorityNotification(notif))) root.peek()
        }
    }

    // Recording
    readonly property bool isRecording: Persistent.states.record.enable || root.fakeRecording

    // ilha-teste helpers
    property bool fakeRecording: false
    property string simFlagRestore: "1"

    Timer {
        id: fakeRecordingTimer
        interval: 20000
        onTriggered: root.fakeRecording = false
    }

    Timer {
        id: simOsdTimer
        interval: 2500
        onTriggered: GlobalStates.osdVolumeOpen = false
    }

    Timer {
        id: simFlagTimer
        interval: 6500
        onTriggered: F1.flagOverride = ""
    }

    // Live offset while a swipe is in progress, so the content follows the fingers
    property real swipeOffsetX: 0
    property real swipeOffsetY: 0

    Behavior on swipeOffsetX {
        enabled: !root.swipeTracking
        NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    Behavior on swipeOffsetY {
        enabled: !root.swipeTracking
        NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    property bool swipeTracking: false
    property int recordingElapsedSeconds: 0
    onIsRecordingChanged: if (!isRecording) recordingElapsedSeconds = 0

    function formatRecordingTime(s) {
        return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRecording
        onTriggered: root.recordingElapsedSeconds++
    }

    // Timers
    property string engagedTimerKind: ""
    readonly property bool hasActiveTimer: root.engagedTimerKind !== ""

    Connections {
        target: TimerService
        function onPomodoroRunningChanged() { if (TimerService.pomodoroRunning) root.engagedTimerKind = "pomodoro" }
        function onCountdownRunningChanged() { if (TimerService.countdownRunning) root.engagedTimerKind = "countdown" }
        function onStopwatchRunningChanged() { if (TimerService.stopwatchRunning) root.engagedTimerKind = "stopwatch" }
    }

    function timerIcon() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroBreak ? "coffee" : "visibility"
            case "countdown": return "hourglass_top"
            default:          return "timer"
        }
    }

    function timerValueText() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            case "countdown": return TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            case "stopwatch": return TimerService.formatSeconds(Math.floor(TimerService.stopwatchTime / 100))
            default:          return ""
        }
    }

    function timerSecondsLeft() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroSecondsLeft
            case "countdown": return TimerService.countdownSecondsLeft
            default:          return -1
        }
    }

    // 0..1 remaining fraction; stopwatch loops every minute
    function timerProgress() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroLapDuration > 0 ? TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration : 0
            case "countdown": return TimerService.countdownDuration > 0 ? TimerService.countdownSecondsLeft / TimerService.countdownDuration : 0
            case "stopwatch": return ((TimerService.stopwatchTime / 100) % 60) / 60
            default:          return 0
        }
    }

    function timerRunning() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroRunning
            case "countdown": return TimerService.countdownRunning
            case "stopwatch": return TimerService.stopwatchRunning
            default:          return false
        }
    }

    function toggleActiveTimer() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  TimerService.togglePomodoro(); break
            case "countdown": TimerService.toggleCountdown(); break
            case "stopwatch": TimerService.toggleStopwatch(); break
        }
    }

    function resetActiveTimer() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  TimerService.resetPomodoro(); break
            case "countdown": TimerService.resetCountdown(); break
            case "stopwatch": TimerService.stopwatchReset(); break
        }
        root.engagedTimerKind = ""
    }

    // Battery
    property bool batteryAlertActive: false
    property string batteryAlertKind: ""
    property real lastBatteryPercentage: Battery.percentage

    Timer {
        id: batteryAlertTimer
        interval: 4000
        onTriggered: root.batteryAlertActive = false
    }

    function triggerBatteryAlert(kind) {
        root.batteryAlertKind = kind
        root.batteryAlertActive = true
        batteryAlertTimer.interval = kind === "critical" ? 12000 : kind === "low" ? 7000 : 4500
        batteryAlertTimer.restart()
    }

    // Automatic hibernation countdown (Battery service); ilha-teste fakes one without hibernating
    property int simHibernate: -1
    readonly property int hibernateSeconds: root.simHibernate >= 0 ? root.simHibernate : (Battery.hibernateCountdown ?? -1)

    Timer {
        interval: 1000
        repeat: true
        running: root.simHibernate > 0
        onTriggered: {
            root.simHibernate--
            if (root.simHibernate === 0) root.simHibernate = -1
        }
    }

    function cancelHibernate() {
        root.simHibernate = -1
        Battery.cancelHibernate()
    }

    Connections {
        target: Battery
        function onIsCriticalAndNotChargingChanged() {
            if (Battery.isCriticalAndNotCharging) root.triggerBatteryAlert("critical")
        }
        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging && !Battery.isCriticalAndNotCharging) root.triggerBatteryAlert("low")
        }
        // Stopping at 80% saves battery wear; nudge when charging crosses it
        function onPercentageChanged() {
            const percentage = Battery.percentage
            if (Battery.isCharging && root.lastBatteryPercentage < 0.8 && percentage >= 0.8) root.triggerBatteryAlert("eighty")
            root.lastBatteryPercentage = percentage
        }
        function onIsPluggedInChanged() {
            if (Battery.isPluggedIn) root.triggerBatteryAlert("charging")
        }
    }

    function formatDuration(seconds) {
        const minutes = Math.max(1, Math.round(seconds / 60))
        if (minutes < 60) return `${minutes} min`
        return `${Math.floor(minutes / 60)}h ${(minutes % 60).toString().padStart(2, "0")}`
    }

    function batteryStatusText() {
        switch (root.batteryAlertKind) {
            case "critical": return Translation.tr("Critical Battery")
            case "eighty":   return Translation.tr("80% · you can unplug")
            case "charging":
                return Battery.timeToFull > 60 ? `${Translation.tr("Full in")} ${root.formatDuration(Battery.timeToFull)}` : Translation.tr("Charging")
            default:         return Translation.tr("Low Battery")
        }
    }

    function batteryIcon() {
        if (root.batteryAlertKind === "charging" || Battery.isCharging) return "battery_android_frame_bolt"
        const pct = Battery.percentage
        if (pct <= 0.1) return "battery_android_frame_alert"
        if (pct <= 0.2) return "battery_android_frame_1"
        if (pct <= 0.4) return "battery_android_frame_2"
        if (pct <= 0.6) return "battery_android_frame_3"
        if (pct <= 0.8) return "battery_android_frame_4"
        if (pct < 1)    return "battery_android_frame_5"
        return "battery_android_full"
    }

    function batteryAlertColor() {
        return ["charging", "eighty"].includes(root.batteryAlertKind) ? Appearance.m3colors.m3success : Appearance.colors.colError
    }

    // F1 moments
    property bool f1StartActive: false
    property bool f1FlagFlashActive: false

    Timer {
        id: f1StartTimer
        interval: 5600
        onTriggered: root.f1StartActive = false
    }

    Timer {
        id: f1FlagTimer
        interval: 6000
        onTriggered: root.f1FlagFlashActive = false
    }

    // Race weekend moments: pit stops of the focused driver, rain at the track, session result
    property var f1Event: ({})
    property bool f1EventActive: false

    Timer {
        id: f1EventTimer
        interval: 7000
        onTriggered: root.f1EventActive = false
    }

    function showF1Event(payload) {
        root.f1Event = payload
        root.f1EventActive = true
        f1EventTimer.interval = payload.kind === "radio" ? 12000 : 7000
        f1EventTimer.restart()
        root.peek(5000)
    }

    Connections {
        target: F1
        function onTyreChange(driver) {
            root.showF1Event({
                kind: "tyre", letter: F1.tyreLetter(driver.tyre), color: F1.tyreColor(driver.tyre),
                title: `${driver.tla} ${Translation.tr("pitted")} · P${driver.position}`,
                subtitle: `${Translation.tr("Tyre")} ${F1.tyreName(driver.tyre)} ${driver.tyreNew ? Translation.tr("(new)") : Translation.tr("(used)")}`
            })
        }
        function onTeamRadioMessage(radio) {
            const driver = F1.drivers.find(d => d.tla === radio.tla)
            root.showF1Event({
                kind: "radio", icon: "radio", color: driver?.color ?? "#FF1E00", url: radio.url,
                title: `${Translation.tr("Team radio")} · ${radio.tla}`,
                subtitle: driver ? `P${driver.position} · ${Translation.tr("Tap to listen")}` : Translation.tr("Tap to listen")
            })
            if (F1.autoPlayRadio && !F1.radioPlaying) F1.playRadio(radio.url)
        }
        function onRainStarted() {
            root.showF1Event({
                kind: "rain", icon: "rainy", color: "#4FC3F7",
                title: `${Translation.tr("Rain at")} ${F1.session?.circuit || F1.session?.meeting || ""}`,
                subtitle: `${Translation.tr("Track")} ${F1.weather?.track ?? "?"}°C · ${Translation.tr("Air")} ${F1.weather?.air ?? "?"}°C`
            })
        }
        function onSessionResult(podium) {
            const focus = F1.focusDriver
            const qualifying = /qualifying|shootout/i.test(`${F1.session?.type ?? ""} ${F1.session?.name ?? ""}`)
            if (qualifying) {
                const grid = F1.drivers.slice(0, 5).map(d => d.tla).join(" · ")
                root.showF1Event({
                    kind: "result", icon: "grid_on", color: "#FFD54F",
                    title: `${Translation.tr("Pole")}: ${podium[0]?.tla ?? ""}${podium[0]?.best ? ` · ${podium[0].best}` : ""}`,
                    subtitle: `${Translation.tr("Grid")}: ${grid}${focus && focus.position > 5 ? ` · ${focus.tla} P${focus.position}` : ""}`
                })
                return
            }
            root.showF1Event({
                kind: "result", icon: "emoji_events", color: "#FFD54F",
                title: `${F1.session?.name ?? ""}: ${podium.map(d => d.tla).join(" · ")}`,
                subtitle: focus ? `${focus.tla} P${focus.position}` : ""
            })
        }
        function onFastestLap(driver, time) {
            root.showF1Event({
                kind: "fastest", icon: "timer", color: "#B138DD",
                title: `${Translation.tr("Fastest lap")} · ${driver.tla}`,
                subtitle: `${time} · P${driver.position}`
            })
        }
        function onBlueFlag(driver) {
            root.showF1Event({
                kind: "blue", icon: "flag", color: "#2979FF",
                title: `${Translation.tr("Blue flag")} · ${driver.tla}`,
                subtitle: Translation.tr("Let the faster car through")
            })
        }
        function onLapsToGo(laps) {
            const focus = F1.focusDriver
            root.showF1Event({
                kind: "laps", icon: laps === 0 ? "sports_score" : "flag_circle", color: laps === 0 ? "#FFFFFF" : Appearance.colors.colPrimary,
                title: laps === 0 ? Translation.tr("Final lap") : Translation.tr("%1 laps to go").arg(laps),
                subtitle: focus ? `${focus.tla} P${focus.position}${focus.interval ? ` · ${focus.interval}` : ""}` : ""
            })
        }
    }

    Connections {
        target: F1
        function onLightsOut() {
            root.f1StartActive = true
            f1StartTimer.restart()
        }
        function onFlagEvent(flag) {
            root.f1FlagFlashActive = true
            f1FlagTimer.interval = flag === "green" ? 3000 : 6000
            f1FlagTimer.restart()
            if (flag !== "green" && (root.cfg.f1.autoExpandFlags ?? true)) root.peek(5000)
        }
    }

    Connections {
        target: IslandEvents
        function onActivityFinished(activity) { root.peek(3500) }
        function onActivityNeedsAttention(activity) { root.peek(6000) }
        function onExpandRequested() { if (root.onFocusedScreen) root.toggleExpanded() }
        function onLevelRequested(level) {
            if (!root.onFocusedScreen) return
            if (level <= 0) root.collapse()
            else root.expandTo(level)
        }
        function onCycleRequested(direction) {
            if (root.onFocusedScreen) root.cycleIsland(direction)
        }
        function onPinnedCycleRequested(direction) {
            if (root.onFocusedScreen) root.cyclePinned(direction)
        }
        function onPinToggleRequested() {
            if (root.onFocusedScreen) root.togglePin()
        }
        function onViewRequested(view) {
            if (root.onFocusedScreen) root.expandTo(2, view)
        }
        function onScrollRequested(direction) {
            if (root.onFocusedScreen) root.scrollVertical(direction)
        }
        function onHomeRequested() {
            if (root.onFocusedScreen) root.goHome()
        }
        function onDismissRequested() {
            if (root.onFocusedScreen) root.dismissCurrent()
        }
        function onSilenceRequested() {
            if (root.onFocusedScreen) root.silenceIsland(root.primaryId)
        }
        function onSimulateRequested(name) {
            if (!root.onFocusedScreen) return
            switch (name) {
                case "batteryLow": root.triggerBatteryAlert("low"); break
                case "batteryCritical": root.triggerBatteryAlert("critical"); break
                case "charging": root.triggerBatteryAlert("charging"); break
                case "recording":
                    root.fakeRecording = !root.fakeRecording
                    if (root.fakeRecording) fakeRecordingTimer.restart()
                    break
                case "osd":
                    GlobalStates.osdIndicatorType = "volume"
                    GlobalStates.osdVolumeOpen = true
                    simOsdTimer.restart()
                    break
                case "lights":
                    root.f1StartActive = true
                    f1StartTimer.restart()
                    break
                case "flag":
                    F1.flagOverride = "yellow"
                    root.f1FlagFlashActive = true
                    f1FlagTimer.interval = 6000
                    f1FlagTimer.restart()
                    simFlagTimer.restart()
                    break
                case "f1Tyre":
                    root.showF1Event({ kind: "tyre", letter: "H", color: F1.tyreColor("HARD"),
                        title: `VER ${Translation.tr("pitted")} · P4`, subtitle: `${Translation.tr("Tyre")} ${F1.tyreName("HARD")} ${Translation.tr("(new)")}` })
                    break
                case "f1Rain":
                    root.showF1Event({ kind: "rain", icon: "rainy", color: "#4FC3F7",
                        title: `${Translation.tr("Rain at")} Baku`, subtitle: `${Translation.tr("Track")} 31°C · ${Translation.tr("Air")} 24°C` })
                    break
                case "f1Result":
                    root.showF1Event({ kind: "result", icon: "emoji_events", color: "#FFD54F",
                        title: "Qualifying: NOR · VER · LEC", subtitle: "VER P2" })
                    break
                // The new race moments go through F1's own signals, so the real handlers are what gets tested
                case "f1Fastest":
                    F1.fastestLap({ tla: "VER", position: 1, best: "1:12.345", color: "#3671C6" }, "1:12.345")
                    break
                case "f1Blue":
                    F1.blueFlag({ tla: "SAR", position: 19, color: "#64C4FF" })
                    break
                case "f1Laps":
                    F1.lapsToGo(10)
                    break
                case "f1Final":
                    F1.lapsToGo(0)
                    break
                case "f1Radio":
                    F1.teamRadioMessage({ tla: F1.focusDriver?.tla ?? "VER", url: "" })
                    break
                case "f1Pole":
                    root.showF1Event({ kind: "result", icon: "grid_on", color: "#FFD54F",
                        title: `${Translation.tr("Pole")}: VER · 1:10.270`, subtitle: `${Translation.tr("Grid")}: VER · NOR · LEC · PIA · RUS` })
                    break
                case "eighty":
                    root.triggerBatteryAlert("eighty")
                    break
                case "hibernate":
                    root.simHibernate = 60
                    break
            }
        }
    }

    Connections {
        target: IslandEvents.screenshot
        function onActiveChanged() { if (IslandEvents.screenshot.active) root.peek(4000) }
    }

    // Drawer: anything dropped on the island is kept in DropShelf until removed
    property bool dropHovering: false
    property bool shelfAddedFlash: false
    property var lastShelfAdded: []

    Timer {
        id: shelfAddedTimer
        interval: 3500
        onTriggered: root.shelfAddedFlash = false
    }

    Connections {
        target: DropShelf
        function onItemsAdded(paths) {
            if (!root.visible) return
            root.lastShelfAdded = paths
            root.shelfAddedFlash = true
            shelfAddedTimer.restart()
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.vertical
        onEntered: drag => {
            drag.accept(Qt.CopyAction)
            root.dropHovering = true
        }
        onExited: root.dropHovering = false
        onDropped: drop => {
            root.dropHovering = false
            if (drop.hasUrls && drop.urls.length > 0) DropShelf.addItems(drop.urls)
            else if (drop.hasText) DropShelf.addText(drop.text)
            drop.accept(Qt.CopyAction)
        }
    }

    // Providers: interrupts are short-lived and take the pill; persistent ones share it via split capsules
    readonly property var interruptIds: ["session", "f1Start", "osd", "notification", "battery", "bluetooth",
        "audioOutput", "screenshot", "clipboard", "songRecResult", "weather", "f1Flag", "shelfDrop", "f1Event", "networkAlert", "hardware", "hibernate", "downloadDone"]

    // The semantic model (ILHA.md § Modelo semântico): every id above answers to one of four questions.
    // CRITICAL and PEEK are both `interruptIds` — CRITICAL is the subset that can genuinely preempt (a
    // subset of `urgentIds`/`importance()` below, and mostly state-dependent rather than a fixed id: a
    // battery only becomes critical at `batteryAlertKind === "critical"`, hardware only when its own
    // payload says `urgent`). PEEK is everything else in `interruptIds` — it flashes and gives the pill
    // back exactly as it was. LIVE is what persists and is the only thing the scroll wheel walks through
    // (`cycleIds` below). TOOL is content you asked to see; it never competes for the pill or the wheel —
    // it only opens from the Tool Dock in the expanded Home (`DiXIdle.qml`) or the switcher strip.
    readonly property var criticalIds: ["hibernate", "session"]
    readonly property var liveIds: ["recording", "f1", "timer", "activity", "systemLoad", "download", "agents", "songRec", "media"]
    readonly property var toolIds: ["weather", "shelf", "clipboard", "system", "zerotier", "history"]
    // Everything else in `interruptIds` that isn't dynamically critical (see `isCriticalNow`) is a Peek.
    readonly property var peekIds: root.interruptIds.filter(id => !root.criticalIds.includes(id))

    function isCriticalNow(id) {
        if (root.criticalIds.includes(id)) return true
        if (id === "battery" && root.batteryAlertKind === "critical") return true
        if (id === "hardware" && (IslandHardware.payload.urgent ?? false)) return true
        return false
    }

    readonly property var activeIds: {
        const ids = []
        if (root.hibernateSeconds >= 0) ids.push("hibernate")
        if (root.dropHovering || root.shelfAddedFlash) ids.push("shelfDrop")
        if (GlobalStates.diSessionOpen) ids.push("session")
        if (root.f1StartActive) ids.push("f1Start")
        if (GlobalStates.osdVolumeOpen || root.heldId === "osd") ids.push("osd")
        if (root.latestNotification !== null) ids.push("notification")
        if (root.batteryAlertActive || root.heldId === "battery") ids.push("battery")
        if (IslandEvents.bluetooth.active) ids.push("bluetooth")
        if (IslandEvents.audioOutput.active) ids.push("audioOutput")
        if (IslandEvents.screenshot.active) ids.push("screenshot")
        if (IslandEvents.clipboard.active) ids.push("clipboard")
        if (IslandEvents.songRecResult.active) ids.push("songRecResult")
        if (IslandEvents.weather.active) ids.push("weather")
        if (root.f1FlagFlashActive || root.heldId === "f1Flag") ids.push("f1Flag")
        if (root.f1EventActive || root.heldId === "f1Event") ids.push("f1Event")
        if (IslandEvents.networkAlert.active) ids.push("networkAlert")
        if (IslandEvents.downloadDone.active) ids.push("downloadDone")
        if (IslandHardware.active || root.heldId === "hardware") ids.push("hardware")
        if (root.isRecording) ids.push("recording")
        if (F1.enabled && (F1.sessionLive || F1.countdownActive)) ids.push("f1")
        if (root.hasActiveTimer) ids.push("timer")
        if (IslandEvents.activities.length > 0) ids.push("activity")
        if (IslandEvents.systemLoadActive) ids.push("systemLoad")
        if (IslandEvents.downloadActive || root.heldId === "download") ids.push("download")
        // One island per agent session, not two: while a specific task is already showing as an "activity"
        // (richer: title, subtitle, progress), the general "agents" summary would just repeat the same
        // agent's mark a second time — same fact, two Live ids competing for the pill/deck at once.
        const agentActivityShown = IslandEvents.activities.some(a => ["claude", "codex", "gemini"].includes(a.icon))
        if (ClaudeCode.openCount > 0 && (root.cfg.claudeCode ?? true) && !agentActivityShown) ids.push("agents")
        if (DropShelf.items.length > 0) ids.push("shelf")
        if (SongRec.running) ids.push("songRec")
        if (root.hasMedia) ids.push("media")
        return ids
    }

    // The state each island is showing right now. Dismissing keeps this stamp: when it changes, the island is
    // news again and comes back by itself.
    // ---------------------------------------------------------------------------------------------
    // The anchor: one fact that stays put while the islands come and go. Without it the clock only exists
    // when nothing is happening, which is exactly when you least need it. It is not always the time, though:
    // a battery about to die or a timer running out matter more, and a two-second "connected" flash does not
    // need an anchor at all.
    // The days when the date is worth more than a whisper
    readonly property bool dateIsNews: {
        const now = new Date()
        return root.justWokeUp || now.getHours() === 0 || now.getDay() === 0 || now.getDay() === 6
    }

    // For a few minutes after the machine wakes up, the date is news — you may have slept through a day change
    property bool justWokeUp: false

    Connections {
        target: IslandHardware
        function onWakeCauseChanged() {
            root.justWokeUp = true
            wokeUpTimer.restart()
        }
    }

    Timer {
        id: wokeUpTimer
        interval: 5 * 60000
        onTriggered: root.justWokeUp = false
    }

    readonly property real worstAgentLimit: {
        let worst = -1
        for (const agent of ClaudeCode.openAgents) {
            const limit = ClaudeCode.limits[agent]
            if (limit) worst = Math.max(worst, limit.five)
        }
        return worst
    }

    readonly property var anchorInfo: {
        if (Battery.available && !Battery.isCharging && Battery.percentage <= 0.15)
            return { text: `${Math.round(Battery.percentage * 100)}%`, icon: "battery_alert", tone: "error" }
        if (root.isRecording)
            return { text: root.formatRecordingTime(root.recordingElapsedSeconds), icon: "fiber_manual_record", tone: "error" }
        if (root.hasActiveTimer)
            return { text: root.timerValueText(), icon: root.timerIcon(), tone: "attention" }
        // On a call you lose track of time in a different way: the clock matters less than how long you have been talking
        if (IslandEvents.voiceCallActive)
            return { text: IslandEvents.voiceCallMinutes < 1 ? DateTime.time : `${IslandEvents.voiceCallMinutes} min`,
                icon: "call", tone: "plain" }
        // About to run out of agent budget is more urgent than the time, and only you can act on it
        if ((root.cfg.claudeCode ?? true) && root.worstAgentLimit >= 85)
            return { text: `${Math.round(root.worstAgentLimit)}%`, icon: "bolt", tone: root.worstAgentLimit >= 95 ? "error" : "attention" }
        if (IslandEvents.caffeineOn && IslandEvents.caffeineMinutesLeft >= 0)
            return { text: `${IslandEvents.caffeineMinutesLeft} min`, icon: "local_cafe", tone: "attention" }
        // A race being run: the lap is the number you keep glancing at, and the F1 island is rarely the one up
        if (F1.enabled && F1.sessionLive && F1.totalLaps > 0 && root.primaryId !== "f1")
            return { text: `L${F1.lap}/${F1.totalLaps}`, icon: "sports_motorsports", tone: "plain" }
        if (Notifications.silent)
            return { text: DateTime.time, icon: "notifications_off", tone: "attention" }
        // Right after midnight, or right after waking up, the day itself is the news — the clock is not.
        if (root.justWokeUp || new Date().getHours() === 0)
            return { text: DateTime.shortDate, icon: "calendar_month", tone: "plain" }
        return { text: DateTime.time, icon: "", tone: "plain" }
    }

    // Islands that are their own answer — a notification you are reading, a device that just connected, the
    // volume you are turning — get the whole pill. Anything that sits there for minutes shares it with the anchor.
    readonly property var anchorFreeIds: ["notification", "bluetooth", "audioOutput", "osd", "screenshot",
        "clipboard", "songRecResult", "weather", "f1Flag", "f1Start", "f1Event", "shelfDrop", "networkAlert",
        "downloadDone", "hardware", "session", "hibernate", "battery", "idle", "history"]

    readonly property bool anchorShown: !root.vertical && !root.overlayShown
        && (root.cfg.anchor ?? true)
        && !root.anchorFreeIds.includes(root.primaryId)
        && root.anchorInfo.text !== ""

    readonly property real anchorInset: root.anchorShown ? anchorRow.implicitWidth + 16 : 0

    function stampFor(id) {
        switch (id) {
            case "media":      return root.activePlayer?.trackTitle ?? ""
            case "download":   return IslandEvents.downloadFileName
            case "activity":   return `${IslandEvents.latestActivity?.id ?? ""}:${IslandEvents.latestActivity?.state ?? ""}`
            case "agents":     return ClaudeCode.liveSessions.map(s => `${s.key}:${s.state}`).join(",")
            case "notification": return `${root.latestNotification?.notificationId ?? ""}`
            case "shelf":      return `${DropShelf.items.length}`
            case "timer":      return root.timerValueText()
            case "f1":         return F1.sessionLive ? "live" : "soon"
            case "systemLoad": return "load"
            case "recording":  return "recording"
            default:           return ""
        }
    }

    // One entry point for "get this out of my way", whatever kind of island it is
    function dismissCurrent() {
        const id = root.primaryId
        if (id === "idle") {
            root.goHome()
            return
        }
        if (root.interruptIds.includes(id) || root.flashFor(id) !== null) {
            root.dismiss(id)
            return
        }
        root.dismissIsland(id)
    }

    function dismissIsland(id) {
        if (id === "" || id === "idle") return
        IslandEvents.dismissIsland(id, root.stampFor(id))
        root.dismissFeedback(id, false)
    }

    function silenceIsland(id) {
        if (id === "" || id === "idle") return
        IslandEvents.silenceIsland(id)
        root.dismissFeedback(id, true)
    }

    property string dismissFeedbackId: ""
    property bool dismissFeedbackSilenced: false

    function dismissFeedback(id, silenced) {
        root.dismissFeedbackId = id
        root.dismissFeedbackSilenced = silenced
        dismissFeedbackTimer.restart()
        root.markUserSwitch()
    }

    Timer {
        id: dismissFeedbackTimer
        interval: 1400
        onTriggered: root.dismissFeedbackId = ""
    }

    readonly property var persistentIds: root.activeIds
        .filter(id => !root.interruptIds.includes(id))
        .filter(id => !IslandEvents.isIslandHidden(id, root.stampFor(id)))
    readonly property string interruptId: root.activeIds.find(id => root.interruptIds.includes(id)) ?? ""

    property string manualFocusId: ""
    property bool forceIdle: false
    onInterruptIdChanged: if (root.interruptId !== "") Qt.callLater(() => root.forceIdle = false)

    // Pinned islands stay reachable sideways even when nothing is happening in them
    readonly property var pinnableIds: ["weather", "shelf", "clipboard", "system", "media", "f1", "agents", "download", "zerotier"]
    readonly property var pinnedIds: (root.cfg.pinned ?? []).filter(id => root.pinnableIds.includes(id))

    // What the hierarchy wants on screen right now: interrupts > your manual choice > the most important active island > main
    readonly property string rawPrimaryId: {
        if (root.interruptId !== "") return root.interruptId
        if (root.forceIdle) return "idle"
        if (root.manualFocusId !== "" && (root.persistentIds.includes(root.manualFocusId) || root.pinnedIds.includes(root.manualFocusId)))
            return root.manualFocusId
        return root.persistentIds[0] ?? "idle"
    }

    // What is actually shown: follows the hierarchy but keeps each island up for a minimum time,
    // so a new event doesn't yank away something you just started reading. Urgent ones and your own switches skip the wait.
    readonly property var urgentIds: ["hibernate", "session", "osd", "f1Start", "shelfDrop"]
    property string primaryId: "idle"
    property real primarySince: 0
    property bool userSwitch: false

    // A drag started from the island runs a nested Wayland event loop; if its source item is destroyed
    // before the drop (content swap, flash timeout, overlay closing) Qt crashes. Freeze the island meanwhile.
    property bool dragging: false
    onDraggingChanged: if (!root.dragging) Qt.callLater(root.updatePrimary)

    function minDwell(id) {
        if (id === "idle") return 0
        if (id === "notification") return IslandEvents.readingTime(root.shownNotification)
        if (root.interruptIds.includes(id)) return 2000
        return 1200
    }

    function updatePrimary() {
        if (root.dragging) return
        const next = root.rawPrimaryId
        if (next === root.primaryId) {
            dwellTimer.stop()
            return
        }
        const current = root.primaryId
        const currentAlive = root.activeIds.includes(current) || root.pinnedIds.includes(current)
        const wait = root.minDwell(current) - (Date.now() - root.primarySince)
        const urgent = root.urgentIds.includes(next) || (next === "battery" && root.batteryAlertKind === "critical")
            || (next === "hardware" && (IslandHardware.payload.urgent ?? false))
        if (currentAlive && wait > 0 && !urgent && !root.userSwitch) {
            dwellTimer.interval = wait
            dwellTimer.restart()
            return
        }
        root.primaryId = next
        root.primarySince = Date.now()
    }

    function markUserSwitch() {
        root.userSwitch = true
        Qt.callLater(() => root.userSwitch = false)
        returnHomeTimer.restart()
    }

    // Home is a place, not a state you can get stranded outside of: stop steering and the island walks back,
    // so "the main one" is always the same island in the same spot.
    Timer {
        id: returnHomeTimer
        interval: 8000
        onTriggered: {
            if (root.expanded || root.hoverArmed || root.dragging || root.overlayShown) {
                returnHomeTimer.restart()
                return
            }
            if (root.manualFocusId === "" && !root.forceIdle) return
            root.goHome()
        }
    }

    onRawPrimaryIdChanged: root.updatePrimary()

    Timer {
        id: dwellTimer
        onTriggered: root.updatePrimary()
    }

    // Notifications: always the newest, but each one stays readable for a moment before the next replaces it
    property var shownNotification: null
    property real notificationSince: 0

    function updateShownNotification() {
        const next = root.latestNotification
        if (next === root.shownNotification) return
        const wait = IslandEvents.readingTime(root.shownNotification) * 0.6 - (Date.now() - root.notificationSince)
        if (root.shownNotification && next && wait > 0 && Notifications.popupList.includes(root.shownNotification)) {
            notificationDwell.interval = wait
            notificationDwell.restart()
            return
        }
        root.shownNotification = next
        root.notificationSince = Date.now()
    }

    onLatestNotificationChanged: root.updateShownNotification()

    Timer {
        id: notificationDwell
        onTriggered: root.updateShownNotification()
    }

    readonly property var secondaryIds: (root.cfg.splitMode ?? true) && !root.vertical
        ? root.persistentIds.filter(id => id !== root.primaryId).slice(0, 2)
        : []

    function compactWidth(id) {
        return root.baseWidth(id) + (root.hoverRevealed && id === root.primaryId ? root.hoverExtra(id) : 0)
            + (id === root.primaryId ? root.anchorInset : 0)
    }

    // Room for the complementary details each island reveals on hover; 0 means it doesn't grow
    function hoverExtra(id) {
        switch (id) {
            case "idle":         return 0
            case "f1":           return F1.sessionLive ? 74 : 0
            // Room for the reply button; a message that had to be cut also gets room to scroll
            case "notification": return root.notifContentWidth > 340 ? 96 : 40
            case "activity":     return 56
            case "timer":        return 52
            case "recording":    return 70
            case "shelf":        return 110
            default:             return 0
        }
    }

    function baseWidth(id) {
        switch (id) {
            case "media":         return root.mediaWidth
            case "osd":           return 196
            case "notification":  return Math.max(200, Math.min(340, root.notifContentWidth))
            case "battery":       return 236
            case "bluetooth":     return IslandEvents.bluetooth.payload?.phase === "lowBattery" ? 270 : 240
            case "audioOutput":   return 216
            case "screenshot":    return 206
            case "clipboard":     return 226
            case "songRecResult": return 250
            case "weather":       return 196
            case "f1Flag":        return 210
            case "f1Start":       return 156
            case "recording":     return 112
            case "f1":            return F1.sessionLive ? 222 : 186
            case "timer":         return 150
            case "activity":      return 236
            case "systemLoad":    return 190
            case "system":        return 214
            case "songRec":       return 150
            case "shelf":         return 132
            case "shelfDrop":     return 236
            case "f1Event":       return 262
            case "hibernate":     return 280
            case "networkAlert":  return 300
            case "hardware":      return ["caps", "layout"].includes(IslandHardware.payload.kind) ? 214 : 300
            case "download":      return 250
            case "agents":        return 230
            case "history":       return 240
            case "zerotier":      return 210
            case "downloadDone":  return 320
            case "session":       return 164
            default:              return Math.max(144, root.idleTextContentWidth)
        }
    }

    // 0: trivial (fade), 1: notice (breath), 2: critical (shake + glow)
    function importance(id) {
        switch (id) {
            case "osd":
            case "clipboard":
            case "audioOutput":
            case "idle":         return 0
            case "battery":      return root.batteryAlertKind === "critical" ? 2 : 1
            case "hibernate":    return 2
            case "notification": return root.latestNotificationCritical ? 2 : 1
            case "f1Flag":       return F1.flag === "red" ? 2 : 1
            default:             return root.interruptIds.includes(id) ? 1 : 0
        }
    }

    readonly property int alertLevel: root.importance(root.primaryId)
    readonly property color alertColor: {
        switch (root.primaryId) {
            case "f1Flag": return F1.flagColor(F1.flag)
            default:       return Appearance.colors.colError
        }
    }

    function flashFor(id) {
        switch (id) {
            case "bluetooth":     return IslandEvents.bluetooth
            case "audioOutput":   return IslandEvents.audioOutput
            case "screenshot":    return IslandEvents.screenshot
            case "clipboard":     return IslandEvents.clipboard
            case "songRecResult": return IslandEvents.songRecResult
            case "weather":       return IslandEvents.weather
            case "networkAlert":  return IslandEvents.networkAlert
            case "downloadDone":  return IslandEvents.downloadDone
            case "hardware":      return IslandHardware
            default:              return null
        }
    }

    function dismiss(id) {
        const flash = root.flashFor(id)
        if (flash) {
            flash.dismiss()
            return
        }
        switch (id) {
            case "notification":
                if (root.latestNotification) Notifications.timeoutNotification(root.latestNotification.notificationId)
                break
            case "battery":  root.batteryAlertActive = false; break
            case "f1Flag":   root.f1FlagFlashActive = false; break
            case "f1Start":  root.f1StartActive = false; break
            case "f1Event":  root.f1EventActive = false; break
            case "hibernate": root.cancelHibernate(); break
            case "shelfDrop":
                root.shelfAddedFlash = false
                root.dropHovering = false
                break
            case "osd":      GlobalStates.osdVolumeOpen = false; break
            case "session":  GlobalStates.diSessionOpen = false; break
            default:         root.forceIdle = true
        }
    }

    // Keep an interrupt on screen while the user is looking at it
    readonly property string holdId: root.expanded ? root.expandedId : ((root.hoverRevealed || root.dragging) ? root.primaryId : "")
    property string heldId: ""
    property int heldNotificationId: -1
    onHoldIdChanged: Qt.callLater(root.syncHold)

    function syncHold() {
        if (root.holdId === root.heldId) return
        if (root.heldId !== "") root.setHold(root.heldId, false)
        root.heldId = root.holdId
        if (root.holdId !== "") root.setHold(root.holdId, true)
    }

    function setHold(id, value) {
        const flash = root.flashFor(id)
        if (flash) {
            flash.hold(value)
            return
        }
        if (id === "notification") {
            // Release has to restart the timer of the notification that was held, not of whatever is newest by then:
            // otherwise a notification arriving mid-hover leaves the old one frozen on the island forever.
            if (value) {
                if (!root.latestNotification) return
                root.heldNotificationId = root.latestNotification.notificationId
                Notifications.cancelTimeout(root.heldNotificationId)
            } else {
                const held = Notifications.list.find(n => n.notificationId === root.heldNotificationId)
                root.heldNotificationId = -1
                if (held?.timer) held.timer.restart()
                else if (held) Notifications.timeoutNotification(held.notificationId)
            }
        }
    }

    // Normal -> hover widens the island in place -> click opens the full view (only when there is one)
    property bool hoverArmed: false
    property bool forcedReveal: false
    property bool peekReveal: false
    readonly property bool hoverRevealed: !root.overlayShown && !root.vertical
        && (((root.cfg.expandOnHover ?? true) && root.hoverArmed) || root.forcedReveal || root.peekReveal)

    property int expandLevel: 0
    readonly property bool expanded: root.expandLevel >= 2
    property bool overlayShown: false
    property bool cardHovered: false
    property bool wantsKeyboard: false
    // Quick reply: the expanded notification exposes its field so the overlay can take keyboard focus
    property bool replyRequested: false
    property bool replyReady: false
    property bool replyHasText: false
    property string expandedOverride: ""

    function requestReply() {
        root.replyRequested = true
        root.wantsKeyboard = true
        root.expandTo(2)
    }
    // Views worth opening even when nothing is happening in them: the system one now holds the temperature,
    // the power profile and every peripheral battery, and the network one holds the downloads
    readonly property var standaloneViews: ["privacy", "f1", "idle", "weather", "shelf", "overview", "system", "download", "history", "audioOutput", "calendar"]
    readonly property string expandedId: root.expandedOverride !== "" ? root.expandedOverride : root.primaryId

    readonly property Item surfaceItem: {
        root.isMaterial
        let item = root.parent
        while (item) {
            if (item.objectName === "dynamicIslandSurface" && item.visible) return item
            item = item.parent
        }
        return pill
    }

    readonly property var switcherIds: {
        const ids = root.persistentIds.filter(id => root.hasDetails(id))
        // Home is an island like the others: it has a face, a name and a place in the queue, so it shows up
        // in the overview and in the switcher instead of being the invisible thing behind everything else.
        ids.push("idle")
        for (const id of root.pinnedIds) if (!ids.includes(id)) ids.push(id)
        if ((root.cfg.privacyIndicators ?? true) && IslandEvents.anyPrivacy) ids.push("privacy")
        return ids
    }

    onSwitcherIdsChanged: {
        if (root.expandedOverride !== "" && !root.switcherIds.includes(root.expandedOverride)
                && !root.standaloneViews.includes(root.expandedOverride))
            root.expandedOverride = ""
        if (root.splitId !== "" && !root.switcherIds.includes(root.splitId) && !root.standaloneViews.includes(root.splitId))
            root.splitId = ""
    }

    function hasDetails(id) {
        if (id === "hardware") return (IslandHardware.payload.actions ?? []).length > 0
        return !["session", "f1Start", "battery", "recording", "networkAlert", "hibernate", "downloadDone"].includes(id)
    }

    function canExpand(id) {
        return root.hasDetails(id)
    }

    function expandTo(level, overrideId) {
        if (root.vertical) return
        if (level < 2) {
            root.forcedReveal = true
            return
        }
        if (overrideId !== undefined) root.expandedOverride = overrideId
        if (!root.hasDetails(root.expandedId)) {
            root.expandedOverride = ""
            return
        }
        root.peekReveal = false
        peekTimer.stop()
        root.expandLevel = 2
    }

    function expand(overrideId) {
        root.expandTo(2, overrideId ?? "")
    }

    function collapse() {
        const chosen = root.expandedOverride
        if (chosen !== "" && root.persistentIds.includes(chosen)) root.focusIsland(chosen)
        root.expandLevel = 0
        root.forcedReveal = false
        root.wantsKeyboard = false
        root.replyRequested = false
        root.expandedOverride = ""
        root.splitId = ""
        root.splitArmed = false
    }

    function toggleExpanded() {
        if (root.expanded) root.collapse()
        else root.expandTo(2)
    }

    function selectIsland(id) {
        root.expandedOverride = id === root.primaryId ? "" : id
    }

    // Split View (seção 13): two Tools/Activities side by side in the expanded surface. Never automatic —
    // only ever entered by an explicit tap (arm, then pick the second one), never by the island itself.
    property string splitId: ""
    property bool splitArmed: false

    function toggleSplitArm() {
        if (root.splitId !== "") { root.splitId = ""; return }
        root.splitArmed = !root.splitArmed
    }

    // What a pip tap does while armed: pick the split partner instead of replacing the main view
    function selectForSplit(id) {
        if (!root.splitArmed) { root.selectIsland(id); return }
        root.splitArmed = false
        if (id === root.expandedId) return
        root.splitId = id
    }

    function exitSplit() {
        root.splitId = ""
    }

    function focusIsland(id) {
        if (!root.persistentIds.includes(id) && !root.pinnedIds.includes(id)) return
        root.markUserSwitch()
        root.forceIdle = false
        root.manualFocusId = id
    }

    // Axis of the last gesture, so content slides the way the user swiped
    property string switchAxis: ""
    property int switchDirection: 1

    // Sideways used to be a second way to change island, competing with scrolling and putting the pinned ones
    // on two different paths. Now it acts *inside* whatever is on screen: skip the track, walk the clipboard.
    function cyclePinned(direction) {
        if (root.expanded || root.interruptId !== "") return
        root.switchAxis = "horizontal"
        root.switchDirection = direction
        switch (root.primaryId) {
            case "media":
                if (direction > 0) root.activePlayer?.next()
                else root.activePlayer?.previous()
                return
            case "clipboard":
                root.clipboardIndex = Math.max(0, Math.min(Math.max(0, Cliphist.entries.length - 1), root.clipboardIndex + direction))
                return
            case "system":
            case "systemLoad":
                root.systemMetric += direction
                return
            case "shelf":
                root.shelfIndex = Math.max(0, Math.min(Math.max(0, DropShelf.items.length - 1), root.shelfIndex + direction))
                return
            case "history":
                root.historyIndex = Math.max(0, Math.min(Math.max(0, IslandEvents.eventLog.length - 1), root.historyIndex + direction))
                return
            default:
                return
        }
    }

    property int shelfIndex: 0
    property int historyIndex: 0

    // Gestures. Touchpad two-finger swipes accumulate, lock to one axis and drag the content with a
    // rubber band; crossing the threshold switches once per gesture. Mouse wheels step one notch at a time.
    property real gestureDx: 0
    property real gestureDy: 0
    property string gestureAxis: ""
    property bool gestureConsumed: false
    property bool wheelCooling: false
    property real wheelAccum: 0
    readonly property real sideSwipeThreshold: 64
    readonly property real stackSwipeThreshold: 30

    function rubber(value, limit) {
        return limit * Math.tanh(value / (limit * 2.4))
    }

    function followSwipe() {
        if (root.gestureAxis === "" && Math.max(Math.abs(root.gestureDx), Math.abs(root.gestureDy)) > 6)
            root.gestureAxis = Math.abs(root.gestureDx) > Math.abs(root.gestureDy) ? "horizontal" : "vertical"
        root.swipeOffsetX = root.gestureAxis === "horizontal" ? root.rubber(root.gestureDx, 26) : 0
        root.swipeOffsetY = root.gestureAxis === "vertical" ? root.rubber(root.gestureDy, 9) : 0
    }

    function commitSwipe() {
        const axis = root.gestureAxis
        const delta = axis === "horizontal" ? root.gestureDx : root.gestureDy
        root.gestureConsumed = true
        root.swipeTracking = false
        root.swipeOffsetX = 0
        root.swipeOffsetY = 0
        if (axis === "horizontal") root.cyclePinned(delta < 0 ? 1 : -1)
        else if (axis === "vertical") root.scrollVertical(delta < 0 ? 1 : -1)
    }

    function resetSwipe() {
        root.swipeTracking = false
        root.gestureDx = 0
        root.gestureDy = 0
        root.gestureAxis = ""
        root.gestureConsumed = false
        root.swipeOffsetX = 0
        root.swipeOffsetY = 0
    }

    function handleWheel(event) {
        if (root.vertical) return
        const touchpad = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0
        if (!touchpad) {
            // One notch of the wheel is 120; a free-spinning wheel or a high-resolution one sends fractions of it.
            // Accumulate until a full notch is worth one island, so a flick doesn't skip three of them.
            if (root.wheelCooling) return
            const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) || (event.modifiers & Qt.ShiftModifier)
            const delta = horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y
            if ((delta > 0) !== (root.wheelAccum > 0)) root.wheelAccum = 0
            root.wheelAccum += delta
            wheelReset.restart()
            if (Math.abs(root.wheelAccum) < 100) return
            const direction = root.wheelAccum < 0 ? 1 : -1
            root.wheelAccum = 0
            root.wheelCooling = true
            wheelCooldown.restart()
            if (horizontal) root.cyclePinned(direction)
            else root.scrollVertical(direction)
            return
        }
        gestureIdle.restart()
        if (root.gestureConsumed) return
        root.swipeTracking = true
        root.gestureDx += event.pixelDelta.x
        root.gestureDy += event.pixelDelta.y
        root.followSwipe()
        if ((root.gestureAxis === "horizontal" && Math.abs(root.gestureDx) > root.sideSwipeThreshold)
                || (root.gestureAxis === "vertical" && Math.abs(root.gestureDy) > root.stackSwipeThreshold))
            root.commitSwipe()
    }

    function beginSwipe() {
        root.resetSwipe()
        root.swipeTracking = true
    }

    function trackSwipe(dx, dy) {
        root.gestureDx = dx
        root.gestureDy = dy
        root.followSwipe()
    }

    // Mouse drags only switch on release, so a short drag can be abandoned by letting go early
    function endSwipe() {
        const passed = (root.gestureAxis === "horizontal" && Math.abs(root.gestureDx) > 48)
            || (root.gestureAxis === "vertical" && Math.abs(root.gestureDy) > 16)
        if (passed) {
            root.gestureDy = -root.gestureDy
            root.commitSwipe()
        }
        root.resetSwipe()
    }

    // Scrolling: on active islands it moves between them; some pinned islands use it for their own content
    property int clipboardIndex: 0
    property int systemMetric: 0
    readonly property bool onPinnedView: root.pinnedIds.includes(root.primaryId)
        && root.manualFocusId === root.primaryId && !root.activeIds.includes(root.primaryId)

    function scrollVertical(direction) {
        root.cycleIsland(direction)
    }

    function goHome() {
        root.markUserSwitch()
        root.switchAxis = "horizontal"
        root.switchDirection = -1
        root.forceIdle = false
        root.manualFocusId = ""
    }

    property string pinFeedbackId: ""
    property bool pinFeedbackPinned: false

    Timer {
        id: pinFeedbackTimer
        interval: 1400
    }

    function togglePin(id) {
        const target = id ?? root.primaryId
        if (!root.pinnableIds.includes(target)) return
        const list = [...(root.cfg.pinned ?? [])]
        const index = list.indexOf(target)
        if (index >= 0) list.splice(index, 1)
        else list.push(target)
        Config.options.bar.dynamicIsland.pinned = list
        root.pinFeedbackId = target
        root.pinFeedbackPinned = index < 0
        pinFeedbackTimer.restart()
    }

    // What scrolling up and down walks through: Live Activities only (Regra 4), then home. Tools — pinned
    // or not — never show up on the wheel; they are reached by intent, from the Tool Dock or the switcher.
    readonly property var cycleIds: {
        const ids = root.persistentIds.filter(id => root.liveIds.includes(id))
        ids.push("idle")
        return ids
    }

    // How many Live Activities are actually running — the pips only earn their place (Regra: "se houver
    // apenas uma Live Activity, não existe motivo para indicar navegação") once there is more than one.
    readonly property int liveActivityCount: root.persistentIds.filter(id => root.liveIds.includes(id)).length

    // Where home sits in that queue: the pip drawn hollow, and the place the island returns to
    readonly property int homeIndex: root.cycleIds.indexOf("idle")
    readonly property bool atHome: root.primaryId === "idle" || root.primaryId === root.rawPrimaryId

    // A short trail after each turn of the wheel: which of them you are on
    property bool cycleHintShown: false
    Timer {
        id: cycleHintTimer
        interval: 1600
        onTriggered: root.cycleHintShown = false
    }

    function cycleIsland(direction) {
        if (!root.expanded && root.interruptId === "" && root.cycleIds.length > 1) {
            root.cycleHintShown = true
            cycleHintTimer.restart()
        }
        if (root.expanded) {
            const ids = root.switcherIds
            if (ids.length < 2) return
            const index = Math.max(0, ids.indexOf(root.expandedId))
            root.selectIsland(ids[(index + direction + ids.length) % ids.length])
            return
        }
        if (root.interruptId !== "") return
        const ids = root.cycleIds
        if (ids.length < 2) return
        const index = ids.indexOf(root.primaryId)
        const next = index < 0
            ? (direction > 0 ? ids[0] : ids[ids.length - 1])
            : ids[(index + direction + ids.length) % ids.length]
        root.switchAxis = "vertical"
        root.switchDirection = direction
        root.markUserSwitch()
        if (next === "idle") root.forceIdle = true
        else root.focusIsland(next)
    }

    // Automatic attention: only the lateral reveal, never the vertical expansion
    function peek(ms) {
        if (!(root.cfg.autoExpand ?? true) || !root.onFocusedScreen || root.expanded || root.vertical) return
        root.peekReveal = true
        peekTimer.interval = ms ?? (root.cfg.autoExpandDuration ?? 4500)
        peekTimer.restart()
    }

    onExpandedIdChanged: if (root.expanded && !root.hasDetails(root.expandedId)) root.collapse()
    onCardHoveredChanged: {
        if (root.cardHovered) collapseTimer.stop()
        else if (root.expanded) collapseTimer.restart()
    }

    // Open and untouched (or left alone): it closes after a while; the overlay's fuse shows the countdown
    readonly property int collapseDelay: 4000
    onExpandedChanged: {
        if (root.expanded && !root.cardHovered) collapseTimer.restart()
        if (!root.expanded) collapseTimer.stop()
    }

    Timer {
        id: peekTimer
        onTriggered: root.peekReveal = false
    }

    Timer {
        id: hoverRevealTimer
        interval: 140
        onTriggered: root.hoverArmed = pillHover.hovered
    }

    Timer {
        id: collapseTimer
        interval: root.collapseDelay + 800
        onTriggered: {
            if (!root.cardHovered && !(root.wantsKeyboard && root.replyHasText) && !root.dragging) root.collapse()
        }
    }

    // Motion
    property real breath: 1
    property real shakeX: 0
    property real glow: 0

    SequentialAnimation {
        id: breathAnim
        NumberAnimation { target: root; property: "breath"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "breath"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -7; duration: 45 }
        NumberAnimation { target: root; property: "shakeX"; to: 7; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: -5; duration: 55 }
        NumberAnimation { target: root; property: "shakeX"; to: 4; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 45 }
    }


    // Content switching: old content blurs out, new content slides in 80ms later
    property string shownId: ""
    property int activeSlot: 0

    function componentFor(id) {
        switch (id) {
            case "media":         return mediaComponent
            case "osd":           return osdComponent
            case "notification":  return notificationComponent
            case "battery":       return batteryComponent
            case "bluetooth":     return bluetoothComponent
            case "audioOutput":   return audioOutputComponent
            case "screenshot":    return screenshotComponent
            case "clipboard":     return clipboardComponent
            case "songRecResult": return songRecComponent
            case "songRec":       return songRecComponent
            case "weather":       return weatherComponent
            case "f1Flag":        return f1FlagComponent
            case "f1Start":       return f1StartComponent
            case "f1":            return f1Component
            case "recording":     return recordingComponent
            case "timer":         return timerComponent
            case "activity":      return activityComponent
            case "systemLoad":    return systemLoadComponent
            case "system":        return systemComponent
            case "shelf":         return shelfComponent
            case "shelfDrop":     return shelfDropComponent
            case "f1Event":       return f1EventComponent
            case "hibernate":     return batteryComponent
            case "networkAlert":
            case "download":      return networkComponent
            case "agents":        return agentsComponent
            case "history":       return historyComponent
            case "zerotier":      return zerotierComponent
            case "downloadDone":  return downloadDoneComponent
            case "hardware":      return hardwareComponent
            case "session":       return sessionComponent
            default:              return idleComponent
        }
    }

    function switchContent() {
        if (root.vertical) return
        const id = root.primaryId
        if (id === root.shownId) return
        const incoming = root.activeSlot === 0 ? slotB : slotA
        const outgoing = root.activeSlot === 0 ? slotA : slotB
        const firstShow = root.shownId === ""
        const axis = root.switchAxis
        const direction = root.switchDirection
        root.switchAxis = ""
        outgoing.leave(axis, direction)
        incoming.contentId = id
        incoming.sourceComponent = root.componentFor(id)
        incoming.enter(firstShow, axis, direction)
        root.activeSlot = 1 - root.activeSlot
        root.shownId = id
        if (firstShow) return
        if (axis === "vertical") stackShuffle.restart()
        if (root.interruptIds.includes(id) && !["osd", "hibernate", "shelfDrop"].includes(id)) breathAnim.restart()
    }

    onPrimaryIdChanged: {
        if (root.primaryId !== "clipboard") root.clipboardIndex = 0
        root.switchContent()
    }
    Component.onCompleted: {
        root.primaryId = root.rawPrimaryId
        root.primarySince = Date.now()
        root.shownNotification = root.latestNotification
        root.switchContent()
    }

    component ContentSlot: Loader {
        id: slot
        property string contentId: ""
        property real blurAmount: 0
        property real offsetY: 0
        property real offsetX: 0
        property real leaveX: 0
        property real leaveY: -4
        anchors.fill: parent
        opacity: 0
        transform: Translate { x: slot.offsetX; y: slot.offsetY }
        layer.enabled: slot.blurAmount > 0.01
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: slot.blurAmount
            blurMax: 24
        }

        onLoaded: if (slot.contentId === "session" && slot.item) slot.item.forceActiveFocus()

        function enter(instant, axis, direction) {
            leaveAnim.stop()
            if (instant) {
                slot.opacity = 1
                slot.offsetX = 0
                slot.offsetY = 0
                slot.blurAmount = 0
                return
            }
            slot.opacity = 0
            slot.offsetX = axis === "horizontal" ? 16 * direction : 0
            slot.offsetY = axis === "vertical" ? 10 * direction : (axis === "horizontal" ? 0 : 6)
            slot.blurAmount = 0.45
            slot.scale = 0.96
            enterAnim.restart()
        }

        function leave(axis, direction) {
            enterAnim.stop()
            slot.leaveX = axis === "horizontal" ? -16 * direction : 0
            slot.leaveY = axis === "vertical" ? -10 * direction : (axis === "horizontal" ? 0 : -4)
            if (slot.sourceComponent) leaveAnim.restart()
        }

        SequentialAnimation {
            id: enterAnim
            PauseAnimation { duration: 80 }
            ParallelAnimation {
                NumberAnimation { target: slot; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                NumberAnimation { target: slot; property: "blurAmount"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: slot; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                NumberAnimation {
                    target: slot; property: "offsetX"; to: 0; duration: 380
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
                NumberAnimation {
                    target: slot; property: "offsetY"; to: 0; duration: 380
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }
        }

        SequentialAnimation {
            id: leaveAnim
            ParallelAnimation {
                NumberAnimation { target: slot; property: "opacity"; to: 0; duration: 170; easing.type: Easing.InCubic }
                NumberAnimation { target: slot; property: "blurAmount"; to: 0.6; duration: 170 }
                NumberAnimation { target: slot; property: "offsetY"; to: slot.leaveY; duration: 170; easing.type: Easing.InCubic }
                NumberAnimation { target: slot; property: "offsetX"; to: slot.leaveX; duration: 170; easing.type: Easing.InCubic }
            }
            ScriptAction {
                script: {
                    slot.sourceComponent = undefined
                    slot.contentId = ""
                    slot.blurAmount = 0
                }
            }
        }
    }

    implicitHeight: root.pillHeight
    implicitWidth: pill.width + (capsuleRow.visible ? capsuleRow.width : 0)
        + (homeTab.visible ? homeTab.width + 8 : 0) + (f1Chip.visible ? f1Chip.width + 8 : 0) + (deck.visible ? deck.width + 8 : 0)

    // Covers the pill and its bubbles, so hovering a bubble keeps the island revealed
    HoverHandler {
        id: pillHover
        onHoveredChanged: {
            if (pillHover.hovered) {
                hoverRevealTimer.restart()
            } else {
                hoverRevealTimer.stop()
                root.hoverArmed = false
                root.leftPillAt = Date.now()
                root.releaseInsist()
            }
        }
        onPointChanged: root.trackInsist(pillHover.point.position)
    }

    // Pushing the pointer against the screen edge over the island ("insisting") opens it: the pill stretches
    // toward the pointer while it builds up, and springs back if the pointer leaves the edge
    property real insist: 0

    // When the pointer comes up from the island itself, not when the island grows under a resting pointer
    property double leftPillAt: 0

    function startInsist() {
        if (root.expanded || root.vertical || Config.options.bar.bottom || root.dragging) return
        if (!pillHover.hovered && Date.now() - root.leftPillAt > 800) return
        if (!insistBuild.running && root.insist < 0.01) {
            insistRelease.stop()
            insistBuild.restart()
        }
    }

    // Bars that touch the screen edge: the top row of the bar window is the edge
    function trackInsist(position) {
        const inWindow = root.mapToItem(null, position.x, position.y)
        if (inWindow.y <= 1.5) root.startInsist()
        else if (inWindow.y > 6) root.releaseInsist()
    }

    function releaseInsist() {
        if (!insistBuild.running && root.insist < 0.01) return
        insistBuild.stop()
        insistRelease.restart()
    }

    SequentialAnimation {
        id: insistBuild
        NumberAnimation { target: root; property: "insist"; from: 0; to: 1; duration: 450; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                root.markUserSwitch()
                root.expandTo(2, root.hasDetails(root.primaryId) ? undefined : "overview")
                insistRelease.restart()
            }
        }
    }

    NumberAnimation {
        id: insistRelease
        target: root
        property: "insist"
        to: 0
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 2.5
    }

    // Card stack: other active islands peek out from under the pill
    readonly property var stackIds: (root.cfg.splitMode ?? false) ? [] : root.persistentIds.filter(id => id !== root.primaryId)
    readonly property int stackDepth: Math.min(2, root.stackIds.length)
    property real stackPulse: 0

    SequentialAnimation {
        id: stackShuffle
        NumberAnimation { target: root; property: "stackPulse"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "stackPulse"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    // Geometry of the island's visible surface (material pill or the pill itself) in this item's coordinates
    readonly property rect surfaceRectLocal: {
        root.surfaceItem.width
        root.surfaceItem.height
        root.implicitWidth
        pill.width
        const p = root.mapFromItem(root.surfaceItem, 0, 0)
        return Qt.rect(p.x, p.y, root.surfaceItem.width, root.surfaceItem.height)
    }

    // A short name for an island, for the places where only an icon fits and an icon is not enough
    function nameForId(id) {
        const name = root.longNameForId(id)
        return name.length > 18 ? `${name.slice(0, 17)}…` : name
    }

    function longNameForId(id) {
        switch (id) {
            case "media":      return root.activePlayer?.trackTitle ?? Translation.tr("Media")
            case "recording":  return Translation.tr("Recording")
            case "f1":         return "F1"
            case "timer":      return root.timerValueText()
            case "activity": {
                const title = IslandEvents.latestActivity?.title ?? Translation.tr("Activity")
                return title.split(" · ")[0]
            }
            case "systemLoad": return Translation.tr("System")
            case "system":     return Translation.tr("System")
            case "songRec":    return Translation.tr("Listening…")
            case "shelf":      return Translation.tr("Drawer")
            case "notification": return IslandEvents.notificationParts(root.latestNotification).app || Translation.tr("Notification")
            case "download":   return IslandEvents.downloadFileName !== "" ? IslandEvents.downloadFileName : Translation.tr("Download")
            case "agents":     return Translation.tr("AI agents")
            case "history":    return Translation.tr("Recent events")
            case "calendar":   return DateTime.longDate
            case "zerotier":   return "ZeroTier"
            case "networkAlert": return Translation.tr("Network")
            case "downloadDone": return IslandEvents.downloadDone.payload?.name ?? Translation.tr("Downloaded")
            case "battery":    return `${Math.round(Battery.percentage * 100)}%`
            case "bluetooth":  return IslandEvents.bluetooth.payload?.name ?? "Bluetooth"
            case "clipboard":  return Translation.tr("Copied")
            case "screenshot": return Translation.tr("Screenshots")
            case "weather":    return Weather.data?.temp ?? Translation.tr("Weather")
            case "privacy":    return Translation.tr("Privacy")
            case "hardware":   return IslandHardware.payload.title ?? Translation.tr("Hardware")
            default:           return id
        }
    }

    function iconForId(id) {
        switch (id) {
            case "media":      return "music_note"
            case "recording":  return "fiber_manual_record"
            case "f1":         return "sports_motorsports"
            case "timer":      return root.timerIcon()
            case "activity":   return IslandEvents.latestActivity?.icon ?? "bolt"
            case "systemLoad": return "memory"
            case "system":     return "monitoring"
            case "songRec":    return "graphic_eq"
            case "shelf":      return "inventory_2"
            case "download":   return "download"
            case "agents":     return ClaudeCode.openAgents[0] ?? "bolt"
            case "history":    return "history"
            case "calendar":   return "calendar_month"
            case "zerotier":   return "vpn_lock"
            case "networkAlert": return "wifi"
            case "downloadDone": return "download_done"
            case "notification": return "notifications"
            case "battery":    return root.batteryIcon()
            case "bluetooth":  return "bluetooth"
            case "clipboard":  return "content_paste"
            case "screenshot": return "screenshot_monitor"
            case "weather":    return IslandEvents.weatherSymbol(Weather.data?.wCode ?? 800)
            case "privacy":    return "privacy_tip"
            case "hardware":   return IslandHardware.payload.icon ?? "memory"
            default:           return "stacks"
        }
    }

    // On a pinned island, a small home tab leads back to the main island
    Rectangle {
        id: homeTab
        // Only on a pinned island: a leftover from natural priority or a scroll comes with the pips and the
        // deck already, and this tab used to show for those too — a home icon with no pinned tab in sight.
        visible: !root.vertical && root.onPinnedView
        x: pill.width + 6
        anchors.verticalCenter: pill.verticalCenter
        width: visible ? 24 : 0
        height: 24
        radius: 12
        color: homeMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        opacity: root.overlayShown ? 0 : 1

        onVisibleChanged: if (visible) homeEntrance.restart()

        DiEntrance {
            id: homeEntrance
            target: homeTab
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "home"
            iconSize: 15
            fill: 1
            color: Appearance.colors.colOnLayer1
        }

        MouseArea {
            id: homeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goHome()
        }
    }

    // During a session the focused driver's position stays beside the island while something else is on top
    Rectangle {
        id: f1Chip
        readonly property var driver: F1.focusDriver
        visible: !root.vertical && !root.overlayShown && F1.enabled && F1.sessionLive && f1Chip.driver !== null
            && root.primaryId !== "f1" && (root.cfg.f1.pinPosition ?? true)
        x: pill.width + 6 + (homeTab.visible ? homeTab.width + 6 : 0)
        anchors.verticalCenter: pill.verticalCenter
        width: visible ? f1ChipRow.implicitWidth + 14 : 0
        height: 24
        radius: 12
        color: f1ChipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        onVisibleChanged: if (visible) f1ChipEntrance.restart()

        DiEntrance {
            id: f1ChipEntrance
            target: f1Chip
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        RowLayout {
            id: f1ChipRow
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                implicitWidth: 3
                implicitHeight: 12
                radius: 1.5
                color: f1Chip.driver?.color ?? Appearance.colors.colPrimary
            }
            StyledText {
                text: `P${f1Chip.driver?.position ?? "-"}`
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: f1Chip.driver?.tla ?? ""
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer1
                opacity: 0.7
            }
        }

        MouseArea {
            id: f1ChipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusIsland("f1")
        }
    }

    // Deck: the other active islands as a tiny card pile beside the pill.
    // The top card shows what comes next; scrolling/swiping up-down (or a click) deals it.
    Item {
        id: deck
        visible: !root.vertical && root.stackDepth > 0
        x: pill.width + 12 + (homeTab.visible ? homeTab.width + 6 : 0) + (f1Chip.visible ? f1Chip.width + 6 : 0)
        anchors.verticalCenter: pill.verticalCenter
        width: visible ? 18 + (root.stackDepth - 1) * 4 + (deckLabel.implicitWidth > 0 ? deckLabel.implicitWidth + 5 : 0) : 0
        height: 22
        opacity: root.overlayShown ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }
        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.stackDepth
            delegate: Rectangle {
                required property int index
                readonly property bool isTop: index === root.stackDepth - 1
                x: index * 4 + root.stackPulse * index * 3
                y: (root.stackDepth - 1 - index) * 1.5
                width: 16
                height: 21
                radius: 5
                // A calm fan at rest; the shuffle pulse still gives it a flourish when a card changes
                rotation: (index - (root.stackDepth - 1) / 2) * (3 + root.stackPulse * 8)
                color: isTop ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, isTop ? 0.7 : 0.84)

                readonly property bool mediaOnTop: isTop && (root.stackIds[0] ?? "") === "media"
                readonly property bool hasArt: (root.activePlayer?.trackArtUrl ?? "") !== ""
                clip: true

                // Music waiting behind: its cover, with bars that keep moving while it plays
                StyledImage {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: parent.mediaOnTop && parent.hasArt
                    source: visible ? root.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 32
                    sourceSize.height: 42
                }

                Row {
                    visible: parent.mediaOnTop
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 3
                    }
                    spacing: 1.5

                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            id: bar
                            required property int index
                            width: 2
                            height: 3
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: parent.parent.hasArt ? "white" : Appearance.colors.colPrimary

                            SequentialAnimation on height {
                                running: root.activePlayer?.isPlaying ?? false
                                loops: Animation.Infinite
                                PauseAnimation { duration: bar.index * 120 }
                                NumberAnimation { to: 9; duration: 260; easing.type: Easing.OutQuad }
                                NumberAnimation { to: 3; duration: 300; easing.type: Easing.InQuad }
                            }
                        }
                    }
                }

                // An agent's mark is an SVG, not a Material symbol: drawing it as text gives an empty box
                DiClaudeIcon {
                    visible: parent.isTop && ["claude", "codex", "gemini"].includes(root.iconForId(root.stackIds[0] ?? ""))
                    anchors.centerIn: parent
                    agent: root.iconForId(root.stackIds[0] ?? "")
                    size: 12
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    visible: parent.isTop && !(parent.mediaOnTop && parent.hasArt)
                        && !["claude", "codex", "gemini"].includes(root.iconForId(root.stackIds[0] ?? ""))
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: parent.mediaOnTop ? -3 : 0
                    text: root.iconForId(root.stackIds[0] ?? "")
                    iconSize: 12
                    fill: 1
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // A card alone says nothing about what is behind it: name it while the pointer is on the island
        Revealer {
            id: deckLabel
            anchors {
                left: parent.left
                leftMargin: 18 + (root.stackDepth - 1) * 4 + 5
                verticalCenter: parent.verticalCenter
            }
            height: parent.height
            reveal: root.hoverRevealed && root.stackIds.length > 0

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.nameForId(root.stackIds[0] ?? "")
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                opacity: 0.85
            }
        }

        Rectangle {
            visible: root.stackIds.length > 1
            anchors {
                right: parent.right
                rightMargin: -4
                top: parent.top
                topMargin: -5
            }
            width: 14
            height: 14
            radius: 7
            color: Appearance.colors.colPrimary
            border.width: 1.5
            border.color: root.pillColor

            StyledText {
                anchors.centerIn: parent
                text: root.stackIds.length
                font.pixelSize: 8
                font.weight: Font.Bold
                color: Appearance.colors.colOnPrimary
            }
        }

        MouseArea {
            id: deckMouse
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            // One island behind: deal it. Several: open the overview with all of them
            onClicked: {
                if (root.deckPeeking) return
                if (root.stackIds.length > 1) root.expandTo(2, "overview")
                else root.cycleIsland(1)
            }
            onPressAndHold: root.deckPeeking = true
            onReleased: root.deckPeeking = false
            onExited: root.deckPeeking = false
        }
    }

    // Holding the deck shows the island underneath, small, before you decide to deal it
    property bool deckPeeking: false

    Item {
        id: deckPeek
        visible: root.deckPeeking && root.stackIds.length > 0
        x: deck.x + deck.width + 8
        y: pill.y
        implicitWidth: 190
        height: root.pillHeight
        opacity: root.deckPeeking ? 1 : 0
        scale: root.deckPeeking ? 1 : 0.9
        transformOrigin: Item.Left
        z: 4

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.capsuleColor

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 12
                }
                spacing: 8

                DiClaudeIcon {
                    visible: ["claude", "codex", "gemini"].includes(root.iconForId(root.stackIds[0] ?? ""))
                    agent: root.iconForId(root.stackIds[0] ?? "")
                    size: 16
                    color: Appearance.colors.colOnLayer1
                }
                MaterialSymbol {
                    visible: !["claude", "codex", "gemini"].includes(root.iconForId(root.stackIds[0] ?? ""))
                    text: root.iconForId(root.stackIds[0] ?? "")
                    iconSize: 17
                    fill: 1
                    color: Appearance.colors.colOnLayer1
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: -3

                    StyledText {
                        Layout.fillWidth: true
                        text: root.nameForId(root.stackIds[0] ?? "")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Release to switch")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // The only navigation indicator there is. One dot per stop of the single vertical queue, laid under the pill
    // where no island's own content can sit on top of it, and with home drawn hollow — that is the mark that
    // tells you how far from the main island you are.
    Row {
        id: cyclePips
        visible: !root.vertical && !root.overlayShown && root.liveActivityCount > 1
        // Centered under the whole visual block: just the pill normally, but the pill plus the capsules
        // when split mode stretches the island sideways — otherwise the dots read as pushed to the left.
        readonly property real blockWidth: pill.width + (capsuleRow.visible ? capsuleRow.width : 0)
        x: pill.x + (cyclePips.blockWidth - cyclePips.implicitWidth) / 2
        y: pill.y + root.pillHeight + 2
        spacing: 3
        opacity: (root.cycleHintShown || root.hoverRevealed) ? 1 : 0
        z: 3

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: Math.min(7, root.cycleIds.length)
            delegate: Rectangle {
                required property int index
                readonly property bool current: root.cycleIds.indexOf(root.primaryId) === index
                readonly property bool home: root.homeIndex === index
                width: current ? 8 : 3
                height: 3
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: current ? Appearance.colors.colPrimary
                    : (home ? "transparent" : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.55))
                border.width: home && !current ? 1 : 0
                border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.35)

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Rectangle {
        id: pill
        anchors.left: parent.left
        width: root.compactWidth(root.primaryId)
        height: root.pillHeight
        radius: height / 2
        color: root.pillColor
        visible: !root.vertical
        // The overlay takes over with an identical shape, so swap without a fade
        opacity: root.overlayShown ? 0 : 1
        scale: root.breath
        transform: [
            Translate { x: root.shakeX },
            Scale {
                origin.x: pill.width / 2
                origin.y: 0
                xScale: 1 + 0.04 * root.insist
                yScale: 1 + 0.16 * root.insist
            }
        ]

        Behavior on width {
            NumberAnimation {
                duration: 440
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        Item {
            anchors.fill: parent
            anchors.rightMargin: root.anchorInset
            clip: true
            transform: Translate { x: root.swipeOffsetX; y: root.swipeOffsetY }

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            ContentSlot { id: slotA }
            ContentSlot { id: slotB }
        }

        // The anchor itself, pinned to the right edge of the pill. A hairline separates it from whatever island
        // is on the left, and the value slides up when it changes, so the minute turning is a movement you catch
        // out of the corner of your eye instead of a number that blinks.
        Item {
            id: anchor
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: anchorRow.implicitWidth
            implicitHeight: anchorRow.implicitHeight

            // The date is the thing you look *up*, not at: hovering the anchor swaps the time for it, and a
            // click opens the calendar full size.
            HoverHandler {
                id: anchorHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.expandTo(2, "calendar")
            }
            opacity: root.anchorShown ? 1 : 0
            visible: opacity > 0.01

            readonly property color tone: {
                switch (root.anchorInfo.tone) {
                    case "error":     return Appearance.colors.colError
                    case "attention": return IslandEvents.colorAttention
                    default:          return Appearance.colors.colOnLayer0
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors {
                    right: anchorRow.left
                    rightMargin: 9
                    verticalCenter: parent.verticalCenter
                }
                width: 1
                height: root.pillHeight * 0.42
                radius: 0.5
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
            }

            RowLayout {
                id: anchorRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                MaterialSymbol {
                    visible: root.anchorInfo.icon !== ""
                    text: root.anchorInfo.icon
                    iconSize: 13
                    fill: 1
                    color: anchor.tone
                }

                ColumnLayout {
                    spacing: -3

                    // The date rides above the clock whenever the anchor *is* the clock. It is small and quiet
                    // most of the time, and steps forward on the days you actually have to think about it —
                    // the weekend, the first hour of a new day, the minutes after waking the machine up.
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        visible: root.anchorInfo.tone === "plain" && (root.cfg.anchorDate ?? true)
                            && !anchorHover.hovered && root.pillHeight >= 26
                        text: DateTime.shortDate
                        font.family: anchorText.font.family
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: anchor.tone
                        opacity: root.dateIsNews ? 0.9 : 0.5
                    }

                Item {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: anchorText.implicitWidth
                    Layout.preferredHeight: anchorText.implicitHeight
                    clip: true

                    StyledText {
                        id: anchorText
                        y: 0
                        text: anchorHover.hovered && root.anchorInfo.tone === "plain"
                            ? DateTime.shortDate : root.anchorInfo.text
                        // The one number that is always on screen deserves a face of its own: a geometric
                        // display face reads as deliberate next to the interface font, and tabular figures keep
                        // the digits from shifting as the minute turns.
                        font.family: {
                            switch (root.cfg.anchorFont ?? "expressive") {
                                case "numbers":   return Appearance.font.family.numbers
                                case "monospace": return Appearance.font.family.monospace
                                case "main":      return Appearance.font.family.main
                                default:          return Appearance.font.family.expressive
                            }
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        font.letterSpacing: 0.4
                        font.features: { "tnum": 1 }
                        color: anchor.tone
                        opacity: root.anchorInfo.tone === "plain" ? 0.85 : 1

                        onTextChanged: anchorSlide.restart()

                        SequentialAnimation {
                            id: anchorSlide
                            NumberAnimation { target: anchorText; property: "y"; from: 7; to: 0; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1.5
            border.color: root.alertColor
            opacity: root.alertLevel >= 2 ? 0.8 : 0
            visible: opacity > 0
        }

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: -4
                top: parent.top
                topMargin: -4
            }
            width: 18
            height: 18
            radius: 9
            color: Appearance.colors.colPrimary
            scale: pinFeedbackTimer.running ? 1 : 0
            visible: scale > 0.01

            Behavior on scale {
                NumberAnimation { duration: 300; easing.type: Easing.OutBack }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.pinFeedbackPinned ? "push_pin" : "keep_off"
                iconSize: 12
                fill: 1
                color: Appearance.colors.colOnPrimary
            }
        }

        // Says what just happened to the island you pushed away, so a dismissal never looks like a glitch
        Rectangle {
            anchors {
                left: parent.left
                leftMargin: -4
                top: parent.top
                topMargin: -4
            }
            width: 18
            height: 18
            radius: 9
            color: root.dismissFeedbackSilenced ? IslandEvents.colorAttention : Appearance.colors.colLayer2
            scale: dismissFeedbackTimer.running ? 1 : 0
            visible: scale > 0.01

            Behavior on scale {
                NumberAnimation { duration: 300; easing.type: Easing.OutBack }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.dismissFeedbackSilenced ? "notifications_paused" : "do_not_disturb_on"
                iconSize: 12
                fill: 1
                color: root.dismissFeedbackSilenced ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }
        }

        Row {
            id: privacyDots
            anchors {
                right: parent.right
                rightMargin: 12
                top: parent.top
                topMargin: 2
            }
            spacing: 3
            visible: (root.cfg.privacyIndicators ?? true) && IslandEvents.anyPrivacy

            Repeater {
                model: [
                    { show: IslandEvents.micInUse, color: IslandEvents.colorAttention },
                    { show: IslandEvents.cameraInUse || IslandEvents.screenInUse, color: "#30D158" }
                ].filter(d => d.show)
                delegate: Rectangle {
                    required property var modelData
                    width: 6
                    height: 6
                    radius: 3
                    color: modelData.color

                }
            }

        }

        // Getting something out of the way: a middle click dismisses what is on screen, holding it silences that
        // island until you ask for it back. Kept on its own handler so a hold never also counts as a tap.
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            longPressThreshold: 0.55
            onTapped: root.dismissCurrent()
            onLongPressed: root.silenceIsland(root.primaryId)
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (eventPoint, button) => {
                if (button === Qt.RightButton) {
                    root.togglePin()
                    return
                }
                const onPrivacy = privacyDots.visible
                    && privacyDots.contains(privacyDots.mapFromItem(pill, eventPoint.position.x, eventPoint.position.y))
                if (onPrivacy) root.expandTo(2, "privacy")
                else if (root.hasDetails(root.primaryId)) root.toggleExpanded()
            }
        }

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.handleWheel(event)
        }

        DragHandler {
            id: swipe
            target: null
            acceptedButtons: Qt.LeftButton
            dragThreshold: 6
            onActiveChanged: {
                if (swipe.active) root.beginSwipe()
                else root.endSwipe()
            }
            onTranslationChanged: if (swipe.active) root.trackSwipe(swipe.translation.x, swipe.translation.y)
        }

        Timer {
            id: wheelCooldown
            interval: 260
            onTriggered: root.wheelCooling = false
        }

        // A pause means the next turn starts over, instead of adding to what was left of the last one
        Timer {
            id: wheelReset
            interval: 500
            onTriggered: root.wheelAccum = 0
        }

        Timer {
            id: gestureIdle
            interval: 160
            onTriggered: root.resetSwipe()
        }
    }

    Row {
        id: capsuleRow
        anchors {
            left: pill.right
            verticalCenter: pill.verticalCenter
        }
        visible: !root.vertical && root.secondaryIds.length > 0
        opacity: root.overlayShown ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        readonly property int hiddenCount: root.persistentIds.filter(id => id !== root.primaryId).length - root.secondaryIds.length

        Item {
            visible: capsuleRow.hiddenCount > 0
            width: visible ? moreBadge.width + root.capsuleGap : 0
            height: root.pillHeight
            z: 1

            Rectangle {
                id: moreBadge
                x: root.capsuleGap
                anchors.verticalCenter: parent.verticalCenter
                width: moreText.implicitWidth + 12
                height: 20
                radius: 10
                color: root.capsuleColor

                StyledText {
                    id: moreText
                    anchors.centerIn: parent
                    text: `+${capsuleRow.hiddenCount}`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandTo(1)
                }
            }
        }

        // secondaryIds is a plain JS array, rebuilt fresh every time anything it depends on changes (which,
        // between timers and live stats, is roughly every second) — a Repeater has no way to diff that against
        // the last array, so it destroys and recreates every capsule delegate on that same cadence. That used to
        // feed straight into "sep"/"grow", so the pop-in animation kept restarting from zero forever and the
        // capsule could never actually finish detaching from the pill. Binding the resting values directly
        // (instead of assigning them once in onCompleted) makes the correct geometry the delegate's first frame,
        // no animation life span required — recreated every second or not, it always renders already-settled.
        Repeater {
            model: root.secondaryIds
            delegate: Item {
                id: capsuleDelegate
                required property string modelData
                readonly property real sep: root.capsuleGap
                readonly property real grow: 1

                width: capsuleDelegate.sep + capsule.width
                height: root.pillHeight
                opacity: 0

                NumberAnimation on opacity {
                    to: 1
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                Rectangle {
                    id: capsule
                    x: capsuleDelegate.sep
                    width: Math.max(root.pillHeight, capsuleContent.implicitWidth)
                    height: root.pillHeight
                    radius: height / 2
                    color: root.capsuleColor
                    transformOrigin: Item.Left

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }

                    DiCapsule {
                        id: capsuleContent
                        anchors.centerIn: parent
                        di: root
                        providerId: capsuleDelegate.modelData
                        showLabel: true
                        hovered: capsuleMouse.containsMouse
                    }

                    MouseArea {
                        id: capsuleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                root.dismiss(capsuleDelegate.modelData)
                                return
                            }
                            root.forceIdle = false
                            root.manualFocusId = capsuleDelegate.modelData
                        }
                    }
                }
            }
        }
    }

    DiExpanded {
        di: root
        pillItem: pill
    }

    // Floating bars leave a gap above them: this strip at the screen edge is what the pointer touches when pushed up
    DiEdgeTrigger {
        di: root
    }

    // A fullscreen window hides the bar; this keeps a hairline of it alive at the screen edge
    DiFullscreenPeek {
        di: root
    }

    Component { id: idleComponent; DiIdle { di: root } }
    Component { id: mediaComponent; DiMedia { di: root } }
    Component { id: osdComponent; DiOsd { di: root } }
    Component { id: notificationComponent; DiNotifs { di: root } }
    Component { id: batteryComponent; DiBattery { di: root } }
    Component { id: bluetoothComponent; DiBluetooth { di: root } }
    Component { id: audioOutputComponent; DiAudioOutput { di: root } }
    Component { id: screenshotComponent; DiScreenshot { di: root } }
    Component { id: clipboardComponent; DiClipboard { di: root } }
    Component { id: songRecComponent; DiSongRec { di: root } }
    Component { id: weatherComponent; DiWeather { di: root } }
    Component { id: f1FlagComponent; DiF1Flag { di: root } }
    Component { id: f1StartComponent; DiF1Start { di: root } }
    Component { id: f1Component; DiF1 { di: root } }
    Component { id: recordingComponent; DiRecording { di: root } }
    Component { id: timerComponent; DiTimers { di: root } }
    Component { id: activityComponent; DiActivity { di: root } }
    Component { id: systemLoadComponent; DiSystemLoad { di: root } }
    Component { id: systemComponent; DiSystem { di: root } }
    Component { id: shelfComponent; DiShelf { di: root } }
    Component { id: shelfDropComponent; DiShelfDrop { di: root } }
    Component { id: f1EventComponent; DiF1Event { di: root } }
    Component { id: networkComponent; DiNetwork { di: root } }
    Component { id: downloadDoneComponent; DiDownloadDone { di: root } }
    Component { id: agentsComponent; DiAgents { di: root } }
    Component { id: historyComponent; DiHistory { di: root } }
    Component { id: zerotierComponent; DiZeroTier { di: root } }
    Component { id: hardwareComponent; DiHardware { di: root } }
    Component { id: sessionComponent; DiSession { di: root } }
}
