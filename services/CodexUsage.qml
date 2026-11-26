pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real percentage: 0
    property int resetsAt: 0
    property real weeklyPercentage: 0
    property int weeklyResetsAt: 0

    function refresh() {
        if (Config.options.bar.aiUsage.codexEnabled && !usageProc.running)
            usageProc.running = true;
    }

    Timer {
        interval: Config.options.bar.aiUsage.updateInterval * 1000
        repeat: true
        running: Config.ready && Config.options.bar.aiUsage.codexEnabled
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProc
        command: ["python3", Quickshell.shellPath("scripts/ai/codex-usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.available = data.available === true;
                    root.percentage = data.percentage ?? 0;
                    root.resetsAt = data.resetsAt ?? 0;
                    root.weeklyPercentage = data.weeklyPercentage ?? 0;
                    root.weeklyResetsAt = data.weeklyResetsAt ?? 0;
                } catch (e) { root.available = false; }
            }
        }
    }
}
