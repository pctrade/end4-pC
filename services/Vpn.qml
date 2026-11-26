pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Singleton {
    id: root

    property list<var> profiles: []
    property list<string> activeUuids: []
    property string selectedUuid: ""
    property bool busy: connectProc.running || disconnectProc.running || actionProc.running
    property string pendingUuid: ""

    signal dialogRequested()

    readonly property var activeProfile: profiles.find(p => activeUuids.includes(p.uuid)) ?? null
    readonly property var selectedProfile: activeProfile
        ?? profiles.find(p => p.uuid === selectedUuid)
        ?? profiles[0]
        ?? null
    readonly property bool available: profiles.length > 0
    readonly property bool connected: activeProfile !== null

    function splitFields(line) {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                current += line[++i];
            } else if (ch === ":") {
                fields.push(current);
                current = "";
            } else {
                current += ch;
            }
        }
        fields.push(current);
        return fields;
    }

    function refresh() {
        if (!listProc.running) listProc.running = true;
    }

    function toggle() {
        const profile = root.selectedProfile;
        if (!profile) {
            root.dialogRequested();
            return;
        }
        if (busy) return;
        if (root.connected) disconnectProc.exec(["nmcli", "connection", "down", "uuid", root.activeProfile.uuid]);
        else connectProc.exec(["nmcli", "connection", "up", "uuid", profile.uuid]);
    }

    function connectTo(uuid) {
        if (busy) return;
        if (root.connected && root.activeProfile.uuid === uuid) {
            disconnectProc.exec(["nmcli", "connection", "down", "uuid", uuid]);
            return;
        }
        root.selectedUuid = uuid;
        if (root.connected) {
            root.pendingUuid = uuid;
            disconnectProc.exec(["nmcli", "connection", "down", "uuid", root.activeProfile.uuid]);
        } else {
            connectProc.exec(["nmcli", "connection", "up", "uuid", uuid]);
        }
    }

    function remove(uuid) {
        actionProc.exec(["nmcli", "connection", "delete", "uuid", uuid]);
    }

    function importFile(path) {
        const file = path.trim();
        if (file === "") return;
        const type = file.toLowerCase().endsWith(".ovpn") ? "openvpn" : "wireguard";
        actionProc.exec(["nmcli", "connection", "import", "type", type, "file", file]);
    }

    function pickAndImport() {
        if (!pickerProc.running) pickerProc.running = true;
    }

    function notifyFailure(message) {
        Quickshell.execDetached(["notify-send", "VPN", message, "-a", "Shell"]);
    }

    Timer {
        running: GlobalStates.sidebarRightOpen
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        command: ["bash", "-c", "nmcli -t -f NAME,UUID,TYPE connection show; echo :::ACTIVE; nmcli -t -f UUID connection show --active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split(":::ACTIVE");
                const found = [];
                for (const line of parts[0].split("\n")) {
                    const fields = root.splitFields(line);
                    if (fields.length < 3) continue;
                    if (fields[2] === "vpn" || fields[2] === "wireguard")
                        found.push({ name: fields[0], uuid: fields[1], type: fields[2] });
                }
                root.profiles = found;
                root.activeUuids = (parts[1] ?? "").split("\n").map(s => s.trim()).filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: connectProc
        stderr: StdioCollector {
            id: connectErr
        }
        onExited: (code, status) => {
            if (code !== 0) root.notifyFailure(connectErr.text.trim() || "Connection failed");
            root.refresh();
        }
    }

    Process {
        id: disconnectProc
        onExited: {
            if (root.pendingUuid !== "") {
                const uuid = root.pendingUuid;
                root.pendingUuid = "";
                connectProc.exec(["nmcli", "connection", "up", "uuid", uuid]);
                return;
            }
            root.refresh();
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: (code, status) => {
            if (code !== 0) root.notifyFailure(actionErr.text.trim() || "Action failed");
            root.refresh();
        }
    }

    Process {
        id: pickerProc
        command: ["bash", "-c", "kdialog --getopenfilename \"$HOME\" '*.conf *.ovpn|VPN configs' 2>/dev/null || zenity --file-selection --file-filter='*.conf *.ovpn' 2>/dev/null"]
        stdout: StdioCollector {
            id: pickerOut
            onStreamFinished: root.importFile(pickerOut.text)
        }
    }
}
