pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string scriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/football/football.py`
    readonly property string cachePath: `${Quickshell.env("HOME")}/.cache/quickshell/football/matches.json`
    readonly property real staleAfterMs: 6 * 60 * 60 * 1000
    readonly property var fb: Config.options.sidebar.football
    readonly property string defaultGoalSound: Quickshell.shellPath("assets/sounds/football-goal.ogg")
    readonly property string defaultCornerSound: Quickshell.shellPath("assets/sounds/football-corner.ogg")
    readonly property bool trackingEnabled: root.fb.enable && root.fb.alerts
    property var lastLive: ({})
    property var formByTeam: ({})
    property string formQueue: ""
    property var positionsByLeague: ({})
    property var standingsByLeague: ({})
    property string standingsLeague: ""
    property bool standingsLoading: false
    property bool standingsFailed: false
    property string standingsQueued: ""

    property var matches: []
    property real generatedAt: 0
    property bool loading: false
    property bool failed: false
    property bool loadedOnce: false

    readonly property bool stale: Date.now() - root.generatedAt > root.staleAfterMs

    readonly property var days: {
        const todayKey = root.dayKey(new Date());
        const map = {};
        root.matches.forEach(match => {
            const date = new Date(match.date);
            const key = root.dayKey(date);
            if (key < todayKey) return;
            if (!map[key]) map[key] = { key: key, date: date, matches: [] };
            map[key].matches.push(match);
        });
        return Object.values(map).sort((a, b) => a.key < b.key ? -1 : 1);
    }

    function dayKey(date) {
        const month = String(date.getMonth() + 1).padStart(2, "0");
        const day = String(date.getDate()).padStart(2, "0");
        return `${date.getFullYear()}-${month}-${day}`;
    }

    function ensureFresh() {
        if (root.loading) return;
        if (root.stale || root.matches.length === 0) root.refresh();
    }

    function refresh() {
        if (fetchProc.running) return;
        root.loading = true;
        root.failed = false;
        fetchProc.running = true;
    }

    function apply(raw) {
        try {
            const data = JSON.parse(raw);
            root.matches = data.matches ?? [];
            root.generatedAt = new Date(data.generated).getTime();
            root.loadedOnce = true;
            root.loadPositions();
            return true;
        } catch (e) {
            return false;
        }
    }

    function bestResult(probs) {
        const entries = [["home", probs.home], ["draw", probs.draw], ["away", probs.away]];
        return entries.reduce((best, entry) => entry[1] > best[1] ? entry : best);
    }

    function bestOf(probs, keys) {
        return keys.reduce((best, key) => probs[key] > probs[best] ? key : best, keys[0]);
    }

    function candidateFor(match, markets) {
        if (!match.probs || match.state !== "pre") return null;
        const options = [];
        if (markets.result) {
            const best = root.bestResult(match.probs);
            options.push({ type: "result", pick: best[0], prob: best[1] });
        }
        if (markets.goals) {
            const key = root.bestOf(match.probs, ["o15", "o25"]);
            options.push({ type: "goals", pick: key, prob: match.probs[key] });
        }
        if (markets.corners) {
            const key = root.bestOf(match.probs, ["c85", "c95", "c105"]);
            options.push({ type: "corners", pick: key, prob: match.probs[key] });
        }
        if (options.length === 0) return null;
        const best = options.reduce((top, option) => option.prob > top.prob ? option : top);
        return Object.assign({ match: match }, best);
    }

    function typeCandidates(match, type, ignoreState) {
        if (!match.probs || (!ignoreState && match.state !== "pre")) return null;
        if (type === "result") {
            const best = root.bestResult(match.probs);
            return { match: match, type: type, pick: best[0], prob: best[1] };
        }
        const keys = type === "goals" ? ["o15", "o25"] : ["c85", "c95", "c105"];
        const key = root.bestOf(match.probs, keys);
        return { match: match, type: type, pick: key, prob: match.probs[key] };
    }

    function buildParlay(dayMatches, legs, markets, ignoreState) {
        const types = ["result", "goals", "corners"].filter(type => markets[type]);
        const byType = {};
        types.forEach(type => {
            byType[type] = dayMatches.map(match => root.typeCandidates(match, type, ignoreState === true)).filter(candidate => candidate !== null).sort((a, b) => b.prob - a.prob);
        });
        const order = types.slice().sort((a, b) => (byType[b][0]?.prob ?? 0) - (byType[a][0]?.prob ?? 0));
        const quota = {};
        order.forEach((type, index) => { quota[type] = Math.floor(legs / order.length) + (index < legs % order.length ? 1 : 0); });

        const used = new Set();
        const chosen = [];
        order.forEach(type => {
            let taken = 0;
            for (const candidate of byType[type]) {
                if (taken >= quota[type]) break;
                if (used.has(candidate.match.id)) continue;
                used.add(candidate.match.id);
                chosen.push(candidate);
                taken++;
            }
        });
        if (chosen.length < legs) {
            const rest = [];
            order.forEach(type => byType[type].forEach(candidate => { if (!used.has(candidate.match.id)) rest.push(candidate); }));
            rest.sort((a, b) => b.prob - a.prob);
            for (const candidate of rest) {
                if (chosen.length >= legs) break;
                if (used.has(candidate.match.id)) continue;
                used.add(candidate.match.id);
                chosen.push(candidate);
            }
        }
        chosen.sort((a, b) => b.prob - a.prob);
        const combined = chosen.reduce((total, leg) => total * leg.prob, 1);
        return { legs: chosen, combined: chosen.length > 0 ? combined : 0, odds: combined > 0 ? 1 / combined : 0 };
    }

    readonly property var trackedSet: {
        const ids = new Set();
        if (root.fb.alertsScope === "all") {
            root.matches.forEach(match => ids.add(match.id));
            return ids;
        }
        const markets = {
            result: root.fb.markets.indexOf("result") >= 0,
            goals: root.fb.markets.indexOf("goals") >= 0,
            corners: root.fb.markets.indexOf("corners") >= 0
        };
        const byDay = {};
        root.matches.forEach(match => {
            const key = root.dayKey(new Date(match.date));
            if (!byDay[key]) byDay[key] = [];
            byDay[key].push(match);
        });
        Object.values(byDay).forEach(dayMatches => {
            root.buildParlay(dayMatches, root.fb.legs, markets, true).legs.forEach(leg => ids.add(leg.match.id));
        });
        return ids;
    }

    function isLiveish(match) {
        if (match.state === "in") return true;
        if (match.state !== "pre") return false;
        const kickoff = new Date(match.date).getTime();
        const now = Date.now();
        return kickoff <= now + 2 * 60 * 1000 && kickoff > now - 4 * 3600 * 1000;
    }

    readonly property bool liveActive: root.trackingEnabled && root.matches.some(match => root.isLiveish(match) && root.trackedSet.has(match.id))

    readonly property real nextKickoffMs: {
        const now = Date.now();
        let best = 0;
        root.matches.forEach(match => {
            if (match.state !== "pre" || !root.trackedSet.has(match.id)) return;
            const kickoff = new Date(match.date).getTime();
            if (kickoff > now && (best === 0 || kickoff < best)) best = kickoff;
        });
        return best;
    }

    function load() {
        cacheFile.reload();
    }

    function positionOf(leagueId, teamId) {
        return root.positionsByLeague[leagueId]?.[teamId] ?? 0;
    }

    function loadForm(leagueId, teamIds) {
        const missing = teamIds.filter(id => root.formByTeam[id] === undefined);
        if (missing.length === 0) return;
        if (formProc.running) {
            root.formQueue = leagueId + "|" + missing.join(",");
            return;
        }
        formProc.command = ["python3", "-I", root.scriptPath, "--form", leagueId, missing.join(",")];
        formProc.running = true;
    }

    function loadPositions() {
        if (positionsProc.running) return;
        positionsProc.running = true;
    }

    function loadStandings(leagueId) {
        root.standingsLeague = leagueId;
        root.standingsFailed = false;
        if (standingsProc.running) {
            root.standingsQueued = leagueId;
            return;
        }
        root.standingsLoading = true;
        standingsProc.command = ["python3", "-I", root.scriptPath, "--standings", leagueId];
        standingsProc.running = true;
    }

    function pollLive() {
        if (pollProc.running) return;
        pollProc.running = true;
    }

    function expandPath(path) {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.substring(1) : path.replace(/^file:\/\//, "");
    }

    function playSound(path, fallback) {
        const file = path.trim() !== "" ? root.expandPath(path.trim()) : fallback;
        Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-volume", String(root.fb.soundVolume), file]);
    }

    function announceGoal(match, side) {
        if (root.fb.goalSound) root.playSound(root.fb.goalSoundPath, root.defaultGoalSound);
        if (!root.fb.notify) return;
        const scorer = side === "home" ? match.home.name : match.away.name;
        Quickshell.execDetached(["notify-send", "-a", "Football", Translation.tr("GOAL! %1").arg(scorer), `${match.home.name} ${match.home.score} – ${match.away.score} ${match.away.name} · ${match.detail}`]);
    }

    function announceCorner() {
        if (root.fb.cornerSound) root.playSound(root.fb.cornerSoundPath, root.defaultCornerSound);
    }

    function applyLive(updates) {
        const byId = {};
        updates.forEach(update => { byId[update.id] = update; });
        const snapshot = Object.assign({}, root.lastLive);
        const merged = root.matches.map(match => {
            const update = byId[match.id];
            if (!update) return match;
            const previousState = match.state;
            const next = Object.assign({}, match, {
                state: update.state,
                detail: update.detail,
                home: Object.assign({}, match.home, { score: update.home.score }),
                away: Object.assign({}, match.away, { score: update.away.score })
            });
            const tracked = root.trackedSet.has(match.id);
            const homeScore = parseInt(update.home.score) || 0;
            const awayScore = parseInt(update.away.score) || 0;
            const homeCorners = update.corners.home;
            const awayCorners = update.corners.away;
            let before = snapshot[match.id];
            if (!before && previousState === "pre") before = { hs: 0, as: 0, hc: 0, ac: 0 };
            if (before && tracked) {
                for (let n = before.hs; n < homeScore; n++) root.announceGoal(next, "home");
                for (let n = before.as; n < awayScore; n++) root.announceGoal(next, "away");
                if (homeCorners !== null && homeCorners > before.hc) root.announceCorner();
                if (awayCorners !== null && awayCorners > before.ac) root.announceCorner();
            }
            if (update.state === "in") {
                snapshot[match.id] = {
                    hs: homeScore,
                    as: awayScore,
                    hc: homeCorners ?? before?.hc ?? 0,
                    ac: awayCorners ?? before?.ac ?? 0
                };
            } else {
                delete snapshot[match.id];
            }
            return next;
        });
        root.lastLive = snapshot;
        root.matches = merged;
    }

    Timer {
        id: livePollTimer
        interval: 45000
        repeat: true
        running: root.liveActive
        onTriggered: root.pollLive()
    }

    Timer {
        id: kickoffTimer
        interval: Math.min(2147483000, Math.max(1000, root.nextKickoffMs - Date.now() + 3000))
        running: root.trackingEnabled && !root.liveActive && root.nextKickoffMs > 0
        onTriggered: root.pollLive()
    }

    Process {
        id: formProc
        stdout: StdioCollector {
            id: formOut
        }
        onExited: code => {
            try {
                const data = JSON.parse(formOut.text);
                root.formByTeam = Object.assign({}, root.formByTeam, data);
            } catch (e) {}
            if (root.formQueue !== "") {
                const parts = root.formQueue.split("|");
                root.formQueue = "";
                root.loadForm(parts[0], parts[1].split(","));
            }
        }
    }

    Process {
        id: positionsProc
        command: ["python3", "-I", root.scriptPath, "--positions"]
        stdout: StdioCollector {
            id: positionsOut
        }
        onExited: code => {
            if (code !== 0) return;
            try {
                root.positionsByLeague = JSON.parse(positionsOut.text);
            } catch (e) {}
        }
    }

    Process {
        id: standingsProc
        stdout: StdioCollector {
            id: standingsOut
        }
        onExited: code => {
            root.standingsLoading = false;
            try {
                const data = JSON.parse(standingsOut.text);
                if (code !== 0 || !data.groups || data.groups.length === 0) throw new Error("empty");
                const next = Object.assign({}, root.standingsByLeague);
                next[data.league] = data.groups;
                root.standingsByLeague = next;
            } catch (e) {
                root.standingsFailed = true;
            }
            if (root.standingsQueued !== "") {
                const queued = root.standingsQueued;
                root.standingsQueued = "";
                if (queued !== root.standingsLeague || root.standingsByLeague[queued] === undefined) root.loadStandings(queued);
            }
        }
    }

    Process {
        id: pollProc
        command: ["python3", "-I", root.scriptPath, "--live"]
        stdout: StdioCollector {
            id: pollOut
        }
        onExited: code => {
            if (code !== 0) return;
            try {
                root.applyLive(JSON.parse(pollOut.text).updates ?? []);
            } catch (e) {}
        }
    }

    Component.onCompleted: cacheFile.reload()

    FileView {
        id: cacheFile
        path: root.cachePath
        printErrors: false
        onLoaded: {
            root.apply(cacheFile.text());
        }
    }

    Process {
        id: fetchProc
        command: ["python3", "-I", root.scriptPath]
        stdout: StdioCollector {
            id: fetchOut
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 || !root.apply(fetchOut.text)) root.failed = root.matches.length === 0;
        }
    }
}
