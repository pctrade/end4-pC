pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var sessions: []
    property int tokens: 0
    property int resetsAt: 0
    readonly property int tokenLimit: Config.options.bar.aiUsage.tokenLimit
    readonly property real percentage: root.tokenLimit > 0 ? Math.min(root.tokens / root.tokenLimit, 1) : 0
    readonly property int activeSessions: root.sessions.length

    function refresh() {
        if (Config.options.bar.aiUsage.claudeEnabled && !usageProc.running) usageProc.running = true;
    }

    Timer {
        interval: Config.options.bar.aiUsage.updateInterval * 1000
        repeat: true
        running: Config.ready && Config.options.bar.aiUsage.claudeEnabled
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProc
        command: ["python3", Quickshell.shellPath("scripts/ai/claude-usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.sessions = data.sessions;
                    root.tokens = data.tokens;
                    root.resetsAt = data.resetsAt;
                } catch (e) {}
            }
        }
    }
}
