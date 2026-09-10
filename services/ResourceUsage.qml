pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU and Disk usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property real cpuTemp: 0

    property real diskTotal: 1
    property real diskUsed: 0
    property real diskFree: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0
    property list<real> diskUsageHistory: []
    property string activeBoostPath: ""
    property string activeBoostType: ""
    property bool hasBoostControl: false
    property bool cpuBoostEnabled: true

    function syncBoostState() {
        if (!root.hasBoostControl || !fileBoost.loaded) return;
        const val = fileBoost.text().trim();
        if (val.length === 0) return;
        if (root.activeBoostType === "intel_no_turbo") {
            root.cpuBoostEnabled = (val === "0");
        } else {
            root.cpuBoostEnabled = (val === "1");
        }
    }

    function toggleCpuBoost() {
        if (!root.hasBoostControl || toggleCpuBoostProc.running) return;
        toggleCpuBoostProc.running = true;
    }

    Process {
        id: boostProbeProc
        running: true
        command: ["bash", "-c", "if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then echo 'intel_no_turbo /sys/devices/system/cpu/intel_pstate/no_turbo'; elif [ -f /sys/devices/system/cpu/cpufreq/boost ]; then echo 'cpufreq_boost /sys/devices/system/cpu/cpufreq/boost'; elif [ -f /sys/devices/system/cpu/amd_pstate/cpupower/boost ]; then echo 'amd_boost /sys/devices/system/cpu/amd_pstate/cpupower/boost'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length >= 2 && parts[1].length > 0) {
                    root.activeBoostType = parts[0];
                    root.activeBoostPath = parts[1];
                    root.hasBoostControl = true;
                    fileBoost.reload();
                } else {
                    root.hasBoostControl = false;
                }
            }
        }
    }

    Process {
        id: toggleCpuBoostProc
        command: {
            if (!root.hasBoostControl) return ["true"];
            const targetVal = root.activeBoostType === "intel_no_turbo"
                ? (root.cpuBoostEnabled ? "1" : "0")
                : (root.cpuBoostEnabled ? "0" : "1");
            return ["pkexec", "bash", "-c", `echo ${targetVal} > "${root.activeBoostPath}"`];
        }
        onExited: {
            if (fileBoost.path.length > 0) {
                fileBoost.reload();
            }
        }
    }

    Process {
        id: tempProc
        command: ["bash", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTemp = parseFloat(text.trim())
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2,$3,$4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ").map(Number)
                if (parts.length >= 3) {
                    root.diskTotal = parts[0]
                    root.diskUsed  = parts[1]
                    root.diskFree  = parts[2]
                }
            }
        }
    }

    Timer {
        interval: Config?.options.resources.updateInterval ?? 3000
        running: true
        repeat: true
        onTriggered: {
            tempProc.running = false
            tempProc.running = true
            diskProc.running = false
            diskProc.running = true
        }
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) memoryUsageHistory.shift()
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) swapUsageHistory.shift()
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) cpuUsageHistory.shift()
    }
    function updateDiskUsageHistory() {
        diskUsageHistory = [...diskUsageHistory, diskUsedPercentage]
        if (diskUsageHistory.length > historyLength) diskUsageHistory.shift()
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateDiskUsageHistory()
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()
            if (root.hasBoostControl && root.activeBoostPath.length > 0) {
                fileBoost.reload()
            }

            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree  = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal   = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree    = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            const textStat = fileStat.text()
            const cpuLine  = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle  = stats[3]
                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff  = idle  - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }
                previousCpuStats = { total, idle }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat;    path: "/proc/stat" }
    FileView {
        id: fileBoost
        path: root.activeBoostPath
        onLoaded: root.syncBoostState()
    }

    Process {
        id: findCpuMaxFreqProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
