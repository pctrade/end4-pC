pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isAvailable: true
    property var containers: []
    property var projects: []
    property var standaloneContainers: []
    property int runningCount: 0
    property int totalCount: 0
    property int stoppedCount: 0
    property int unhealthyCount: 0
    property string totalMemoryUsage: "0 MB"
    property var statsMap: ({})
    property bool isRefreshing: false

    property bool popupVisible: false

    function parsePortNumbers(portsStr) {
        if (!portsStr) return [];
        const portList = [];
        const regex = /(?:0\.0\.0\.0|127\.0\.0\.1|\[::\]):([0-9]+)->([0-9]+)/g;
        let match;
        while ((match = regex.exec(portsStr)) !== null) {
            const hostPort = match[1];
            if (!portList.includes(hostPort)) {
                portList.push(hostPort);
            }
        }
        return portList;
    }

    function extractProjectName(labelsStr) {
        if (!labelsStr) return "standalone";
        const match = labelsStr.match(/com\.docker\.compose\.project=([a-zA-Z0-9_\-\.]+)/);
        return match ? match[1] : "standalone";
    }

    function extractServiceName(labelsStr, defaultName) {
        if (!labelsStr) return defaultName;
        const match = labelsStr.match(/com\.docker\.compose\.service=([a-zA-Z0-9_\-\.]+)/);
        return match ? match[1] : defaultName;
    }

    function refresh() {
        if (psProc.running) return;
        psProc.buffer = [];
        root.isRefreshing = true;
        psProc.running = true;
    }

    function refreshStats() {
        if (statsProc.running) return;
        statsProc.buffer = [];
        statsProc.running = true;
    }

    function startContainer(id) {
        Quickshell.execDetached(["docker", "start", id]);
        actionTimer.restart();
    }

    function stopContainer(id) {
        Quickshell.execDetached(["docker", "stop", id]);
        actionTimer.restart();
    }

    function restartContainer(id) {
        Quickshell.execDetached(["docker", "restart", id]);
        actionTimer.restart();
    }

    function removeContainer(id) {
        Quickshell.execDetached(["docker", "rm", "-f", id]);
        actionTimer.restart();
    }

    function startProject(projectName) {
        const targetContainers = root.containers.filter(c => c.project === projectName);
        const ids = targetContainers.map(c => c.id);
        if (ids.length > 0) {
            Quickshell.execDetached(["docker", "start", ...ids]);
            actionTimer.restart();
        }
    }

    function stopProject(projectName) {
        const targetContainers = root.containers.filter(c => c.project === projectName && c.state === "running");
        const ids = targetContainers.map(c => c.id);
        if (ids.length > 0) {
            Quickshell.execDetached(["docker", "stop", ...ids]);
            actionTimer.restart();
        }
    }

    function restartProject(projectName) {
        const targetContainers = root.containers.filter(c => c.project === projectName);
        const ids = targetContainers.map(c => c.id);
        if (ids.length > 0) {
            Quickshell.execDetached(["docker", "restart", ...ids]);
            actionTimer.restart();
        }
    }

    function openTerminalExec(nameOrId) {
        Quickshell.execDetached(["ptyxis", "--", "docker", "exec", "-it", nameOrId, "sh"]);
    }

    function openTerminalLogs(nameOrId) {
        Quickshell.execDetached(["ptyxis", "--", "docker", "logs", "-f", "--tail", "200", nameOrId]);
    }

    function openPortInBrowser(port) {
        Quickshell.execDetached(["xdg-open", "http://localhost:" + port]);
    }

    function pruneContainers() {
        Quickshell.execDetached(["docker", "container", "prune", "-f"]);
        actionTimer.restart();
    }

    Timer {
        id: actionTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root.refresh();
        }
    }

    Timer {
        id: pollTimer
        interval: root.popupVisible ? 2500 : 12000
        running: true
        repeat: true
        onTriggered: {
            root.refresh();
            if (root.popupVisible || root.runningCount > 0) {
                root.refreshStats();
            }
        }
    }

    Process {
        id: psProc
        property list<string> buffer: []
        command: ["docker", "ps", "-a", "--format", "{{json .}}"]

        stdout: SplitParser {
            onRead: line => {
                if (line.trim().length > 0) {
                    psProc.buffer.push(line.trim());
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.isRefreshing = false;
            if (exitCode !== 0) {
                root.isAvailable = false;
                root.containers = [];
                root.projects = [];
                root.standaloneContainers = [];
                root.runningCount = 0;
                root.totalCount = 0;
                root.stoppedCount = 0;
                root.unhealthyCount = 0;
                return;
            }

            root.isAvailable = true;
            const parsedList = [];
            let running = 0;
            let stopped = 0;
            let unhealthy = 0;

            for (const line of psProc.buffer) {
                try {
                    const item = JSON.parse(line);
                    const isRunning = (item.State === "running");
                    const isUnhealthy = (item.Status && item.Status.includes("unhealthy"));
                    const isRestarting = (item.State === "restarting" || (item.Status && item.Status.startsWith("Restarting")));
                    
                    if (isRunning) running++;
                    else stopped++;
                    if (isUnhealthy) unhealthy++;

                    const proj = root.extractProjectName(item.Labels || "");
                    const serv = root.extractServiceName(item.Labels || "", item.Names || item.ID);
                    const ports = root.parsePortNumbers(item.Ports || "");
                    const stats = root.statsMap[item.ID] || root.statsMap[item.Names] || {};

                    parsedList.push({
                        id: item.ID,
                        name: item.Names || item.ID,
                        image: item.Image || "",
                        state: isRestarting ? "restarting" : (item.State || "unknown"),
                        status: item.Status || "",
                        health: isUnhealthy ? "unhealthy" : (item.Status && item.Status.includes("healthy") ? "healthy" : "none"),
                        ports: ports,
                        portsRaw: item.Ports || "",
                        project: proj,
                        service: serv,
                        cpu: stats.cpu || "0%",
                        cpuVal: stats.cpuVal || 0.0,
                        mem: stats.mem || "",
                        memVal: stats.memVal || 0.0,
                        raw: item
                    });
                } catch (e) {
                    console.error("[DockerService] Parse error on line:", line, e);
                }
            }

            root.totalCount = parsedList.length;
            root.runningCount = running;
            root.stoppedCount = stopped;
            root.unhealthyCount = unhealthy;
            root.containers = parsedList;

            // Group into projects
            const projectMap = {};
            const standalones = [];

            for (const c of parsedList) {
                if (c.project && c.project !== "standalone") {
                    if (!projectMap[c.project]) {
                        projectMap[c.project] = [];
                    }
                    projectMap[c.project].push(c);
                } else {
                    standalones.push(c);
                }
            }

            const projectList = [];
            for (const pName in projectMap) {
                const pContainers = projectMap[pName];
                const pRunning = pContainers.filter(c => c.state === "running").length;
                projectList.push({
                    name: pName,
                    containers: pContainers,
                    runningCount: pRunning,
                    totalCount: pContainers.length,
                    allRunning: (pRunning === pContainers.length)
                });
            }

            projectList.sort((a, b) => a.name.localeCompare(b.name));
            root.projects = projectList;
            root.standaloneContainers = standalones;
        }
    }

    Process {
        id: statsProc
        property list<string> buffer: []
        command: ["docker", "stats", "--no-stream", "--format", "{{json .}}"]

        stdout: SplitParser {
            onRead: line => {
                if (line.trim().length > 0) {
                    statsProc.buffer.push(line.trim());
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) return;
            const newStats = {};
            for (const line of statsProc.buffer) {
                try {
                    const item = JSON.parse(line);
                    const cpuPerc = parseFloat((item.CPUPerc || "0").replace("%", "")) || 0;
                    const memPerc = parseFloat((item.MemPerc || "0").replace("%", "")) || 0;
                    const statObj = {
                        cpu: item.CPUPerc || "0%",
                        cpuVal: cpuPerc / 100.0,
                        mem: item.MemUsage || "",
                        memVal: memPerc / 100.0
                    };
                    if (item.ID) newStats[item.ID] = statObj;
                    if (item.Name) newStats[item.Name] = statObj;
                } catch (e) {}
            }
            root.statsMap = newStats;

            const updated = root.containers.map(c => {
                const s = newStats[c.id] || newStats[c.name] || {};
                return Object.assign({}, c, {
                    cpu: s.cpu || c.cpu || "0%",
                    cpuVal: (s.cpuVal !== undefined) ? s.cpuVal : (c.cpuVal || 0.0),
                    mem: s.mem || c.mem || "",
                    memVal: (s.memVal !== undefined) ? s.memVal : (c.memVal || 0.0)
                });
            });
            root.containers = updated;
        }
    }

    IpcHandler {
        target: "docker"

        function toggle(): void {
            root.popupVisible = !root.popupVisible;
        }
        function open(): void {
            root.popupVisible = true;
        }
        function close(): void {
            root.popupVisible = false;
        }
        function refresh(): void {
            root.refresh();
            root.refreshStats();
        }
    }

    Component.onCompleted: {
        root.refresh();
        root.refreshStats();
    }
}
