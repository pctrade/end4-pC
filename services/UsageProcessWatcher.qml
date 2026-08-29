pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Singleton {
    id: root

    readonly property string checkHelper: Quickshell.shellPath("scripts/usage-check.py")
    readonly property string pythonBinary: Quickshell.env("PYTHON3") || "python3"
    readonly property list<string> providerIds: ["codex", "claude", "kimi", "zai", "antigravity", "cursor"]
    readonly property var selectedProviderIds: UsageProviderSettings.enabledProviderIds
    readonly property bool enabled: Config.ready && selectedProviderIds.length > 0

    property var runningProviders: ({})
    property bool initialized: false
    property bool checking: checker.running
    signal providerStarted(string providerId)
    signal providerStopped(string providerId)

    function applyLine(rawLine) {
        const trimmed = rawLine.trim()
        if (trimmed.length === 0)
            return

        let parsed
        try {
            parsed = JSON.parse(trimmed)
        } catch (e) {
            return
        }

        const previous = root.runningProviders
        const next = ({})
        root.providerIds.forEach(providerId => next[providerId] = parsed[providerId] === true)
        root.runningProviders = next

        if (!root.initialized) {
            root.initialized = true
            return
        }

        root.providerIds.forEach(providerId => {
            const wasRunning = previous[providerId] === true
            const isRunning = next[providerId] === true
            if (!wasRunning && isRunning)
                root.providerStarted(providerId)
            else if (wasRunning && !isRunning)
                root.providerStopped(providerId)
        })
    }

    function check() {
        if (root.enabled && !checker.running)
            checker.running = true
    }

    Process {
        id: checker
        command: [root.pythonBinary, "-B", root.checkHelper]

        stdout: StdioCollector {
            onStreamFinished: root.applyLine(text)
        }
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.enabled
        onTriggered: root.check()
    }

    onEnabledChanged: {
        if (root.enabled) {
            Qt.callLater(root.check)
        } else {
            root.initialized = false
            root.runningProviders = ({})
            if (checker.running)
                checker.running = false
        }
    }

    Component.onCompleted: {
        if (root.enabled)
            Qt.callLater(root.check)
    }
}
