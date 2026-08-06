pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * Exposes the active Niri Xkb keyboard layout name and code for indicators.
 * Mirrors HyprlandXkb.qml's shape so widgets can bind to either transparently.
 */
Singleton {
    id: root
    property list<string> layoutNames: []
    property int currentIdx: 0
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    property var baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"

    onCurrentLayoutNameChanged: root.updateLayoutCode()
    function updateLayoutCode() {
        if (WM.compositor !== "niri") return;
        if (!root.currentLayoutName) return;
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            root.currentLayoutCode = cachedLayoutCodes[currentLayoutName];
        } else {
            getLayoutProc.running = true;
        }
    }

    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector

            onStreamFinished: {
                const lines = layoutCollector.text.split("\n");
                const targetDescription = root.currentLayoutName;
                lines.find(line => {
                    if (!line.trim() || line.trim().startsWith('!'))
                        return false;

                    const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/);
                    if (matchLayout && matchLayout[2] === targetDescription) {
                        root.cachedLayoutCodes[matchLayout[2]] = matchLayout[1];
                        root.currentLayoutCode = matchLayout[1];
                        return true;
                    }

                    const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/);
                    if (matchVariant && matchVariant[3] === targetDescription) {
                        const complexLayout = matchVariant[2] + matchVariant[1];
                        root.cachedLayoutCodes[matchVariant[3]] = complexLayout;
                        root.currentLayoutCode = complexLayout;
                        return true;
                    }

                    return false;
                });
            }
        }
    }

    function refresh() {
        if (WM.compositor !== "niri") return;
        fetchLayoutsProc.running = true;
    }

    Process {
        id: fetchLayoutsProc
        command: ["niri", "msg", "-j", "keyboard-layouts"]

        stdout: StdioCollector {
            id: layoutsCollector
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(layoutsCollector.text);
                    root.layoutNames = parsed.names ?? [];
                    root.currentIdx = parsed.current_idx ?? 0;
                    root.currentLayoutName = root.layoutNames[root.currentIdx] ?? "";
                } catch (e) {
                    console.log("[NiriXkb] keyboard-layouts parse error: " + e);
                }
            }
        }
    }

    Component.onCompleted: {
        if (WM.compositor === "niri") {
            refresh();
            eventStream.running = true;
        }
    }

    Process {
        id: eventStream
        running: false
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.indexOf("KeyboardLayout") !== -1) refreshDebounce.restart();
            }
        }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: { if (WM.compositor === "niri") eventStream.running = true; } }
    Timer { id: refreshDebounce; interval: 80; onTriggered: root.refresh() }
}