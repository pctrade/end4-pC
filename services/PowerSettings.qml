pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// System power policy for the settings page: lid, power key, hibernate delay, idle action, critical-battery
// safety net and wake devices. The system is the source of truth (scripts/power/power_settings.py reads and
// writes it), so nothing here is stored in the shell config and nothing runs until the page asks.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/power/power_settings.py")
    property var values: ({})
    property bool ready: false
    property string error: ""
    property var pending: []
    property bool refreshAgain: false

    function refresh() {
        if (getProc.running) root.refreshAgain = true
        else getProc.running = true
    }

    function set(key: string, value: var) {
        root.pending = root.pending.concat([[key, String(value)]])
        root.pump()
    }

    function pump() {
        if (setProc.running) return
        if (root.pending.length === 0) {
            root.refresh()
            return
        }
        const next = root.pending[0]
        root.pending = root.pending.slice(1)
        root.error = ""
        setProc.command = ["python3", root.script, "set", next[0], next[1]]
        setProc.running = true
    }

    Process {
        id: getProc
        command: ["python3", root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text)
                    root.ready = true
                } catch (e) {
                    root.error = Translation.tr("Couldn't read the system power settings")
                }
            }
        }
        onExited: {
            if (!root.refreshAgain) return
            root.refreshAgain = false
            getProc.running = true
        }
    }

    Process {
        id: setProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.error = text.trim()
        }
        onExited: root.pump()
    }
}
