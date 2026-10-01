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

    // Fetched on demand by views, cached for hours, never polled
    property var weekend: []
    property real weekendFetchedAt: 0
    readonly property int weekendCacheMs: 6 * 3600 * 1000
    property var standings: []
    property real standingsFetchedAt: 0
    readonly property int standingsCacheMs: 6 * 3600 * 1000

    // Whole season from Jolpica/Ergast (full weekend agenda of every round), fetched once, cached for a day
    property var calendar: []
    property real calendarFetchedAt: 0
    readonly property int calendarCacheMs: 24 * 3600 * 1000

    property var resultsByRound: ({})
    property var resultsRequestedAt: ({})
    readonly property int resultsCacheMs: 24 * 3600 * 1000

    function requestWeekend() {
        if (weekendFetcher.running) return
        if (root.weekend.length > 0 && Date.now() - root.weekendFetchedAt < root.weekendCacheMs) return
        const since = new Date(Date.now() - 86400000).toISOString().split(".")[0]
        const until = new Date(Date.now() + 8 * 86400000).toISOString().split(".")[0]
        const url = `https://api.openf1.org/v1/sessions?date_end%3E${since}&date_start%3C${until}`
        weekendFetcher.command[2] = `curl -s "${url}"`
        weekendFetcher.running = true
    }

    function requestStandings() {
        if (standingsFetcher.running) return
        if (root.standings.length > 0 && Date.now() - root.standingsFetchedAt < root.standingsCacheMs) return
        standingsFetcher.command[2] = `curl -s "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"`
        standingsFetcher.running = true
    }

    function requestCalendar() {
        if (calendarFetcher.running) return
        if (root.calendar.length > 0 && Date.now() - root.calendarFetchedAt < root.calendarCacheMs) return
        calendarFetcher.command[2] = `curl -s "https://api.jolpi.ca/ergast/f1/current.json"`
        calendarFetcher.running = true
    }

    // A round asked for while another is still downloading waits here instead of being dropped
    property string pendingResultsRound: ""

    function requestResults(round) {
        if (!round) return
        const key = String(round)
        if (resultsFetcher.running) {
            if (resultsFetcher.round !== key) root.pendingResultsRound = key
            return
        }
        if (root.resultsByRound[key] && Date.now() - (root.resultsRequestedAt[key] ?? 0) < root.resultsCacheMs) return
        root.resultsRequestedAt = Object.assign({}, root.resultsRequestedAt, { [key]: Date.now() })
        resultsFetcher.round = key
        resultsFetcher.command[2] = `curl -s "https://api.jolpi.ca/ergast/f1/current/${key}/results.json"`
        resultsFetcher.running = true
    }

    Process {
        id: weekendFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const rows = JSON.parse(text)
                    if (!Array.isArray(rows) || rows.length === 0) return
                    const now = Date.now()
                    const upcoming = rows.filter(r => Date.parse(r.date_end) > now)
                        .sort((a, b) => Date.parse(a.date_start) - Date.parse(b.date_start))
                    if (upcoming.length === 0) return
                    const key = upcoming[0].meeting_key
                    root.weekend = rows.filter(r => r.meeting_key === key)
                        .sort((a, b) => Date.parse(a.date_start) - Date.parse(b.date_start))
                        .map(r => ({ name: r.session_name, type: r.session_type, start: r.date_start, end: r.date_end }))
                    root.weekendFetchedAt = now
                } catch (e) {
                    console.warn("[F1] weekend parse error:", e)
                }
            }
        }
    }

    Process {
        id: standingsFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const parsed = JSON.parse(text)
                    const list = parsed?.MRData?.StandingsTable?.StandingsLists?.[0]?.DriverStandings ?? []
                    root.standings = list.slice(0, 5).map(d => ({
                        pos: d.position ?? "",
                        code: d.Driver?.code || (d.Driver?.familyName ?? "").slice(0, 3).toUpperCase(),
                        points: d.points ?? "",
                        team: d.Constructors?.[0]?.name ?? ""
                    }))
                    root.standingsFetchedAt = Date.now()
                } catch (e) {
                    console.warn("[F1] standings parse error:", e)
                }
            }
        }
    }

    Process {
        id: calendarFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const races = JSON.parse(text)?.MRData?.RaceTable?.Races ?? []
                    // Ergast's session keys, in weekend order; already the labels weekendShortLabel() expects
                    const sessionFields = [
                        ["FirstPractice", "Practice 1"], ["SecondPractice", "Practice 2"], ["ThirdPractice", "Practice 3"],
                        ["SprintQualifying", "Sprint Qualifying"], ["SprintShootout", "Sprint Qualifying"], ["Sprint", "Sprint"],
                        ["Qualifying", "Qualifying"]
                    ]
                    root.calendar = races.map(r => {
                        const sessions = []
                        for (const [key, label] of sessionFields) {
                            const s = r[key]
                            if (s?.date) sessions.push({ name: label, start: `${s.date}T${s.time ?? "00:00:00Z"}` })
                        }
                        sessions.push({ name: "Race", start: `${r.date}T${r.time ?? "00:00:00Z"}` })
                        sessions.sort((a, b) => Date.parse(a.start) - Date.parse(b.start))
                        return {
                            round: r.round, name: r.raceName,
                            circuit: r.Circuit?.Location?.locality ?? r.Circuit?.circuitName ?? "",
                            country: r.Circuit?.Location?.country ?? "",
                            raceDate: `${r.date}T${r.time ?? "00:00:00Z"}`,
                            sessions: sessions
                        }
                    })
                    root.calendarFetchedAt = Date.now()
                } catch (e) {
                    console.warn("[F1] calendar parse error:", e)
                }
            }
        }
    }

    Process {
        id: resultsFetcher
        property string round: ""
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const race = JSON.parse(text)?.MRData?.RaceTable?.Races?.[0]
                    const rows = (race?.Results ?? []).map(res => ({
                        pos: res.position ?? "",
                        code: res.Driver?.code || (res.Driver?.familyName ?? "").slice(0, 3).toUpperCase(),
                        team: res.Constructor?.name ?? "",
                        points: res.points ?? "0",
                        gap: res.Time?.time ?? (res.status ?? ""),
                        winner: res.position === "1"
                    }))
                    root.resultsByRound = Object.assign({}, root.resultsByRound, { [resultsFetcher.round]: rows })
                } catch (e) {
                    console.warn("[F1] results parse error:", e)
                }
            }
        }
        onExited: {
            const next = root.pendingResultsRound
            root.pendingResultsRound = ""
            if (next !== "") Qt.callLater(() => root.requestResults(next))
        }
    }

    readonly property bool sessionLive: root.connected && ["Inactive", "Started", "Aborted", "Finished"].includes(root.sessionStatus)
    readonly property bool racing: root.connected && root.sessionStatus === "Started"
    readonly property bool isRace: (root.session?.type ?? "") === "Race"
    readonly property var leader: root.drivers.length > 0 ? root.drivers[0] : null
    readonly property var focusDriver: root.drivers.find(d => d.tla === root.favoriteDriver) ?? root.leader

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

    function sessionLabel(name) {
        if (!name) return ""
        const practice = name.match(/^Practice (\d)$/)
        if (practice) return Translation.tr("Practice %1").arg(practice[1])
        switch (name) {
            case "Race":              return Translation.tr("Race")
            case "Qualifying":        return Translation.tr("Qualifying")
            case "Sprint":            return "Sprint"
            case "Sprint Qualifying":
            case "Sprint Shootout":   return Translation.tr("Sprint qualifying")
            default:                  return name
        }
    }

    function humanCountdown(seconds) {
        if (seconds <= 0) return ""
        const d = Math.floor(seconds / 86400)
        const h = Math.floor(seconds % 86400 / 3600)
        const m = Math.floor(seconds % 3600 / 60)
        if (d > 0) return `${d}d ${h}h`
        if (h > 0) return `${h}h ${String(m).padStart(2, "0")}min`
        return `${Math.max(1, m)}min`
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

        const focus = root.focusDriver
        const tyreStint = focus?.tyreStint ?? 0
        if (root.racing && focus && root.lastFocusTyreStint > 0 && tyreStint > root.lastFocusTyreStint)
            root.tyreChange(focus)
        root.lastFocusTyreStint = tyreStint

        if (root.sessionLive && !prevRain && (root.weather?.rain ?? false))
            root.rainStarted()
        if (prevStatus === "Started" && root.sessionStatus === "Finished")
            root.sessionResult(root.drivers.slice(0, 3))

        const radio = root.teamRadio
        if (root.sessionLive && radio && radio.id > prevRadio && radio.tla !== "" && radio.tla === root.focusDriver?.tla
                && (Config.options.bar.dynamicIsland.f1.teamRadio ?? true))
            root.teamRadioMessage(radio)

        if (root.session?.key !== prevSessionKey) {
            root.fastestLapMs = 0
            root.announcedLapsToGo = -1
        }

        const rc = root.raceControl
        if (root.sessionLive && rc && prevRc !== -1 && rc.id !== prevRc && rc.flag === "BLUE"
                && (rc.racingNumber ?? "") !== "" && rc.racingNumber === root.focusDriver?.num)
            root.blueFlag(root.focusDriver)

        if (root.racing && root.isRace) {
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
            const togo = root.totalLaps - root.lap
            if (root.totalLaps > 0 && [10, 5, 0].includes(togo) && root.announcedLapsToGo !== togo) {
                root.announcedLapsToGo = togo
                root.lapsToGo(togo)
            }
        }
    }

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

    Timer {
        interval: root.sessionLive || (root.secondsToNext >= 0 && root.secondsToNext <= 3600) ? 1000 : 60000
        repeat: true
        running: root.nextSession !== null || root.sessionLive
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    // "live --until-idle" reports the next session and exits, or streams the session and exits when it ends;
    // this single-shot timer restarts it 30 min before the next one. A crash inside a session retries after 15 s.
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
            wakeTimer.interval = 6 * 3600 * 1000
        } else {
            const until = start - root.preWindowMs - Date.now()
            if (until <= 0) {
                restartTimer.restart()
                return
            }
            wakeTimer.interval = Math.min(until, 2000000000)
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
