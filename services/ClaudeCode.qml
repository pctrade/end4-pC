pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// AI agent sessions on the island: Claude Code, Codex and Gemini (Antigravity CLI). Hooks
// (scripts/island/claude-island.sh and agent-island.sh) report what each session is doing; Claude's statusline
// cache and Codex's session rollouts report context size, model and plan usage.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && (Config.options.bar.dynamicIsland.claudeCode ?? true)
    readonly property int doneMinSeconds: Config.options.bar.dynamicIsland.claudeDoneMinSeconds ?? 20
    readonly property string home: Quickshell.env("HOME")

    readonly property var agentNames: ({ claude: "Claude", codex: "Codex", gemini: "Gemini" })

    function agentColor(agent) {
        switch (agent) {
            case "codex": return Appearance.colors.colOnLayer0
            case "gemini": return "#6F8CF5"
            default: return "#D97757"
        }
    }

    // key -> { key, agent, realId, cwd, project, state: idle|working|waiting|ended, detail, workStarted, shown, termPid,
    //          question, options, waitingText, summary, diff, model, context, contextWarned, updated }
    property var sessions: ({})
    property var claudeIds: []
    readonly property var sessionList: Object.values(root.sessions)
        .sort((a, b) => ((a.state === "ended") - (b.state === "ended")) || ((b.updated ?? 0) - (a.updated ?? 0)))
    readonly property var liveSessions: root.sessionList.filter(s => s.state !== "ended")
    readonly property int openCount: root.liveSessions.length
    readonly property bool anyWorking: root.liveSessions.some(s => s.state === "working")
    readonly property bool anyWaiting: root.liveSessions.some(s => s.state === "waiting")
    // A session stopped on a permission dialog: the island treats it as CRITICAL (ahead of everything, even over a
    // fullscreen window) and answers it from the pill (approve / deny), see DiApproval.qml
    readonly property var approval: root.liveSessions.find(s => s.state === "waiting" && (s.permission ?? "") !== "" && !s.approvalHidden) ?? null
    readonly property var openAgents: ["claude", "codex", "gemini"].filter(a => root.liveSessions.some(s => s.agent === a))

    // agent -> { five, fiveReset, week, weekReset } (percent used, unix seconds)
    property var limits: ({})
    readonly property real fiveHourUsed: root.limits.claude?.five ?? -1
    readonly property string fiveHourReset: root.formatReset(root.limits.claude?.fiveReset)
    property var warned: ({})
    property bool groupedWaiting: false
    property var alivePids: []

    function formatReset(ts) {
        return ts ? Qt.formatTime(new Date(ts * 1000), "hh:mm") : ""
    }

    function keyFor(agent, sid) {
        return agent === "claude" ? sid : `${agent}:${sid}`
    }

    function projectName(cwd) {
        return (cwd ?? "").split("/").filter(Boolean).pop() || "~"
    }

    function activityId(key) {
        return `agent-${key}`
    }

    function titleFor(session) {
        return `${root.agentNames[session?.agent] ?? "Agent"} · ${session?.project ?? "~"}`
    }

    function formatDuration(ms) {
        const s = Math.round(ms / 1000)
        if (s < 60) return `${s}s`
        const m = Math.floor(s / 60)
        if (m < 60) return `${m} min ${s % 60}s`
        return `${Math.floor(m / 60)}h${(m % 60).toString().padStart(2, "0")}`
    }

    // "120,34,5" -> "+120 −34 · 5 files"
    function formatDiff(diff) {
        const m = /^(\d+),(\d+),(\d+)$/.exec((diff ?? "").trim())
        if (!m) return ""
        return `+${m[1]} −${m[2]} · ${Translation.tr("%1 files").arg(m[3])}`
    }

    function toolLabel(detail) {
        const parts = (detail ?? "").split("\t")
        const tool = parts[0] ?? ""
        const arg = parts.slice(1).join(" ").trim()
        const withArg = label => arg !== "" ? `${label} ${arg}` : label
        switch (tool) {
            case "Bash":
            case "shell":
            case "exec_command":
            case "run_command": return arg !== "" ? arg : Translation.tr("Running a command")
            case "Edit":
            case "Write":
            case "MultiEdit":
            case "NotebookEdit":
            case "apply_patch":
            case "write_file":
            case "replace": return withArg(Translation.tr("Editing"))
            case "Read":
            case "read_file": return withArg(Translation.tr("Reading"))
            case "Grep":
            case "Glob":
            case "search": return withArg(Translation.tr("Searching"))
            case "WebFetch":
            case "WebSearch":
            case "web_search": return withArg(Translation.tr("Browsing"))
            case "Agent":
            case "Task": return withArg(Translation.tr("Subagent"))
            case "TodoWrite":
            case "update_plan": return Translation.tr("Planning")
            default: return tool.startsWith("mcp__") ? tool.split("__").slice(1).join(" · ") : withArg(tool)
        }
    }

    function update(key, cwd, changes) {
        const base = root.sessions[key] ?? { key: key, agent: "claude", realId: key, cwd: "", project: "~", state: "idle", detail: "",
            workStarted: 0, shown: false, termPid: 0, question: "", options: [], waitingText: "", summary: "", diff: "", model: "",
            context: -1, contextWarned: false }
        const next = Object.assign({}, base, changes, { updated: Date.now() })
        if (cwd) {
            next.cwd = cwd
            next.project = root.projectName(cwd)
        }
        root.sessions = Object.assign({}, root.sessions, { [key]: next })
        return next
    }

    function ensure(agent, sid, cwd) {
        const key = root.keyFor(agent, sid)
        if (!root.sessions[key]) {
            root.update(key, cwd, { key: key, agent: agent, realId: sid })
            if (agent === "claude") root.claudeIds = [...root.claudeIds, sid]
        }
        return key
    }

    function forget(key) {
        const s = root.sessions[key]
        const copy = Object.assign({}, root.sessions)
        delete copy[key]
        root.sessions = copy
        if (s?.agent === "claude") root.claudeIds = root.claudeIds.filter(id => id !== s.realId)
        IslandEvents.removeActivity(root.activityId(key))
    }

    // Closed sessions stay listed for a while so they can be resumed
    function end(key) {
        if (!root.sessions[key]) return
        IslandEvents.removeActivity(root.activityId(key))
        root.update(key, "", { state: "ended", options: [], question: "", shown: false })
        const ended = root.sessionList.filter(s => s.state === "ended")
        for (const old of ended.slice(4)) root.forget(old.key)
    }

    function windowAlive(session) {
        return (session?.termPid ?? 0) > 0 && root.alivePids.includes(session.termPid)
    }

    function refreshWindows() {
        if (!windowsProc.running) windowsProc.running = true
    }

    Process {
        id: windowsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.alivePids = JSON.parse(text).map(c => c.pid)
                } catch (e) {}
            }
        }
    }

    // Brings the session's terminal window forward
    function focusSession(key) {
        IslandEvents.focusWindowPid(root.sessions[key]?.termPid ?? 0)
    }

    // Opens the session again in a new terminal at its folder
    function resume(key) {
        const s = root.sessions[key]
        if (!s) return
        const command = s.agent === "codex" ? ["codex", "resume", s.realId]
            : s.agent === "gemini" ? (s.realId.startsWith("pid-") ? ["agy", "-c"] : ["agy", "--conversation", s.realId])
            : ["claude", "--resume", s.realId]
        Quickshell.execDetached(["foot", "--working-directory", s.cwd || root.home, ...command])
        root.forget(key)
    }

    // What changed in the repository, in lazygit
    function openDiff(key) {
        const s = root.sessions[key]
        if (!s?.cwd) return
        Quickshell.execDetached(["foot", "--working-directory", s.cwd, "lazygit"])
    }

    // Answers the pending question: its number key, sent straight to the session's terminal window
    function answer(key, index) {
        const pid = root.sessions[key]?.termPid ?? 0
        if (pid <= 0) return
        IslandEvents.hyprDispatch(`hl.dsp.send_shortcut({ mods = "", key = "${index + 1}", window = "pid:${pid}" })`)
        root.update(key, "", { options: [], question: "", state: "working" })
        root.syncWorking(key)
        root.updateWaitingGroup()
    }

    // Permission dialogs, answered in the session's own terminal: "1" (Claude, Gemini) / "y" (Codex) approves
    // once, Escape denies. Nothing is typed if the terminal isn't known.
    function approve(key) {
        const s = root.sessions[key]
        if (!s) return
        // Terminal unknown: nothing to type into — step aside so it can be answered where it is
        if ((s.termPid ?? 0) <= 0) {
            root.hideApproval(key)
            return
        }
        IslandEvents.hyprDispatch(`hl.dsp.send_shortcut({ mods = "", key = "${s.agent === "codex" ? "y" : "1"}", window = "pid:${s.termPid}" })`)
        root.update(key, "", { state: "working", permission: "", approvalHidden: false, workStarted: s.workStarted || Date.now() })
        root.syncWorking(key)
        root.updateWaitingGroup()
    }
    function deny(key) {
        const s = root.sessions[key]
        if (!s) return
        if ((s.termPid ?? 0) <= 0) {
            root.hideApproval(key)
            return
        }
        IslandEvents.hyprDispatch(`hl.dsp.send_shortcut({ mods = "", key = "Escape", window = "pid:${s.termPid}" })`)
        root.update(key, "", { state: "idle", permission: "", approvalHidden: false })
        IslandEvents.upsertActivity(root.activityId(key), root.titleFor(root.sessions[key]), Translation.tr("Denied"), s.agent, -1, "error")
        root.updateWaitingGroup()
    }
    // "Later": back to an ordinary waiting activity (still in Agents), no longer blocking the pill
    function hideApproval(key) {
        root.update(key, "", { approvalHidden: true })
    }

    // Work shows up after a few seconds, so quick back-and-forth answers don't flash the island
    function syncWorking(key) {
        const s = root.sessions[key]
        if (!s || s.state !== "working") return
        if (!s.shown && Date.now() - s.workStarted < 3000) return
        if (!s.shown) root.update(key, "", { shown: true })
        IslandEvents.upsertActivity(root.activityId(key), root.titleFor(s), s.detail || Translation.tr("Thinking…"), s.agent, -1, "running")
    }

    function needsYou(key, cwd, subtitle, extra) {
        const s = root.update(key, cwd, Object.assign({ state: "waiting", shown: true, waitingText: subtitle }, extra ?? {}))
        IslandEvents.upsertActivity(root.activityId(key), root.titleFor(s), subtitle, s.agent, -1, "attention")
    }

    // Two or more agents waiting: one "N agents waiting" instead of a pile of separate alerts
    function updateWaitingGroup() {
        const waiting = root.liveSessions.filter(s => s.state === "waiting")
        if (waiting.length >= 2) {
            for (const s of waiting) IslandEvents.removeActivity(root.activityId(s.key))
            IslandEvents.upsertActivity("agents-waiting", Translation.tr("%1 agents waiting for you").arg(waiting.length),
                waiting.map(s => `${root.agentNames[s.agent]} · ${s.project}`).join(", "), "front_hand", -1, "attention")
            root.groupedWaiting = true
        } else if (root.groupedWaiting) {
            IslandEvents.removeActivity("agents-waiting")
            root.groupedWaiting = false
            for (const s of waiting) IslandEvents.upsertActivity(root.activityId(s.key), root.titleFor(s), s.waitingText, s.agent, -1, "attention")
        }
    }

    // Runs `show` unless the given terminal is the focused window (then `skip`): no need to announce what you're looking at
    property var focusQueue: []

    function unlessTerminalFocused(pid, show, skip) {
        if (!(pid > 0)) {
            show()
            return
        }
        root.focusQueue = [...root.focusQueue, { pid: pid, show: show, skip: skip }]
        if (!activeWindowProc.running) activeWindowProc.running = true
    }

    Process {
        id: activeWindowProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let active = -1
                try {
                    active = JSON.parse(text).pid ?? -1
                } catch (e) {}
                const queue = root.focusQueue
                root.focusQueue = []
                for (const item of queue) (item.pid === active ? item.skip : item.show)()
            }
        }
    }

    function handle(agent, name, sid, cwd, detail, termPid) {
        if (!root.enabled || sid === "") return
        // Antigravity calls the start of each model call PreInvocation: only the first one starts a turn
        if (agent === "gemini") {
            if (name === "PreInvocation") name = root.sessions[root.keyFor(agent, sid)]?.state === "working" ? "" : "UserPromptSubmit"
            else if (name === "PostInvocation") name = ""
        }
        if (name === "") return
        const key = root.ensure(agent, sid, cwd)
        const parts = (detail ?? "").split("\t")
        const kind = parts[0] ?? ""
        const text = parts.slice(1).join(" ").trim()
        if (termPid > 0 && name !== "SessionEnd" && root.sessions[key]?.termPid !== termPid) root.update(key, cwd, { termPid: termPid })

        switch (name) {
            case "SessionStart":
                root.update(key, cwd, { state: "idle", detail: "" })
                break
            case "UserPromptSubmit":
                root.update(key, cwd, { state: "working", detail: "", workStarted: Date.now(), shown: false, options: [], question: "", diff: "", permission: "", approvalHidden: false })
                root.syncWorking(key)
                break
            case "PreToolUse":
            case "PostToolUse": {
                if (name === "PreToolUse" && kind === "AskUserQuestion") {
                    const question = parts[1] ?? ""
                    root.needsYou(key, cwd, `${Translation.tr("Question")}: ${question || Translation.tr("waiting for you")}`,
                        { question: question, options: (parts[2] ?? "").split("").filter(Boolean) })
                    break
                }
                const s = root.sessions[key]
                const working = s?.state === "working" || s?.state === "waiting"
                const changes = { state: "working", workStarted: working && s.workStarted ? s.workStarted : Date.now(), options: [], question: "", pendingPermission: "",
                    permission: "", approvalHidden: false }
                if (name === "PreToolUse" || !working) changes.detail = root.toolLabel(detail)
                root.update(key, cwd, changes)
                root.syncWorking(key)
                break
            }
            case "PermissionRequest":
                // Claude also reports the dialog itself (Notification permission_prompt): only then is it really waiting.
                // Codex and Gemini have no such event, so their request counts right away.
                if (agent === "claude") {
                    root.update(key, cwd, { pendingPermission: root.toolLabel(detail) })
                    break
                }
                root.needsYou(key, cwd, `${Translation.tr("Needs permission")}: ${root.toolLabel(detail)}`,
                    { permission: root.toolLabel(detail) || Translation.tr("an action"), approvalHidden: false })
                break
            case "Notification":
                if (!["permission_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input"].includes(kind)) break
                if (root.sessions[key]?.state === "waiting") break
                const pending = root.sessions[key]?.pendingPermission ?? ""
                root.needsYou(key, cwd, kind === "permission_prompt" && pending !== ""
                    ? `${Translation.tr("Needs permission")}: ${pending}` : (text || Translation.tr("Waiting for you")),
                    kind === "permission_prompt" ? { permission: pending || text || Translation.tr("an action"), approvalHidden: false } : undefined)
                break
            case "PreCompact":
                root.update(key, cwd, { state: "working", detail: Translation.tr("Compacting context…"), contextWarned: false,
                    workStarted: root.sessions[key]?.workStarted || Date.now() })
                root.syncWorking(key)
                break
            case "Stop": {
                const s = root.sessions[key]
                const took = s?.workStarted ? Date.now() - s.workStarted : 0
                const [summary, diff] = (detail ?? "").split("")
                const next = root.update(key, cwd, { state: "idle", detail: "", shown: false, options: [], question: "",
                    summary: (summary ?? "").trim(), diff: (diff ?? "").trim(), permission: "" })
                if (!(s?.shown || took >= root.doneMinSeconds * 1000)) {
                    IslandEvents.removeActivity(root.activityId(key))
                    break
                }
                const subtitle = [took > 0 ? `${Translation.tr("Done")} · ${root.formatDuration(took)}` : Translation.tr("Done"),
                    root.formatDiff(next.diff) || next.summary].filter(Boolean).join(" · ")
                root.unlessTerminalFocused(next.termPid,
                    () => IslandEvents.upsertActivity(root.activityId(key), root.titleFor(next), subtitle, next.agent, 1, "done"),
                    () => IslandEvents.removeActivity(root.activityId(key)))
                break
            }
            case "StopFailure": {
                const next = root.update(key, cwd, { state: "idle", detail: "", shown: false, options: [], question: "" })
                const message = kind === "rate_limit" ? Translation.tr("Usage limit reached")
                    : kind === "overloaded" ? Translation.tr("Servers overloaded") : (text || kind)
                IslandEvents.upsertActivity(root.activityId(key), root.titleFor(next), message, next.agent, -1, "error")
                break
            }
            case "SessionEnd":
                root.end(key)
                break
        }
        root.updateWaitingGroup()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.anyWorking
        onTriggered: {
            for (const s of root.liveSessions) {
                if (s.state === "working" && !s.shown) root.syncWorking(s.key)
            }
        }
    }

    // Sessions killed without SessionEnd fade away after a long silence; closed ones after a few hours
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: root.sessionList.length > 0
        onTriggered: {
            const now = Date.now()
            for (const s of root.sessionList) {
                if (s.state === "ended" ? now - s.updated > 3 * 3600 * 1000 : (s.state !== "working" && now - s.updated > 12 * 3600 * 1000))
                    root.forget(s.key)
            }
        }
    }

    // Short notices (usage and context) share one slot and clear themselves
    function notice(key, title, subtitle, icon, state) {
        if (root.warned[key]) return
        root.warned = Object.assign({}, root.warned, { [key]: true })
        IslandEvents.upsertActivity("agents-notice", title, subtitle, icon, -1, state)
        noticeTimer.restart()
    }

    Timer {
        id: noticeTimer
        interval: 12000
        onTriggered: IslandEvents.removeActivity("agents-notice")
    }

    function setLimits(agent, five, fiveReset, week, weekReset) {
        root.limits = Object.assign({}, root.limits, { [agent]: { five: five, fiveReset: fiveReset, week: week, weekReset: weekReset } })
        const name = root.agentNames[agent] ?? agent
        const fiveRounded = Math.round(five)
        if (five >= 95)
            root.notice(`${agent}-5h95-${fiveReset}`, Translation.tr("%1 · 5h limit at %2%").arg(name).arg(fiveRounded),
                Translation.tr("Resets at %1").arg(root.formatReset(fiveReset)), "hourglass_bottom", "error")
        else if (five >= 80)
            root.notice(`${agent}-5h80-${fiveReset}`, Translation.tr("%1 · 5h limit at %2%").arg(name).arg(fiveRounded),
                Translation.tr("Resets at %1").arg(root.formatReset(fiveReset)), "hourglass_top", "attention")
        if (week >= 90)
            root.notice(`${agent}-7d90-${weekReset}`, Translation.tr("%1 · weekly limit at %2%").arg(name).arg(Math.round(week)),
                Translation.tr("Resets %1").arg(Qt.formatDateTime(new Date(weekReset * 1000), "ddd hh:mm")), "calendar_month", "attention")
        // Every agent you use is close to its limit: worth knowing before starting something long
        const near = Object.keys(root.limits).filter(a => (root.limits[a].five ?? 0) >= 80)
        if (near.length >= 2)
            root.notice(`near-${near.join("-")}-${Math.floor(Date.now() / 3600000)}`,
                Translation.tr("%1 near the 5h limit").arg(near.map(a => root.agentNames[a] ?? a).join(" · ")),
                Translation.tr("Switch agents or wait for a reset"), "balance", "attention")
    }

    function checkUsage(text) {
        let data
        try {
            data = JSON.parse(text)
        } catch (e) {
            return
        }
        root.setLimits("claude", data.five_hour?.used_percentage ?? 0, data.five_hour?.resets_at ?? 0,
            data.seven_day?.used_percentage ?? 0, data.seven_day?.resets_at ?? 0)
    }

    // A 5h window that is nearly used up and about to reset is worth knowing (you can wait instead of stopping)
    Timer {
        interval: 60000
        repeat: true
        // Only while some agent is actually close to its 5h limit — the only case this can ever speak up in
        running: root.enabled && Object.values(root.limits).some(l => (l.five ?? 0) >= 70 && l.fiveReset)
        onTriggered: {
            for (const agent of Object.keys(root.limits)) {
                const l = root.limits[agent]
                if (!l.fiveReset) continue
                const minutes = Math.round((l.fiveReset * 1000 - Date.now()) / 60000)
                if (minutes > 0 && minutes <= 15 && (l.five ?? 0) >= 70)
                    root.notice(`${agent}-5hsoon-${l.fiveReset}`, Translation.tr("%1 · 5h limit resets in %2 min").arg(root.agentNames[agent] ?? agent).arg(minutes),
                        Translation.tr("%1% used so far").arg(Math.round(l.five)), "update", "attention")
            }
        }
    }

    function setContext(agent, sid, used, model) {
        const key = root.keyFor(agent, sid)
        const s = root.sessions[key]
        if (!s || used < 0) return
        const nextModel = model || s.model
        if (used === s.context && nextModel === s.model) return
        const warn = used >= 80 && !s.contextWarned
        root.update(key, "", { context: used, model: nextModel, contextWarned: warn ? true : (used < 50 ? false : s.contextWarned) })
        if (warn)
            root.notice(`ctx-${key}-${Date.now()}`, `${root.titleFor(s)} · ${Translation.tr("Context at %1%").arg(used)}`,
                Translation.tr("It will compact soon"), "data_usage", "attention")
    }

    function checkContext(sid, text) {
        let data
        try {
            data = JSON.parse(text)
        } catch (e) {
            return
        }
        root.setContext("claude", sid, Math.round(data.context_window?.used_percentage ?? -1), data.model?.display_name ?? "")
    }

    FileView {
        path: `${root.home}/.cache/claude-usage.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (root.enabled) root.checkUsage(text())
    }

    Instantiator {
        model: root.claudeIds
        delegate: FileView {
            required property string modelData
            path: `${root.home}/.cache/claude-island/statusline-${modelData}.json`
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: root.checkContext(modelData, text())
        }
    }

    IpcHandler {
        target: "claude"

        function hook(event: string, session: string, cwd: string, detail: string, terminal: int): void {
            root.handle("claude", event, session, cwd, detail, terminal)
        }
        // Codex and Gemini hooks (agent-island.sh)
        function agent(agent: string, event: string, session: string, cwd: string, detail: string, terminal: int): void {
            root.handle(agent, event, session, cwd, detail, terminal)
        }
        function limits(agent: string, five: real, fiveReset: real, week: real, weekReset: real): void {
            root.setLimits(agent, five, fiveReset, week, weekReset)
        }
        function context(agent: string, session: string, percent: int, model: string): void {
            root.setContext(agent, session, percent, model)
        }
        function status(): string {
            return JSON.stringify(root.sessionList)
        }
        // Test notices (ilha-teste): limit, soon, context, near
        function demo(kind: string): void {
            const stamp = Date.now()
            if (kind === "limit")
                root.notice(`demo-${stamp}`, Translation.tr("%1 · 5h limit at %2%").arg("Claude").arg(86),
                    Translation.tr("Resets at %1").arg(Qt.formatTime(new Date(stamp + 95 * 60000), "hh:mm")), "hourglass_top", "attention")
            else if (kind === "soon")
                root.notice(`demo-${stamp}`, Translation.tr("%1 · 5h limit resets in %2 min").arg("Claude").arg(12),
                    Translation.tr("%1% used so far").arg(78), "update", "attention")
            else if (kind === "context")
                root.notice(`demo-${stamp}`, `Claude · meu-projeto · ${Translation.tr("Context at %1%").arg(82)}`,
                    Translation.tr("It will compact soon"), "data_usage", "attention")
            else if (kind === "approval") {
                const key = root.ensure("claude", `demo-approval-${stamp}`, `${root.home}/meu-projeto`)
                root.needsYou(key, `${root.home}/meu-projeto`, `${Translation.tr("Needs permission")}: Bash · git push origin main`,
                    { permission: "Bash · git push origin main", approvalHidden: false })
                root.updateWaitingGroup()
            }
            else if (kind === "near")
                root.notice(`demo-${stamp}`, Translation.tr("%1 near the 5h limit").arg("Claude · Codex"),
                    Translation.tr("Switch agents or wait for a reset"), "balance", "attention")
        }
    }
}
