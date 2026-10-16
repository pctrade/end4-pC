pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string scriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/webapp/webapp.sh`

    property var items: []
    property string error: ""
    readonly property bool busy: createProc.running

    function parseUrls(text) {
        return String(text).split(/[\n,\s]+/).map(line => line.trim()).filter(line => line !== "");
    }

    function refresh() {
        listProc.running = true;
    }

    function create(text) {
        const urls = root.parseUrls(text);
        if (urls.length === 0 || createProc.running) return;
        root.error = "";
        createProc.command = ["bash", root.scriptPath, "create", ...urls];
        createProc.running = true;
    }

    function remove(id) {
        removeProc.command = ["bash", root.scriptPath, "remove", id];
        removeProc.running = true;
    }

    function open(id) {
        openProc.command = ["bash", root.scriptPath, "open", id];
        openProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProc
        command: ["bash", root.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.items = JSON.parse(text);
                } catch (e) {
                    root.items = [];
                }
            }
        }
    }

    Process {
        id: createProc
        stdout: StdioCollector {
            id: createOut
        }
        onExited: {
            const failures = createOut.text.split("\n").filter(line => line.startsWith("ERR"));
            root.error = failures.map(line => line.replace(/^ERR\s*/, "")).join(", ");
            root.refresh();
        }
    }

    Process {
        id: removeProc
        onExited: root.refresh()
    }

    Process {
        id: openProc
    }
}
