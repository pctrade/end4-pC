pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.ready && (Config.options.bar.dynamicIsland.f1.enable ?? false)
    readonly property string favoriteDriver: (Config.options.bar.dynamicIsland.f1.favoriteDriver ?? "").toUpperCase()
    readonly property int countdownMinutes: Config.options.bar.dynamicIsland.f1.countdownMinutes ?? 15

    property list<string> daemonArgs: ["live", "--until-idle"]
    property bool initializing: true

    property string mode: "idle"
    property bool connected: false
    property var session: ({})
    property string sessionStatus: ""
    property string trackStatus: "1"
    property string trackMessage: ""
    property int lap: 0
    property int totalLaps: 0
    property string remaining: ""
    property var drivers: []
    property var raceControl: null
    property var nextSession: null
    property var weather: ({})
    property int lastFocusTyreStint: 0
    property var teamRadio: null
    readonly property bool autoPlayRadio: Config.options.bar.dynamicIsland.f1.autoPlayRadio ?? false
    readonly property bool radioPlaying: radioPlayer.running

    readonly property bool sessionLive: root.connected && ["Inactive", "Started", "Aborted", "Finished"].includes(root.sessionStatus)
    readonly property bool racing: root.connected && root.sessionStatus === "Started"
    readonly property bool isRace: (root.session?.type ?? "") === "Race"
    readonly property var leader: root.drivers.length > 0 ? root.drivers[0] : null
    readonly property var focusDriver: root.drivers.find(d => d.tla === root.favoriteDriver) ?? root.leader

    // Test hook: forces a flag without being overwritten by the live feed
    property string flagOverride: ""
    readonly property string flag: {
        if (root.flagOverride !== "") return root.flagOverride
        switch (root.trackStatus) {
            case "2": return "yellow"
            case "4": return "sc"
            case "5": return "red"
            case "6": return "vsc"
            case "7": return "vscEnding"
            default: return "green"
        }
    }
    readonly property bool flagIsAlert: root.sessionLive && root.flag !== "green"

    property real nowMs: Date.now()
    readonly property int secondsToNext: root.nextSession ? Math.round((Date.parse(root.nextSession.start) - root.nowMs) / 1000) : -1
    readonly property bool countdownActive: !root.sessionLive && root.secondsToNext > 0 && root.secondsToNext <= root.countdownMinutes * 60

    signal flagEvent(string flag)
    signal lightsOut()
    signal newRaceControlMessage(var message)
    signal tyreChange(var driver)
    signal rainStarted()
    signal sessionResult(var podium)
    signal teamRadioMessage(var radio)
    signal fastestLap(var driver, string time)
    signal blueFlag(var driver)
    signal lapsToGo(int laps)

    property int fastestLapMs: 0
    property int announcedLapsToGo: -1

    // "1:24.624" -> 84624
    function parseLapTime(text) {
        const m = /^(?:(\d+):)?(\d+)\.(\d+)$/.exec((text ?? "").trim())
        if (!m) return 0
        return (Number(m[1] ?? 0) * 60 + Number(m[2])) * 1000 + Number(m[3].padEnd(3, "0").slice(0, 3))
    }

    function tyreColor(compound) {
        switch (compound) {
            case "SOFT": return "#E10600"
            case "MEDIUM": return "#FFD12E"
            case "HARD": return "#F0F0F0"
            case "INTERMEDIATE": return "#43B02A"
            case "WET": return "#0067AD"
            default: return "#888888"
        }
    }

    function tyreLetter(compound) {
        switch (compound) {
            case "SOFT": return "S"
            case "MEDIUM": return "M"
            case "HARD": return "H"
            case "INTERMEDIATE": return "I"
            case "WET": return "W"
            default: return "?"
        }
    }

    function tyreName(compound) {
        switch (compound) {
            case "SOFT": return Translation.tr("soft")
            case "MEDIUM": return Translation.tr("medium")
            case "HARD": return Translation.tr("hard")
            case "INTERMEDIATE": return Translation.tr("intermediate")
            case "WET": return Translation.tr("wet")
            default: return compound.toLowerCase()
        }
    }

    function flagColor(f) {
        switch (f) {
            case "yellow":
            case "vsc":
            case "vscEnding": return "#FFC400"
            case "sc": return "#FF9100"
            case "red": return "#FF1744"
            default: return "#00C853"
        }
    }

    function flagLabel(f) {
        switch (f) {
            case "yellow": return Translation.tr("Yellow flag")
            case "sc": return Translation.tr("Safety Car")
            case "vsc": return Translation.tr("Virtual Safety Car")
            case "vscEnding": return Translation.tr("VSC ending")
            case "red": return Translation.tr("Red flag")
            default: return Translation.tr("Green flag")
        }
    }

    function formatCountdown(seconds) {
        const s = Math.max(0, seconds)
        const m = Math.floor(s / 60)
        return `${m}:${(s % 60).toString().padStart(2, "0")}`
    }

    function applyState(s) {
        const prevFlag = root.flag
        const prevStatus = root.sessionStatus
        const prevRc = root.raceControl?.id ?? -1
        const prevRain = root.weather?.rain ?? false
        const prevRadio = root.teamRadio?.id ?? 0
        const prevSessionKey = root.session?.key

        root.mode = s.mode ?? "idle"
        root.connected = s.connected ?? false
        root.session = s.session ?? ({})
        root.sessionStatus = s.session?.status ?? ""
        root.trackStatus = s.track?.status ?? "1"
        root.trackMessage = s.track?.message ?? ""
        root.lap = s.lap?.current ?? 0
        root.totalLaps = s.lap?.total ?? 0
        root.remaining = s.remaining ?? ""
        root.drivers = s.drivers ?? []
        root.raceControl = s.raceControl ?? null
        root.nextSession = s.next ?? null
        root.weather = s.weather ?? ({})
        root.teamRadio = s.radio ?? null
        root.nowMs = Date.now()

        if (root.initializing) {
            root.initializing = false
            root.lastFocusTyreStint = root.focusDriver?.tyreStint ?? 0
            return
        }
        if (root.sessionLive && root.flag !== prevFlag)
            root.flagEvent(root.flag)
        if (prevStatus === "Inactive" && root.sessionStatus === "Started" && root.isRace)
            root.lightsOut()
        if (root.sessionLive && root.raceControl && prevRc !== -1 && root.raceControl.id !== prevRc)
            root.newRaceControlMessage(root.raceControl)

        // Pit stop: the focused driver's compound now belongs to a newer stint
        const focus = root.focusDriver
        const tyreStint = focus?.tyreStint ?? 0
        if (root.racing && focus && root.lastFocusTyreStint > 0 && tyreStint > root.lastFocusTyreStint)
            root.tyreChange(focus)
        root.lastFocusTyreStint = tyreStint

        if (root.sessionLive && !prevRain && (root.weather?.rain ?? false))
            root.rainStarted()
        if (prevStatus === "Started" && root.sessionStatus === "Finished")
            root.sessionResult(root.drivers.slice(0, 3))

        // Team radio of the focused driver (favorite, or the leader when there is none)
        const radio = root.teamRadio
        if (root.sessionLive && radio && radio.id > prevRadio && radio.tla !== "" && radio.tla === root.focusDriver?.tla
                && (Config.options.bar.dynamicIsland.f1.teamRadio ?? true))
            root.teamRadioMessage(radio)

        if (root.session?.key !== prevSessionKey) {
            root.fastestLapMs = 0
            root.announcedLapsToGo = -1
        }

        // Blue flag waved for the focused driver
        const rc = root.raceControl
        if (root.sessionLive && rc && prevRc !== -1 && rc.id !== prevRc && rc.flag === "BLUE"
                && (rc.racingNumber ?? "") !== "" && rc.racingNumber === root.focusDriver?.num)
            root.blueFlag(root.focusDriver)

        if (root.racing && root.isRace) {
            // Fastest lap of the race so far (the first one only sets the reference)
            if (root.lap > 2) {
                let best = null
                for (const d of root.drivers) {
                    const ms = root.parseLapTime(d.best)
                    if (ms > 0 && (!best || ms < best.ms)) best = { driver: d, ms: ms }
                }
                if (best && (root.fastestLapMs === 0 || best.ms < root.fastestLapMs)) {
                    if (root.fastestLapMs > 0) root.fastestLap(best.driver, best.driver.best)
                    root.fastestLapMs = best.ms
                }
            }
            // 10 and 5 laps to go, and the final lap
            const togo = root.totalLaps - root.lap
            if (root.totalLaps > 0 && [10, 5, 0].includes(togo) && root.announcedLapsToGo !== togo) {
                root.announcedLapsToGo = togo
                root.lapsToGo(togo)
            }
        }
    }

    // Team radio clips are short audio files on the live timing server; tapping again stops playback
    function playRadio(url) {
        if (radioPlayer.running) {
            radioPlayer.running = false
            return
        }
        if (url === "") return
        radioPlayer.command = ["mpv", "--no-video", "--really-quiet", url]
        radioPlayer.running = true
    }

    Process {
        id: radioPlayer
    }

    function restartWith(args) {
        daemon.running = false
        root.daemonArgs = args
        root.initializing = true
        Qt.callLater(() => daemon.running = root.enabled)
    }

    onEnabledChanged: {
        daemon.running = root.enabled
        if (!root.enabled) {
            root.connected = false
            wakeTimer.stop()
        }
    }
    Component.onCompleted: daemon.running = root.enabled

    // The countdown only needs seconds in its last hour; before that, a tick a minute is plenty
    Timer {
        interval: root.sessionLive || (root.secondsToNext >= 0 && root.secondsToNext <= 3600) ? 1000 : 60000
        repeat: true
        running: root.nextSession !== null || root.sessionLive
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    // Passive: between race weekends there is no process at all. "live --until-idle" reports the next session and
    // exits (or, inside a session's window, streams it and exits when it's over); this single-shot timer wakes it
    // again 30 minutes before the next one. A crash inside a session's window retries after 15 s.
    readonly property int preWindowMs: 30 * 60 * 1000

    Timer {
        id: restartTimer
        interval: 15000
        onTriggered: if (root.enabled && !daemon.running) daemon.running = true
    }

    function scheduleWake() {
        if (!root.enabled || root.daemonArgs[0] !== "live") return
        const start = root.nextSession ? Date.parse(root.nextSession.start) : NaN
        if (isNaN(start)) {
            // Off-season or the schedule couldn't be fetched: look again in six hours
            wakeTimer.interval = 6 * 3600 * 1000
        } else {
            const until = start - root.preWindowMs - Date.now()
            if (until <= 0) {
                restartTimer.restart()
                return
            }
            wakeTimer.interval = Math.min(until, 2000000000)   // Timer tops out around 24.8 days
        }
        wakeTimer.restart()
    }

    Timer {
        id: wakeTimer
        onTriggered: if (root.enabled && !daemon.running) daemon.running = true
    }

    Process {
        id: daemon
        command: ["uv", "run", "--quiet", "--script", Quickshell.shellPath("scripts/f1/f1_island.py"), ...root.daemonArgs]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("{")) return
                try {
                    const s = JSON.parse(line)
                    if (s.type === "state") root.applyState(s)
                } catch (e) {
                    console.warn("[F1] Could not parse daemon output:", e)
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.log(line)
        }
        onExited: (exitCode, exitStatus) => {
            root.connected = false
            if (!root.enabled) return
            if (root.daemonArgs[0] === "live") root.scheduleWake()
            else restartTimer.restart()
        }
    }

    IpcHandler {
        target: "f1"

        function replay(path: string, speed: real): void {
            root.restartWith(["replay", path === "" ? "latest" : path, "--speed", String(speed > 0 ? speed : 1)])
        }
        function replayFrom(path: string, speed: real, start: string): void {
            root.restartWith(["replay", path === "" ? "latest" : path, "--speed", String(speed > 0 ? speed : 1), "--start", start])
        }
        function live(): void {
            root.restartWith(["live", "--until-idle"])
        }
        function forceLive(): void {
            root.restartWith(["live", "--force"])
        }
        function stop(): void {
            daemon.running = false
            root.connected = false
        }
        function status(): string {
            return JSON.stringify({ mode: root.mode, connected: root.connected, status: root.sessionStatus, flag: root.flag, lap: root.lap, totalLaps: root.totalLaps, leader: root.leader?.tla ?? "", next: root.nextSession })
        }
    }
}
