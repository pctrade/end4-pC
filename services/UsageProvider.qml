pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Item {
    id: root

    property string providerId: ""
    readonly property bool enabled: UsageProviderSettings.providerEnabled(root.providerId)

    property int remainingPercent: -1
    property int resetAt: 0
    property string planType: ""
    property string error: ""
    property var windows: []
    property bool loading: false
    property int clockSeconds: Math.floor(Date.now() / 1000)

    readonly property bool available: root.remainingPercent >= 0 && root.remainingPercent <= 100
    readonly property bool processRunning: UsageProcessWatcher.runningProviders[root.providerId] === true
    readonly property string resetText: formatReset(root.resetAt, root.clockSeconds)

    function formatReset(timestamp, now) {
        if (!timestamp || timestamp <= 0)
            return Translation.tr("Reset unavailable")

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
        return Translation.tr("<1m")
    }

    function applySnapshot(result, persist = false) {
        const parsedWindows = Array.isArray(result?.windows)
            ? result.windows
                .map(window => ({
                    id: String(window?.id ?? "usage"),
                    label: String(window?.label ?? "Usage"),
                    remainingPercent: Math.max(0, Math.min(100, Math.round(Number(window?.remainingPercent ?? -1)))),
                    resetAt: Number(window?.resetAt ?? 0),
                }))
                .filter(window => window.remainingPercent >= 0)
            : []
        const fallbackRemaining = Number(result?.remainingPercent ?? -1)
        const remainingPercent = parsedWindows.length > 0
            ? Math.min(...parsedWindows.map(window => window.remainingPercent))
            : fallbackRemaining

        if (!Number.isFinite(remainingPercent) || remainingPercent < 0 || remainingPercent > 100)
            return false

        root.windows = parsedWindows
        root.remainingPercent = Math.round(remainingPercent)
        root.resetAt = Number(result?.resetAt ?? 0)
        root.planType = String(result?.planType ?? "")
        root.error = String(result?.error ?? "")
        root.loading = false

        if (persist) {
            UsageCache.save(root.providerId, {
                windows: result?.windows ?? parsedWindows,
                remainingPercent: root.remainingPercent,
                resetAt: root.resetAt,
                planType: root.planType,
            })
        }
        return true
    }

    function loadCachedUsage() {
        const cached = UsageCache.snapshot(root.providerId, root.clockSeconds)
        return cached ? root.applySnapshot(cached) : false
    }

    function expireCurrentUsage() {
        root.loadCachedUsage()
    }

    function applyUnavailable(message) {
        if (!root.available && !root.loadCachedUsage()) {
            root.remainingPercent = -1
            root.resetAt = 0
            root.windows = []
            root.planType = ""
        }

        root.error = message
        root.loading = false
    }

    function applyResult(rawText) {
        const trimmed = rawText.trim()
        if (trimmed.length === 0) {
            root.applyUnavailable(Translation.tr("Usage unavailable"))
            return
        }

        try {
            const result = JSON.parse(trimmed)
            if (!root.applySnapshot(result, true))
                root.applyUnavailable(String(result.error ?? "Usage unavailable"))
        } catch (e) {
            root.applyUnavailable(Translation.tr("Usage unavailable"))
        }
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
        command: [
            Quickshell.env("PYTHON3") || "python3",
            "-B",
            Quickshell.shellPath("scripts/ai-usage.py"),
            root.providerId,
        ]

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
        if (enabled) {
            root.loadCachedUsage()
            root.scheduleDetectedRefresh()
        } else if (usageProcess.running) {
            usageProcess.running = false
        }
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
            if (providerId === root.providerId && root.enabled)
                root.loadCachedUsage()
        }
    }

    Component.onCompleted: {
        if (root.enabled)
            root.loadCachedUsage()
    }
}
