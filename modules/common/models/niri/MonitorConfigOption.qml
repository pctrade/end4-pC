pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
import "../"

/**
 * Same interface as models/hyprland/MonitorConfigOption, backed by niri.
 * Fetches via `niri msg -j outputs`, applies live via `niri msg output`,
 * persists via NiriConfig (qssettings/outputs.kdl).
 */
NestableObject {
    id: root

    property var monitors: []

    readonly property var transformNames: ["normal", "90", "180", "270"]

    Component.onCompleted: { if (WM.compositor === "niri") fetchProc.running = true }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    function save() {
        if (root.monitors.length === 0) return
        NiriConfig.generateOutputsKdl(root.monitors)
    }

    function applyMonitor(m) {
        if (!m.name) return
        if (m.disabled) {
            applyProc.command = ["sh", "-c", `niri msg output "${m.name}" off`]
            applyProc.running = true
            return
        }
        const mode = m.currentMode.replace(/Hz$/, "")
        const cmds = [
            `niri msg output "${m.name}" on`,
            `niri msg output "${m.name}" mode "${mode}"`,
            `niri msg output "${m.name}" scale ${m.scale}`,
            `niri msg output "${m.name}" transform "${root.transformNames[m.transform] ?? "normal"}"`,
            `niri msg output "${m.name}" position set ${m.x} ${m.y}`
        ]
        applyProc.command = ["sh", "-c", cmds.join(" && ")]
        applyProc.running = true
    }

    function applyAndSave(index) {
        root.applyMonitor(root.monitors[index])
        root.save()
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height
    }

    Process {
        id: fetchProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)
                    root.monitors = Object.entries(outputs).map(([connector, o]) => {
                        const current = o.modes?.[o.current_mode] ?? null
                        const refresh = current ? current.refresh_rate / 1000 : 60
                        return {
                            name:          connector,
                            description:   [o.make, o.model].filter(s => s && s !== "Unknown").join(" "),
                            width:         current?.width ?? 1920,
                            height:        current?.height ?? 1080,
                            refreshRate:   refresh,
                            x:             o.logical?.x ?? 0,
                            y:             o.logical?.y ?? 0,
                            scale:         o.logical?.scale ?? 1.0,
                            transform:     Math.max(0, root.transformNames.indexOf(o.logical?.transform ?? "normal")),
                            disabled:      o.logical === null,
                            vrr:           o.vrr_enabled ?? false,
                            availableModes: (o.modes ?? []).map(mode => `${mode.width}x${mode.height}@${(mode.refresh_rate / 1000).toFixed(2)}Hz`),
                            currentMode:   current ? `${current.width}x${current.height}@${refresh.toFixed(2)}Hz` : ""
                        }
                    })
                } catch (e) {
                    console.log("[NiriMonitorConfig] Error parsing outputs JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }
}
