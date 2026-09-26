pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.modules.common

/**
 * Quick ways to stretch the battery, offered by the low-battery alert. Each one remembers what it changed and
 * everything goes back the moment the charger is plugged in — the saver never becomes a setting you have to
 * remember to undo.
 *
 *   profile    — power-profiles-daemon "power-saver"
 *   dim        — internal screen to 35% (never raises it)
 *   effects    — Hyprland animations and blur off (hl.config via hyprctl eval; the config is Lua)
 *   bluetooth  — adapter off, only offered when nothing is connected (earbuds stay alone)
 *
 * No polling: state is what this service set, plus the power profile IslandHardware already tracks.
 */
Singleton {
    id: root

    readonly property bool profileOn: IslandHardware.powerProfile === "power-saver"
    property bool dimOn: false
    property bool effectsOn: false
    property bool bluetoothOn: false

    property string previousProfile: ""
    property real previousBrightness: -1
    property bool previousAnimations: true
    property bool previousBlur: true

    readonly property bool anyOn: root.profileOn || root.dimOn || root.effectsOn || root.bluetoothOn
    readonly property bool bluetoothOffered: (Bluetooth.defaultAdapter?.enabled ?? false) && !BluetoothStatus.connected || root.bluetoothOn

    readonly property var screenMonitor: Brightness.monitors.find(m => m.screen?.name?.startsWith("eDP")) ?? Brightness.monitors[0] ?? null

    function toggleProfile() {
        if (root.profileOn) {
            IslandHardware.setPowerProfile(root.previousProfile !== "" && root.previousProfile !== "power-saver" ? root.previousProfile : "balanced")
        } else {
            root.previousProfile = IslandHardware.powerProfile
            IslandHardware.setPowerProfile("power-saver")
        }
    }

    function toggleDim() {
        const monitor = root.screenMonitor
        if (!monitor) return
        if (root.dimOn) {
            if (root.previousBrightness >= 0) monitor.setBrightness(root.previousBrightness)
            root.dimOn = false
        } else {
            root.previousBrightness = monitor.brightness
            if (monitor.brightness > 0.35) monitor.setBrightness(0.35)
            root.dimOn = true
        }
    }

    function toggleEffects() {
        if (root.effectsOn) {
            root.applyEffects(root.previousAnimations, root.previousBlur)
            root.effectsOn = false
        } else {
            effectsReadProc.running = true
        }
    }

    function applyEffects(animations, blur) {
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.config({ animations = { enabled = ${animations} }, decoration = { blur = { enabled = ${blur} } } })`])
    }

    Process {
        id: effectsReadProc
        command: ["bash", "-c", "hyprctl getoption animations:enabled -j; hyprctl getoption decoration:blur:enabled -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.split(/\n(?=\{)/).map(chunk => {
                    try {
                        return JSON.parse(chunk)
                    } catch (e) {
                        return null
                    }
                })
                root.previousAnimations = values[0]?.bool ?? ((values[0]?.int ?? 1) !== 0)
                root.previousBlur = values[1]?.bool ?? ((values[1]?.int ?? 1) !== 0)
                root.applyEffects(false, false)
                root.effectsOn = true
            }
        }
    }

    function toggleBluetooth() {
        const adapter = Bluetooth.defaultAdapter
        if (!adapter) return
        if (root.bluetoothOn) {
            adapter.enabled = true
            root.bluetoothOn = false
        } else if (!BluetoothStatus.connected) {
            adapter.enabled = false
            root.bluetoothOn = true
        }
    }

    function saveAll() {
        if (!root.profileOn) root.toggleProfile()
        if (!root.dimOn) root.toggleDim()
        if (!root.effectsOn) root.toggleEffects()
        if (!root.bluetoothOn && root.bluetoothOffered) root.toggleBluetooth()
    }

    function restoreAll() {
        if (root.profileOn && root.previousProfile !== "") root.toggleProfile()
        if (root.dimOn) root.toggleDim()
        if (root.effectsOn) root.toggleEffects()
        if (root.bluetoothOn) root.toggleBluetooth()
        root.previousProfile = ""
    }

    Connections {
        target: Battery
        function onIsPluggedInChanged() {
            if (Battery.isPluggedIn && root.anyOn) root.restoreAll()
        }
    }
}
