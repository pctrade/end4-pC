pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Singleton {
    id: root

    readonly property int weeklyWindowMinutes: 7 * 24 * 60
    readonly property string usageHelper: Quickshell.shellPath("scripts/codex-usage.py")
    readonly property string pythonBinary: Quickshell.env("PYTHON3") || "python3"
    readonly property bool enabled: Config.ready
        && (Config.options?.bar?.usageProviders ?? []).includes("codex")

    property int weeklyUsedPercent: -1
    property int weeklyRemainingPercent: -1
    property int weeklyResetsAt: 0
    property int windowDurationMins: 0
    property string planType: ""
    property string error: ""
    property bool loading: false
    property var windows: []
    property int clockSeconds: Math.floor(Date.now() / 1000)

    readonly property bool available: weeklyRemainingPercent >= 0
    readonly property bool weeklyWindowKnown: windowDurationMins >= weeklyWindowMinutes
    // Common provider shape used by the multi-provider usage widget.
    readonly property bool processRunning: UsageProcessWatcher.runningProviders.codex === true
    readonly property int remainingPercent: weeklyRemainingPercent
    readonly property int resetAt: weeklyResetsAt
    readonly property string resetText: formatReset(weeklyResetsAt, clockSeconds)

    function formatReset(timestamp, now) {
        if (!timestamp || timestamp <= 0)
            return "Reset unavailable"

        const seconds = Math.max(0, timestamp - now)
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)

        if (days > 0)
            return `${days}d ${hours}h`
        if (hours > 0)
            return `${hours}h ${minutes}m`
        if (minutes > 0)
            return `${minutes}m`
        return "<1m"
    }

    function unavailable(message) {
        root.weeklyUsedPercent = -1
        root.weeklyRemainingPercent = -1
        root.weeklyResetsAt = 0
        root.windowDurationMins = 0
        root.windows = []
        root.loading = false
        root.error = message
    }

    function applySnapshot(result, persist = false) {
        const parsedWindows = Array.isArray(result?.windows)
            ? result.windows
                .map(window => ({
                    id: String(window?.id ?? "usage"),
                    label: String(window?.label ?? "Usage"),
                    remainingPercent: Math.max(0, Math.min(100, Math.round(Number(window?.remainingPercent ?? -1)))),
                    resetAt: Number(window?.resetAt ?? 0),
                    windowDurationMins: Number(window?.windowDurationMins ?? 0),
                }))
                .filter(window => window.remainingPercent >= 0)
            : []

        const weeklyWindow = parsedWindows.find(window =>
            window.windowDurationMins >= root.weeklyWindowMinutes
        )
        const selectedWindow = weeklyWindow ?? (parsedWindows.length === 1 ? parsedWindows[0] : null)
        if (!selectedWindow)
            return false

        root.windows = parsedWindows
        root.weeklyRemainingPercent = selectedWindow.remainingPercent
        root.weeklyUsedPercent = 100 - selectedWindow.remainingPercent
        root.weeklyResetsAt = selectedWindow.resetAt
        root.windowDurationMins = selectedWindow.windowDurationMins
        root.planType = String(result?.planType ?? "")
        root.error = String(result?.error ?? "")
        root.loading = false

        if (persist) {
            root.clockSeconds = Math.floor(Date.now() / 1000)
            UsageCache.save("codex", {
                windows: result?.windows ?? parsedWindows,
                remainingPercent: root.weeklyRemainingPercent,
                resetAt: root.weeklyResetsAt,
                planType: root.planType,
            })
        }
        return true
    }

    function loadCachedUsage() {
        const cached = UsageCache.snapshot("codex", root.clockSeconds)
        return cached ? root.applySnapshot(cached) : false
    }

    function expireCurrentUsage() {
        root.loadCachedUsage()
    }

    function applyUnavailable(message) {
        if (!root.available && !root.loadCachedUsage())
            root.unavailable(message)
        else {
            root.error = message
            root.loading = false
        }
    }

    function applyResult(rawText) {
        const trimmed = rawText.trim()
        if (trimmed.length === 0) {
            root.applyUnavailable("Codex usage unavailable")
            return
        }

        let result
        try {
            result = JSON.parse(trimmed)
        } catch (e) {
            root.applyUnavailable("Codex usage response was invalid")
            return
        }

        if (!root.applySnapshot(result, true))
            root.applyUnavailable(String(result.error ?? "Codex weekly usage is unavailable"))
    }

    function refresh() {
        if (!root.enabled || !root.processRunning)
            return

        if (usageProcess.running) {
            usageProcess.running = false
            Qt.callLater(() => usageProcess.running = true)
        } else {
            usageProcess.running = true
        }
        root.loading = true
    }

    function scheduleDetectedRefresh() {
        if (root.enabled && root.processRunning)
            detectedRefreshTimer.restart()
        else
            detectedRefreshTimer.stop()
    }

    Timer {
        id: detectedRefreshTimer
        interval: 5 * 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: usageProcess
        command: [root.pythonBinary, "-B", root.usageHelper]

        stdout: StdioCollector {
            onStreamFinished: root.applyResult(text)
        }

        onRunningChanged: {
            if (running)
                root.loading = true
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.enabled && root.processRunning
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.enabled
        onTriggered: {
            root.clockSeconds = Math.floor(Date.now() / 1000)
            root.expireCurrentUsage()
        }
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.loadCachedUsage()
            root.scheduleDetectedRefresh()
            return
        }

        root.loading = false
        if (usageProcess.running)
            usageProcess.running = false
    }

    onProcessRunningChanged: {
        if (root.processRunning) {
            root.scheduleDetectedRefresh()
            return
        }

        detectedRefreshTimer.stop()
        root.loading = false
        if (usageProcess.running)
            usageProcess.running = false
    }

    Connections {
        target: Persistent

        function onReadyChanged() {
            if (Persistent.ready && root.enabled && !root.available)
                root.loadCachedUsage()
        }
    }

    Connections {
        target: UsageCache

        function onSnapshotUpdated(providerId) {
            if (providerId === "codex" && root.enabled)
                root.loadCachedUsage()
        }
    }

    Component.onCompleted: {
        if (root.enabled)
            root.loadCachedUsage()
    }
}
