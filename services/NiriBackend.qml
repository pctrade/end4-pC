pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var windowList: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: null

    function switchWorkspaceRelative(direction) {
        actionProc.command = ["niri", "msg", "action", direction === "next" ? "focus-workspace-down" : "focus-workspace-up"];
        actionProc.running = true;
    }

    function normalizeWindow(w) {
        return {
            id: String(w.id),
            address: String(w.id),
            title: w.title ?? "",
            appId: w.app_id ?? "",
            class: w.app_id ?? "",
            workspaceId: w.workspace_id,
            focused: w.is_focused ?? false,
            width: w.layout?.window_size?.[0] ?? 0,
            height: w.layout?.window_size?.[1] ?? 0
        };
    }

    function focusWindow(id) {
        actionProc.command = ["niri", "msg", "action", "focus-window", "--id", id];
        actionProc.running = true;
    }
    function closeWindow(id) {
        actionProc.command = ["niri", "msg", "action", "close-window", "--id", id];
        actionProc.running = true;
    }
    function switchWorkspace(id) {
        actionProc.command = ["niri", "msg", "action", "focus-workspace", String(id)];
        actionProc.running = true;
    }
    function moveWindowToWorkspace(id, wsId) {
        actionProc.command = ["niri", "msg", "action", "move-window-to-workspace", "--window-id", id, String(wsId)];
        actionProc.running = true;
    }

    function monitorFor(screen) {
        if (!screen) return null;
        return root.monitors.find(m => m.name === screen.name) ?? null;
    }

    function activeWorkspaceForMonitor(monitorName) {
        if (!monitorName) return null;
        return root.workspaces.find(ws => ws.output === monitorName && ws.is_active) ?? null;
    }

    function biggestWindowForWorkspace(wsId) {
        const wins = root.windowList.filter(w => w.workspaceId === wsId);
        if (wins.length === 0) return null;
        return wins.reduce((a, b) => (a.width * a.height >= b.width * b.height ? a : b));
    }

    function fullscreenOnMonitor(monitorName) {
        const mon = root.monitors.find(m => m.name === monitorName);
        if (!mon || !mon.logical) return false;
        const ws = root.workspaces.find(w => w.output === monitorName && w.is_active);
        if (!ws) return false;
        return root.windowList.some(w => w.workspaceId === ws.id
            && w.width === mon.logical.width
            && w.height === mon.logical.height);
    }

    function monitorGeometry(screen) {
        const m = root.monitors.find(mm => mm.name === screen?.name);
        if (!m || !m.logical) return { x: 0, y: 0, scale: 1 };
        return { x: m.logical.x, y: m.logical.y, scale: m.logical.scale };
    }

    Process { id: actionProc }

    function updateAll() {
        getWindows.running = true;
        getWorkspaces.running = true;
        getOutputs.running = true;
    }

    Component.onCompleted: {
        updateAll();
        eventStream.running = true;
    }

    Process {
        id: getWindows
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(text).map(root.normalizeWindow);
                } catch (e) { console.log("[NiriBackend] windows parse error: " + e) }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    root.workspaces = raw;
                    let byId = {};
                    for (const ws of raw) byId[ws.id] = ws;
                    root.workspaceById = byId;
                    root.activeWorkspace = raw.find(ws => ws.is_focused) ?? null;
                } catch (e) { console.log("[NiriBackend] workspaces parse error: " + e) }
            }
        }
    }

    Process {
        id: getOutputs
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    root.monitors = Object.keys(raw).map(name => {
                        const o = raw[name];
                        return {
                            name: name,
                            make: o.make ?? "",
                            model: o.model ?? "",
                            current_mode: o.current_mode,
                            modes: o.modes,
                            logical: o.logical
                        };
                    });
                    root.focusedMonitor = root.monitors.find(m => root.workspaces.find(ws => ws.output === m.name && ws.is_focused)) ?? null;
                } catch (e) { console.log("[NiriBackend] outputs parse error: " + e) }
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim().length > 0) refreshDebounce.restart() }
        }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: eventStream.running = true }
    Timer { id: refreshDebounce; interval: 80; onTriggered: root.updateAll() }
}
