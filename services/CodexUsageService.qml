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
    readonly property string codexBinary: Quickshell.env("CODEX_CLI_PATH") || "codex"
    readonly property bool enabled: Config.ready
        && (Config.options?.bar?.usageProviders ?? []).includes("codex")

    property int weeklyUsedPercent: -1
    property int weeklyRemainingPercent: -1
    property int weeklyResetsAt: 0
    property int windowDurationMins: 0
    property string planType: ""
    property string error: ""
    property bool loading: false
    property bool initialized: false
    property bool requestInFlight: false
    property bool pendingRefresh: false
    property int nextRequestId: 10
    property int pendingRequestId: -1
    property int clockSeconds: Math.floor(Date.now() / 1000)

    readonly property bool available: weeklyRemainingPercent >= 0
    readonly property bool weeklyWindowKnown: windowDurationMins >= weeklyWindowMinutes
    // Common provider shape used by the multi-provider usage widget.
    readonly property int remainingPercent: weeklyRemainingPercent
    readonly property int resetAt: weeklyResetsAt
    readonly property var windows: weeklyRemainingPercent >= 0
        ? [{ id: "weekly", label: "Weekly", remainingPercent: weeklyRemainingPercent, resetAt: weeklyResetsAt }]
        : []
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

    function refresh() {
        if (!root.enabled) {
            root.pendingRefresh = false
            return
        }

        root.pendingRefresh = true

        if (!appServer.running) {
            appServer.running = true
            return
        }

        if (!root.initialized || root.requestInFlight)
            return

        requestRateLimits()
    }

    function requestRateLimits() {
        if (!appServer.running || !root.initialized || root.requestInFlight)
            return

        const requestId = root.nextRequestId++
        root.pendingRequestId = requestId
        root.pendingRefresh = false
        root.requestInFlight = true
        root.loading = true
        root.error = ""

        appServer.write(JSON.stringify({
            method: "account/rateLimits/read",
            id: requestId,
            params: null,
        }) + "\n")
    }

    function handleLine(line) {
        const trimmed = line.trim()
        if (trimmed.length === 0)
            return

        let message
        try {
            message = JSON.parse(trimmed)
        } catch (e) {
            return
        }

        if (message.id === 1) {
            if (message.error) {
                root.error = message.error.message ?? "Codex app-server initialization failed"
                root.loading = false
                return
            }

            root.initialized = true
            appServer.write(JSON.stringify({ method: "initialized", params: {} }) + "\n")
            if (root.pendingRefresh)
                requestRateLimits()
            return
        }

        if (message.id !== root.pendingRequestId)
            return

        root.requestInFlight = false
        root.loading = false

        if (message.error) {
            root.error = message.error.message ?? "Unable to read Codex usage"
            return
        }

        applyRateLimitResponse(message.result)
    }

    function applyRateLimitResponse(result) {
        const snapshot = result?.rateLimitsByLimitId?.codex ?? result?.rateLimits
        if (!snapshot) {
            root.error = "Codex did not return a usage limit"
            return
        }

        const windows = [snapshot.primary, snapshot.secondary]
            .filter(window => window !== null && window !== undefined)
        const weeklyWindow = windows.find(window =>
            Number(window.windowDurationMins) >= root.weeklyWindowMinutes
        ) ?? (windows.length === 1 ? windows[0] : snapshot.primary)

        if (!weeklyWindow) {
            root.error = "Codex weekly usage is unavailable"
            return
        }

        const used = Math.max(0, Math.min(100, Number(weeklyWindow.usedPercent) || 0))
        root.weeklyUsedPercent = used
        root.weeklyRemainingPercent = 100 - used
        root.weeklyResetsAt = Number(weeklyWindow.resetsAt) || 0
        root.windowDurationMins = Number(weeklyWindow.windowDurationMins) || 0
        root.planType = snapshot.planType ?? ""
        root.clockSeconds = Math.floor(Date.now() / 1000)
        root.error = ""
    }

    Process {
        id: appServer
        command: [root.codexBinary, "app-server", "--stdio"]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    root.error = line.trim()
            }
        }

        onRunningChanged: {
            if (!running) {
                root.initialized = false
                root.requestInFlight = false
                root.loading = false
                if (root.pendingRefresh && root.enabled)
                    retryTimer.restart()
                return
            }

            root.initialized = false
            root.requestInFlight = false
            root.loading = true
            write(JSON.stringify({
                method: "initialize",
                id: 1,
                params: {
                    clientInfo: {
                        name: "quickshell-codex-usage",
                        version: "1.0",
                    },
                    capabilities: { experimentalApi: true },
                },
            }) + "\n")
        }
    }

    Timer {
        id: refreshTimer
        interval: 5 * 60 * 1000
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }

    Timer {
        id: retryTimer
        interval: 30 * 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.enabled
        onTriggered: root.clockSeconds = Math.floor(Date.now() / 1000)
    }

    onEnabledChanged: {
        if (root.enabled) {
            Qt.callLater(root.refresh)
            return
        }

        root.pendingRefresh = false
        root.pendingRequestId = -1
        root.requestInFlight = false
        root.initialized = false
        root.loading = false
        retryTimer.stop()
        if (appServer.running)
            appServer.running = false
    }

    Component.onCompleted: {
        if (root.enabled)
            Qt.callLater(root.refresh)
    }
}
