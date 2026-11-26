pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.functions
import "../"

NestableObject {
    id: root

    property var monitors: []
    property var _pendingChanges: ({})
    property var _applyQueue: []
    property var _baseline: null
    // The single monitor every display in Mirror mode copies. Written through
    // to each mirroring monitor in monitors.lua, so it survives a restart as
    // long as something is mirroring.
    property string mirrorSource: ""

    // Staged edits versus what is already written to monitors.lua. Editing an
    // option back to its saved value clears this again.
    readonly property bool dirty: root._baseline !== null
        && JSON.stringify(root.monitors) !== root._baseline

    function _rebaseline() { root._baseline = JSON.stringify(root.monitors) }

    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/monitor_configurator.py")
    readonly property string capsScriptPath: Quickshell.shellPath("scripts/hyprland/monitor_caps.py")
    readonly property string monitorsLuaPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/monitors.lua`)

    Component.onCompleted: fetchProc.running = true

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorlayout", "configreloaded"].includes(event.name)) {
                console.log(`[mc] refresh by ${event.name}`)
                refreshTimer.restart()
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: fetchProc.running = true
    }

    function updateMonitor(index, changes) {
        // Never blank the desktop: whatever is left showing it stays on,
        // no matter which page tries to turn the last one off.
        const lastOneOn = changes.disabled === true
            && !root.monitors.some((m, i) => i !== index && !(m.disabled ?? false))
        if (lastOneOn) return

        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m

        let pending = Object.assign({}, root._pendingChanges)
        pending[index] = Object.assign({}, pending[index] || {}, changes)
        root._pendingChanges = pending
    }

    // Pin: one monitor is the mirror reference. Every display already
    // mirroring follows the pin; the pinned one itself stops mirroring.
    function pinSource(name) {
        if (!name || root.mirrorSource === name) return
        root.mirrorSource = name
        root.monitors.forEach((m, i) => {
            if (m.name === name) {
                if (m.mirror) root.updateMonitor(i, { mirror: "" })
            } else if (m.mirror && m.mirror !== name) {
                root.updateMonitor(i, { mirror: name })
            }
        })
    }

    // Mirror / Extended for one display. A display cannot mirror itself, so
    // picking Mirror while it holds the pin moves the pin (and every display
    // already mirroring it) onto another display first.
    function setMirroring(index, mirror) {
        const name = root.monitors[index]?.name
        if (!name) return
        if (!mirror) {
            root.updateMonitor(index, { mirror: "" })
            return
        }
        const source = root.mirrorSource
        if (!source || source === name || !root.monitors.some(m => m.name === source)) {
            const other = root.monitors.find(m => m.name !== name)?.name ?? ""
            if (other) root.pinSource(other)
        }
        root.updateMonitor(index, { mirror: root.mirrorSource })
    }

    function _mergeByName(patchByName) {
        root.monitors = root.monitors.map(mon => {
            const patch = patchByName[mon.name]
            return patch ? Object.assign({}, mon, patch) : mon
        })
    }

    function _modeToLua(m) {
        const parts = m.currentMode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
        return parts ? `${parts[1]}x${parts[2]}@${parseFloat(parts[3])}` : m.currentMode
    }

    function _fieldsToWrite(m, changedKeys) {
        const setPairs = {}
        const resetKeys = []

        if (changedKeys.has("disabled")) {
            if (m.disabled) setPairs["disabled"] = "1"
            else resetKeys.push("disabled")
        }
        if (changedKeys.has("x") || changedKeys.has("y")) {
            setPairs["position"] = `${m.x}x${m.y}`
        }
        if (changedKeys.has("currentMode") || changedKeys.has("width") || changedKeys.has("height") || changedKeys.has("refreshRate")) {
            setPairs["mode"] = root._modeToLua(m)
        }
        if (changedKeys.has("scale")) setPairs["scale"] = m.scale
        if (changedKeys.has("transform")) {
            if (m.transform && m.transform !== 0) setPairs["transform"] = m.transform
            else resetKeys.push("transform")
        }
        if (changedKeys.has("bitdepth")) {
            if (m.bitdepth) setPairs["bitdepth"] = m.bitdepth
            else resetKeys.push("bitdepth")
        }
        if (changedKeys.has("cm")) {
            if (m.cm && m.cm !== "auto") setPairs["cm"] = m.cm
            else resetKeys.push("cm")
        }
        if (changedKeys.has("sdrBrightness")) setPairs["sdrbrightness"] = m.sdrBrightness
        if (changedKeys.has("sdrSaturation")) setPairs["sdrsaturation"] = m.sdrSaturation
        if (changedKeys.has("minLuminance")) setPairs["min_luminance"] = m.minLuminance
        if (changedKeys.has("maxLuminance")) setPairs["max_luminance"] = m.maxLuminance
        if (changedKeys.has("maxAvgLuminance")) setPairs["max_avg_luminance"] = m.maxAvgLuminance
        if (changedKeys.has("sdrMinLuminance")) setPairs["sdr_min_luminance"] = m.sdrMinLuminance
        if (changedKeys.has("sdrMaxLuminance")) setPairs["sdr_max_luminance"] = m.sdrMaxLuminance
        if (changedKeys.has("vrr")) setPairs["vrr"] = m.vrr ? "1" : "0"
        if (changedKeys.has("mirror")) {
            if (m.mirror) setPairs["mirror"] = m.mirror
            else resetKeys.push("mirror")
        }

        return { setPairs, resetKeys }
    }

    function save(index) {
        const m = root.monitors[index]
        if (!m || !m.name) return

        const changed = root._pendingChanges[index]
        if (!changed) return
        const changedKeys = new Set(Object.keys(changed))
        const { setPairs, resetKeys } = root._fieldsToWrite(m, changedKeys)

        if (Object.keys(setPairs).length === 0 && resetKeys.length === 0) return false

        let args = ["python3", root.configuratorScriptPath, "--file", root.monitorsLuaPath, "--output", m.name]
        for (const key in setPairs) args.push("--set", key, String(setPairs[key]))
        for (const key of resetKeys) args.push("--reset", key)

        console.log(`[mc] save ${m.name} pos=${m.x}x${m.y}`)

        saveProc.command = args
        saveProc.running = true

        let pending = Object.assign({}, root._pendingChanges)
        delete pending[index]
        root._pendingChanges = pending
        return true
    }

    // Option edits are staged in _pendingChanges only: nothing is written to
    // monitors.lua until the page's Apply button runs applyAll().
    function applyAndSave(index) {}
    function saveHdr(index) {}

    function applyAll() {
        root._applyQueue = Object.keys(root._pendingChanges).map(Number)
        console.log(`[mc] applyAll queue=[${root._applyQueue}]`)
        root._drainApplyQueue()
    }

    // saveProc is shared, so pending monitors are written one after another
    // instead of overwriting each other's command.
    function _drainApplyQueue() {
        while (root._applyQueue.length > 0) {
            if (root.save(root._applyQueue.shift())) return
        }
        console.log("[mc] queue drained -> reload")
        reloadProc.running = true
        root._rebaseline()
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name:          m.name,
                        description:   m.description,
                        width:         m.width,
                        height:        m.height,
                        refreshRate:   m.refreshRate,
                        x:             m.x,
                        y:             m.y,
                        scale:         m.scale,
                        transform:     m.transform ?? 0,
                        disabled:      m.disabled,
                        mirror:        "",
                        availableModes: m.availableModes,
                        currentMode:   `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`,
                        cm:            m.colorManagementPreset ?? "auto",
                        sdrBrightness: m.sdrBrightness ?? 1.0,
                        sdrSaturation: m.sdrSaturation ?? 1.0,
                        sdrMinLuminance: m.sdrMinLuminance ?? 0,
                        sdrMaxLuminance: m.sdrMaxLuminance ?? 0,
                        vrr:           m.vrr ?? false,
                        bitdepth:        null,
                        minLuminance:    null,
                        maxLuminance:    null,
                        maxAvgLuminance: null,

                        hdrSupported: null,
                        maxBpc:       null,
                    }))
                    root._rebaseline()
                    console.log("[mc] fetch " + root.monitors.map(m => `${m.name}@${m.x},${m.y}`).join(" "))
                    // Put staged edits back on top of the fresh baseline: any
                    // monitor event refreshes from the desktop, and without
                    // this merge it silently dropped a staged drag — Apply
                    // then wrote the old positions back and the canvas jumped.
                    const pend = root._pendingChanges
                    for (const key in pend) {
                        const i = Number(key)
                        if (root.monitors[i])
                            root.monitors[i] = Object.assign({}, root.monitors[i], pend[key])
                    }
                    if (root.monitors.length > 0) {
                        capsProc.command = ["python3", root.capsScriptPath].concat(root.monitors.map(mon => mon.name))
                        capsProc.running = true
                        dumpProc.command = ["python3", root.configuratorScriptPath, "--file", root.monitorsLuaPath, "--dump-all"]
                        dumpProc.running = true
                    }
                } catch(e) {
                    console.log("[MonitorConfig] Error parseando JSON:", e)
                }
            }
        }
    }

    Process {
        id: capsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const caps = JSON.parse(text)
                    let patch = {}
                    for (const name in caps) {
                        patch[name] = { hdrSupported: caps[name].hdr, maxBpc: caps[name].maxBpc }
                    }
                    root._mergeByName(patch)
                    root._rebaseline()
                } catch(e) {
                    console.log("[MonitorConfig] Error parsing caps JSON:", e)
                }
            }
        }
    }

    Process {
        id: dumpProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const dump = JSON.parse(text)
                    let patch = {}
                    for (const name in dump) {
                        const d = dump[name]
                        patch[name] = {
                            bitdepth:        d.bitdepth ?? null,
                            minLuminance:    d.min_luminance ?? null,
                            maxLuminance:    d.max_luminance ?? null,
                            maxAvgLuminance: d.max_avg_luminance ?? null,
                            mirror:          typeof d.mirror === "string" ? d.mirror : "",
                        }
                    }
                    root._mergeByName(patch)
                    root._rebaseline()
                    // Whoever the saved file is mirrored from holds the pin.
                    const src = root.monitors.find(m => m.mirror && m.mirror !== m.name)?.mirror
                    root.mirrorSource = src && root.monitors.some(m => m.name === src)
                        ? src : (root.monitors[0]?.name ?? "")
                } catch(e) {
                    console.log("[MonitorConfig] Error parsing monitors.lua dump JSON:", e)
                }
            }
        }
    }

    Process {
        id: saveProc
        onRunningChanged: if (!running) root._drainApplyQueue()
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}
