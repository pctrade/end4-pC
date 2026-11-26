pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int consumers: 0
    property var positions: ({})

    function claim() {
        root.consumers++
    }

    function release() {
        root.consumers = Math.max(0, root.consumers - 1)
    }

    Process {
        running: root.consumers > 0
        command: ["python3", "-u", Quickshell.shellPath("scripts/glass/floating_tracker.py")]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const client = JSON.parse(line)
                    const next = Object.assign({}, root.positions)
                    next[client.title] = { x: client.at[0], y: client.at[1] }
                    root.positions = next
                } catch (e) {}
            }
        }
    }
}
