pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Sustained pressure on the machine — CPU, memory or GPU — and who is causing it.
 *
 * Passive: no timer of its own for detection. It listens to the samples ResourceUsage already takes for the bar
 * (CPU and memory), and on the same beat reads one sysfs counter for the GPU (Intel's RC6 residency: the time the
 * GPU spent asleep; busy = the rest). Only once an alert is up — or a panel that lists processes is open — does
 * it look at processes, through scripts/island/top_consumers.py, every few seconds.
 *
 * "Abnormal" comes from the script: one process holding a disproportionate part of the resource that isn't a job
 * heavy by nature. The island names it, and the expanded view can end it (SIGTERM, then SIGKILL if it hangs on).
 */
Singleton {
    id: root

    readonly property var cfg: Config.options?.bar?.dynamicIsland ?? ({})
    readonly property bool enabled: root.cfg.systemLoad ?? true
    readonly property real cpuThreshold: (root.cfg.systemLoadThreshold ?? 90) / 100
    readonly property real memoryThreshold: (root.cfg.memoryThreshold ?? 90) / 100
    readonly property real gpuThreshold: (root.cfg.gpuThreshold ?? 90) / 100

    property real cpuSeconds: 0
    property real memorySeconds: 0
    property real gpuSeconds: 0
    property bool cpuHigh: false
    property bool memoryHigh: false
    property bool gpuHigh: false

    readonly property string kind: root.fakeKind !== "" ? root.fakeKind
        : root.memoryHigh ? "memory" : root.cpuHigh ? "cpu" : root.gpuHigh ? "gpu" : ""
    readonly property bool active: root.kind !== ""

    function usage(kind) {
        switch (kind) {
            case "memory": return ResourceUsage.memoryUsedPercentage
            case "gpu":    return root.gpuBusy
            default:       return ResourceUsage.cpuUsage
        }
    }
    function history(kind) {
        switch (kind) {
            case "memory": return ResourceUsage.memoryUsageHistory
            case "gpu":    return root.gpuHistory
            default:       return ResourceUsage.cpuUsageHistory
        }
    }
    function title(kind) {
        switch (kind) {
            case "memory": return Translation.tr("High memory usage")
            case "gpu":    return Translation.tr("High GPU usage")
            default:       return Translation.tr("High CPU")
        }
    }
    function icon(kind) {
        switch (kind) {
            case "memory": return "memory_alt"
            case "gpu":    return "developer_board"
            default:       return "memory"
        }
    }

    property var procs: ({ cpu: [], memory: [], gpu: [] })
    readonly property var alertProcs: root.kind !== "" ? (root.procs[root.kind] ?? []) : []
    readonly property var top: root.alertProcs[0] ?? null
    readonly property var culprit: root.alertProcs.find(p => p.abnormal) ?? null

    property var watchers: ({ cpu: 0, memory: 0, gpu: 0 })
    function watch(kind, on) {
        const next = Object.assign({}, root.watchers)
        next[kind] = Math.max(0, (next[kind] ?? 0) + (on ? 1 : -1))
        root.watchers = next
        if (on) refreshTimer.restart()
    }
    readonly property var wantedKinds: {
        const kinds = []
        if (root.kind !== "" && root.fakeKind === "") kinds.push(root.kind)
        for (const k of ["cpu", "memory", "gpu"])
            if ((root.watchers[k] ?? 0) > 0 && !kinds.includes(k) && k !== root.fakeKind) kinds.push(k)
        return kinds
    }

    Connections {
        target: ResourceUsage
        enabled: root.enabled
        function onCpuUsageChanged() {
            if (root.fakeKind !== "") return
            const now = Date.now()
            const seconds = root.lastSample > 0 ? Math.min(10, (now - root.lastSample) / 1000) : 1
            root.lastSample = now
            root.sampleGpu(now)

            root.cpuSeconds = root.step(root.cpuSeconds, ResourceUsage.cpuUsage, root.cpuThreshold, seconds)
            root.memorySeconds = root.step(root.memorySeconds, ResourceUsage.memoryUsedPercentage, root.memoryThreshold, seconds)
            root.gpuSeconds = root.step(root.gpuSeconds, root.gpuBusy, root.gpuThreshold, seconds)

            root.cpuHigh = root.cpuHigh ? root.cpuSeconds > 0 : root.cpuSeconds >= 10
            root.memoryHigh = root.memoryHigh ? root.memorySeconds > 0 : root.memorySeconds >= 6
            root.gpuHigh = root.gpuHigh ? root.gpuSeconds > 0 : root.gpuSeconds >= 15
        }
    }
    property double lastSample: 0

    function step(current, value, threshold, seconds) {
        if (value >= threshold) return Math.min(current + seconds, 30)
        if (value < threshold - 0.08) return Math.max(current - 2 * seconds, 0)
        return current
    }

    property string rc6Path: ""
    property real gpuBusy: 0
    property list<real> gpuHistory: []
    property double lastRc6: -1
    property double lastRc6At: 0

    Process {
        running: true
        command: ["bash", "-c", "ls /sys/class/drm/card*/gt/gt0/rc6_residency_ms /sys/class/drm/card*/power/rc6_residency_ms 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.rc6Path = text.trim()
        }
    }
    FileView {
        id: rc6File
        path: root.rc6Path
        printErrors: false
    }

    function sampleGpu(now) {
        if (root.rc6Path === "") return
        rc6File.reload()
        const rc6 = parseFloat(rc6File.text())
        if (isNaN(rc6)) return
        if (root.lastRc6 >= 0 && now > root.lastRc6At) {
            const idle = (rc6 - root.lastRc6) / (now - root.lastRc6At)
            root.gpuBusy = Math.max(0, Math.min(1, 1 - idle))
            const history = root.gpuHistory.slice(-(ResourceUsage.historyLength - 1))
            history.push(root.gpuBusy)
            root.gpuHistory = history
        }
        root.lastRc6 = rc6
        root.lastRc6At = now
    }

    property int queueIndex: 0

    Timer {
        id: refreshTimer
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: root.wantedKinds.length > 0
        onTriggered: {
            if (consumersProc.running) return
            const kinds = root.wantedKinds
            if (kinds.length === 0) return
            const kind = kinds[root.queueIndex % kinds.length]
            root.queueIndex++
            consumersProc.kind = kind
            consumersProc.command = ["python3", Quickshell.shellPath("scripts/island/top_consumers.py"), kind, "12"]
            consumersProc.running = true
        }
    }

    Process {
        id: consumersProc
        property string kind: "cpu"
        stdout: StdioCollector {
            onStreamFinished: {
                let result
                try {
                    result = JSON.parse(text)
                } catch (e) {
                    return
                }
                const next = Object.assign({}, root.procs)
                next[consumersProc.kind] = result.procs ?? []
                root.procs = next
                root.settleKills()
            }
        }
    }

    property var kills: ({})

    function kill(pid, force) {
        const proc = [].concat(root.procs.cpu ?? [], root.procs.memory ?? [], root.procs.gpu ?? []).find(p => p.pid === pid)
        if (!proc || proc.protected) return
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)])
        const next = Object.assign({}, root.kills)
        next[pid] = { at: Date.now(), forced: !!force, label: proc.label }
        root.kills = next
        refreshSoon.restart()
    }
    function killState(pid) {
        const entry = root.kills[pid]
        if (!entry) return ""
        if (entry.forced) return "forcing"
        return Date.now() - entry.at > 3000 ? "stuck" : "ending"
    }

    Timer {
        id: refreshSoon
        interval: 3500
        onTriggered: {
            root.kills = Object.assign({}, root.kills)
            refreshTimer.restart()
        }
    }

    function settleKills() {
        const alive = new Set([].concat(root.procs.cpu ?? [], root.procs.memory ?? [], root.procs.gpu ?? []).map(p => p.pid))
        const next = {}
        let changed = false
        for (const pid in root.kills) {
            if (alive.has(Number(pid))) next[pid] = root.kills[pid]
            else changed = true
        }
        if (changed) root.kills = next
    }

    property string fakeKind: ""

    function simulate(kind) {
        const fakes = {
            cpu: [{ pid: 999001, name: "chrome", label: "Chrome · aba", value: 1.6, text: "160%", share: 0.62, abnormal: true, protected: false },
                  { pid: 999002, name: "cargo", label: "cargo", value: 0.4, text: "40%", share: 0.15, abnormal: false, protected: false },
                  { pid: 999003, name: "Hyprland", label: "Hyprland", value: 0.12, text: "12%", share: 0.05, abnormal: false, protected: true }],
            memory: [{ pid: 999001, name: "chrome", label: "Chrome · aba", value: 5.2e9, text: "4.8 GB", share: 0.46, abnormal: true, protected: false },
                     { pid: 999004, name: "code", label: "VS Code", value: 1.3e9, text: "1.2 GB", share: 0.11, abnormal: false, protected: false },
                     { pid: 999005, name: "qs", label: "qs", value: 1.1e9, text: "1.0 GB", share: 0.09, abnormal: false, protected: true }],
            gpu: [{ pid: 999006, name: "chrome", label: "Chrome · GPU", value: 0.7, text: "70%", share: 0.72, abnormal: true, protected: false },
                  { pid: 999003, name: "Hyprland", label: "Hyprland", value: 0.2, text: "20%", share: 0.2, abnormal: false, protected: true }]
        }
        const next = Object.assign({}, root.procs)
        next[kind] = fakes[kind] ?? fakes.cpu
        root.procs = next
        root.fakeKind = kind
        fakeEnd.restart()
    }
    Timer {
        id: fakeEnd
        interval: 15000
        onTriggered: {
            root.fakeKind = ""
            root.procs = ({ cpu: [], memory: [], gpu: [] })
        }
    }
}
