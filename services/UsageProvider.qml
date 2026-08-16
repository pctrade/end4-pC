pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Item {
    id: root

    property string providerId: ""
    readonly property bool enabled: (Config.options?.bar?.usageProviders ?? ["codex", "claude", "antigravity"]).includes(root.providerId)

    property int remainingPercent: -1
    property int resetAt: 0
    property string planType: ""
    property string error: ""
    property var windows: []
    property bool loading: false
    property int clockSeconds: Math.floor(Date.now() / 1000)

    readonly property bool available: root.remainingPercent >= 0 && root.remainingPercent <= 100
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

    function applyResult(rawText) {
        const trimmed = rawText.trim()
        if (trimmed.length === 0) {
            root.remainingPercent = -1
            root.windows = []
            root.loading = false
            root.error = Translation.tr("Usage unavailable")
            return
        }

        try {
            const result = JSON.parse(trimmed)
            const parsedWindows = Array.isArray(result.windows)
                ? result.windows
                    .map(window => ({
                        id: String(window?.id ?? "usage"),
                        label: String(window?.label ?? "Usage"),
                        remainingPercent: Math.max(0, Math.min(100, Math.round(Number(window?.remainingPercent ?? -1)))),
                        resetAt: Number(window?.resetAt ?? 0),
                    }))
                    .filter(window => window.remainingPercent >= 0)
                : []
            root.windows = parsedWindows
            root.remainingPercent = parsedWindows.length > 0
                ? Math.min(...parsedWindows.map(window => window.remainingPercent))
                : Number(result.remainingPercent ?? -1)
            root.resetAt = Number(result.resetAt ?? 0)
            root.planType = String(result.planType ?? "")
            root.error = String(result.error ?? "")
        } catch (e) {
            root.remainingPercent = -1
            root.windows = []
            root.error = Translation.tr("Usage unavailable")
        }
        root.loading = false
    }

    function refresh() {
        if (!root.enabled)
            return

        if (usageProcess.running) {
            usageProcess.running = false
            Qt.callLater(() => usageProcess.running = true)
        } else {
            usageProcess.running = true
        }
        root.loading = true
    }

    Process {
        id: usageProcess
        command: [
            Quickshell.env("PYTHON3") || "python3",
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
        running: root.enabled
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: root.clockSeconds = Math.floor(Date.now() / 1000)
    }

    onEnabledChanged: {
        if (enabled)
            Qt.callLater(root.refresh)
        else if (usageProcess.running)
            usageProcess.running = false
    }

    Component.onCompleted: {
        if (root.enabled)
            Qt.callLater(root.refresh)
    }
}
