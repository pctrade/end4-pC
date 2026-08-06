pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
import "../"

NestableObject {
    id: root

    required property string key
    property alias fetching: fetchProc.running
    property bool set
    property var value

    Component.onCompleted: {
        if (WM.compositor === "hyprland")
            fetch();
    }

    onValueChanged: {
        if (root.fetching) return
    }

    Connections {
        target: HyprlandConfig
        enabled: WM.compositor === "hyprland"
        function onReloaded() {
            root.fetch();
        }
    }

    function fetch() {
        if (WM.compositor !== "hyprland") return;
        fetchProc.command = fetchProc.baseCommand.concat([root.key]);
        fetchProc.running = true;
    }

    function setValue(newValue) {
        if (WM.compositor !== "hyprland") return;
        HyprlandConfig.set(root.key, newValue)
    }

    function reset() {
        if (WM.compositor !== "hyprland") return;
        HyprlandConfig.reset(root.key)
    }

    Process {
        id: fetchProc
        property list<string> baseCommand: ["hyprctl", "getoption", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text == "no such option")
                    return;
                try {
                    const obj = JSON.parse(text);
                    for (const key in obj) {
                        if (key == "option")
                            continue;
                        else if (key == "set")
                            root.set = obj[key];
                        else
                            root.value = obj[key];
                    }
                } catch (e) {
                    console.log(`[HyprlandConfigOption] Failed to fetch option "${root.key}":\n  - Output: ${text.trim()}\n  - Error: ${e}`);
                }
            }
        }
    }
}