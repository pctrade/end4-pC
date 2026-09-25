pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.modules.common
import qs.modules.common.functions

// Hardware moments on the island: monitors, removable drives, docks, chargers, wireless peripherals, game controllers,
// Caps Lock and keyboard layout, waking up from sleep and heat. They share one interrupt island ("hardware"); the
// payload says what to show: { kind, icon, tone, title, subtitle, value, status, urgent, actions: [{ id, label, icon }] }.
Singleton {
    id: root

    readonly property var cfg: Config.options.bar.dynamicIsland
    readonly property bool enabled: Config.ready && (root.cfg.hardware ?? true)
    readonly property int slowChargerWatts: root.cfg.slowChargerWatts ?? 25
    readonly property int hotTemperature: root.cfg.hotTemperature ?? 90

    // What's on screen (same contract as IslandEvents' flashes: active, hold, dismiss)
    property var current: null
    readonly property var payload: root.current ?? ({})
    property bool active: false
    property bool held: false

    Timer {
        id: hideTimer
        onTriggered: if (!root.held) root.active = false
    }

    function show(payload, ms) {
        if (!root.enabled) return
        root.current = payload
        hideTimer.interval = ms ?? 8000
        root.active = true
        hideTimer.restart()
    }

    function hold(value) {
        root.held = value
        if (!value) hideTimer.restart()
    }

    function dismiss() {
        root.held = false
        root.active = false
    }

    // Updates what's on screen (the result of an action), without restarting its timer
    function update(changes) {
        if (!root.current) return
        root.current = Object.assign({}, root.current, changes)
    }

    function formatSize(bytes) {
        if (!(bytes > 0)) return ""
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = bytes
        let unit = 0
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000
            unit++
        }
        return `${value.toFixed(value < 10 && unit > 0 ? 1 : 0)} ${units[unit]}`
    }

    // ---------------------------------------------------------------------------------------------
    // Several things plugged in within a couple of seconds (monitor, network, USB hub, power) is a dock
    property var bucket: []

    function queue(category, payload) {
        root.bucket = [...root.bucket, { category: category, payload: payload }]
        mergeTimer.restart()
    }

    Timer {
        id: mergeTimer
        interval: 2500
        onTriggered: {
            const items = root.bucket
            root.bucket = []
            const dockParts = ["monitor", "net", "hub", "power"]
            const kinds = new Set(items.map(i => i.category).filter(c => dockParts.includes(c)))
            if (kinds.size >= 2) {
                const monitors = items.filter(i => i.category === "monitor")
                const parts = []
                if (monitors.length > 0) parts.push(monitors.length === 1 ? Translation.tr("1 monitor") : Translation.tr("%1 monitors").arg(monitors.length))
                if (kinds.has("net")) parts.push(Translation.tr("network"))
                if (kinds.has("hub")) parts.push("USB")
                if (kinds.has("power")) parts.push(Battery.energyRate > 0.5 ? `${Math.round(Battery.energyRate)} W` : Translation.tr("power"))
                const monitor = monitors[0]?.payload
                root.show({
                    kind: "dock", icon: "dock", tone: "progress", title: Translation.tr("Dock connected"), subtitle: parts.join(" · "), value: "",
                    output: monitor?.output ?? "", layout: "extend", resolution: monitor?.resolution ?? "", actions: monitor?.actions ?? []
                }, 12000)
                return
            }
            for (const category of ["monitor", "drive", "controller"]) {
                const item = items.find(i => i.category === category && i.payload)
                if (item) {
                    root.show(item.payload, 12000)
                    return
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Monitors and keyboard layout: Hyprland events
    readonly property string internalOutput: Hyprland.monitors.values.map(m => m.name).find(n => /^(eDP|LVDS|DSI)/.test(n)) ?? "eDP-1"
    property bool internalDisabled: false
    property string lastLayout: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.enabled) return
            switch (event.name) {
                case "monitoradded":
                    root.monitorAdded(event.data.trim())
                    break
                case "monitorremoved":
                    root.monitorRemoved(event.data.trim())
                    break
                case "activelayout":
                    root.layoutChanged(event.data.slice(event.data.indexOf(",") + 1).trim())
                    break
            }
        }
    }

    function monitorAdded(name) {
        if (/^(eDP|LVDS|DSI)/.test(name)) return
        monitorInfo.pending = name
        monitorInfoDelay.restart()
    }

    function monitorRemoved(name) {
        // Never leave the laptop without a screen
        if (root.internalDisabled) {
            Quickshell.execDetached(["hyprctl", "eval", `hl.monitor({ output = "${root.internalOutput}", mode = "preferred", position = "auto", scale = 1 })`])
            root.internalDisabled = false
        }
        if (root.active && root.payload.output === name) root.dismiss()
        root.show({ kind: "monitorOff", icon: "desktop_access_disabled", tone: "neutral", title: Translation.tr("Monitor disconnected"),
            subtitle: name, value: "", actions: [] }, 3000)
    }

    Timer {
        id: monitorInfoDelay
        interval: 900
        onTriggered: monitorInfo.running = true
    }

    Process {
        id: monitorInfo
        property string pending: ""
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(text)
                } catch (e) {
                    return
                }
                const m = list.find(x => x.name === monitorInfo.pending)
                if (!m) return
                const resolution = `${m.width}×${m.height}`
                root.queue("monitor", {
                    kind: "monitor", icon: "desktop_windows", tone: "progress", title: Translation.tr("Monitor connected"),
                    subtitle: `${IslandEvents.shortName(m.model || m.description || m.name)} · ${resolution} · ${Math.round(m.refreshRate)} Hz`,
                    value: "", output: m.name, resolution: resolution, layout: (m.mirrorOf ?? "none") !== "none" ? "mirror" : "extend",
                    actions: [
                        { id: "extend", label: Translation.tr("Extend"), icon: "splitscreen_right" },
                        { id: "mirror", label: Translation.tr("Mirror"), icon: "screen_share" },
                        { id: "only", label: Translation.tr("External only"), icon: "tv" }
                    ]
                })
            }
        }
    }

    // Changing the screen layout is the one action here that can leave you with nothing to look at: turning the
    // laptop panel off only works if the external one really came up, and an HDMI cable that is loose, a mode the
    // screen refuses, or a monitor that sleeps all end the same way — a black machine that looks crashed.
    // So the layout is applied, then verified, and it undoes itself unless it is confirmed.
    property string layoutBefore: "extend"
    property string layoutPending: ""
    property string layoutOutput: ""

    function applyMonitorLayout(output, mode) {
        // Simulated monitor (no output): only the picture changes
        if (!output) {
            root.update({ layout: mode })
            return
        }
        root.layoutBefore = root.internalDisabled ? "only" : (root.payload.layout ?? "extend")
        root.layoutOutput = output
        root.layoutPending = mode
        root.runMonitorLayout(output, mode)
        root.update({ layout: mode })
        // "only" is the dangerous one: check that something is actually lit, and ask before keeping it
        if (mode === "only") layoutVerifyDelay.restart()
        else root.layoutPending = ""
    }

    function runMonitorLayout(output, mode) {
        const internal = root.internalOutput
        const internalOn = `hl.monitor({ output = "${internal}", mode = "preferred", position = "auto", scale = 1 })`
        const lua = mode === "mirror" ? `${internalOn}; hl.monitor({ output = "${output}", mode = "preferred", position = "auto", scale = 1, mirror = "${internal}" })`
            : mode === "only" ? `hl.monitor({ output = "${output}", mode = "preferred", position = "auto", scale = 1 }); hl.monitor({ output = "${internal}", disabled = true })`
            : `${internalOn}; hl.monitor({ output = "${output}", mode = "preferred", position = "auto-right", scale = 1 })`
        Quickshell.execDetached(["hyprctl", "eval", lua])
        root.internalDisabled = mode === "only"
    }

    function revertMonitorLayout(reason) {
        layoutCountdown.stop()
        root.layoutPending = ""
        root.runMonitorLayout(root.layoutOutput, root.layoutBefore === "only" ? "extend" : root.layoutBefore)
        root.show({
            kind: "monitorReverted", icon: "settings_backup_restore", tone: "attention", urgent: true,
            title: Translation.tr("Screen layout undone"), subtitle: reason, value: "", actions: []
        }, 7000)
    }

    Timer {
        id: layoutVerifyDelay
        interval: 1800
        onTriggered: layoutVerify.running = true
    }

    Process {
        id: layoutVerify
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let monitors = []
                try {
                    monitors = JSON.parse(text)
                } catch (e) {
                    root.revertMonitorLayout(Translation.tr("Couldn't read the screens"))
                    return
                }
                const external = monitors.find(m => m.name === root.layoutOutput && !m.disabled)
                if (!external) {
                    // Nothing came up on the other side: put the laptop screen back before you are left in the dark
                    root.revertMonitorLayout(Translation.tr("The external screen didn't come up"))
                    return
                }
                root.layoutSecondsLeft = 12
                layoutCountdown.restart()
                root.show({
                    kind: "monitorConfirm", icon: "tv", tone: "attention", urgent: true,
                    title: Translation.tr("Keep using only the external screen?"),
                    subtitle: Translation.tr("Going back in %1 s").arg(root.layoutSecondsLeft),
                    value: "", actions: [{ id: "keepLayout", label: Translation.tr("Keep"), icon: "check" }]
                }, 15000)
            }
        }
    }

    property int layoutSecondsLeft: 0

    Timer {
        id: layoutCountdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.layoutSecondsLeft--
            if (root.layoutSecondsLeft <= 0) {
                root.revertMonitorLayout(Translation.tr("No answer"))
                return
            }
            if (root.payload.kind === "monitorConfirm")
                root.update({ subtitle: Translation.tr("Going back in %1 s").arg(root.layoutSecondsLeft) })
        }
    }

    // Starting layout, so the first change is compared with something real
    Process {
        running: root.enabled
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastLayout = JSON.parse(text).keyboards.find(k => k.main)?.active_keymap ?? ""
                } catch (e) {}
            }
        }
    }

    function layoutCode(name) {
        const inParens = /\(([^)]+)\)/.exec(name)
        return (inParens ? inParens[1] : name).slice(0, 2).toUpperCase()
    }

    function layoutChanged(layout) {
        if (layout === "" || layout === root.lastLayout) return
        const first = root.lastLayout === ""
        root.lastLayout = layout
        if (first) return
        root.show({ kind: "layout", icon: "keyboard", tone: "progress", title: Translation.tr("Keyboard layout"), subtitle: layout,
            value: root.layoutCode(layout), urgent: true, actions: [] }, 1600)
    }

    // ---------------------------------------------------------------------------------------------
    // udev: removable drives, game controllers, USB hubs and wired network (for docks)
    Process {
        id: udev
        running: root.enabled
        command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=block", "--subsystem-match=input",
            "--subsystem-match=usb", "--subsystem-match=net"]
        property var props: ({})

        function flush() {
            if (Object.keys(udev.props).length > 0) root.handleUdev(udev.props)
            udev.props = ({})
        }

        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "" || line.startsWith("UDEV ") || line.startsWith("UDEV\t")) {
                    udev.flush()
                    return
                }
                const eq = line.indexOf("=")
                if (eq > 0) udev.props[line.slice(0, eq)] = line.slice(eq + 1)
            }
        }
    }

    function handleUdev(p) {
        const action = p.ACTION
        switch (p.SUBSYSTEM) {
            case "block": {
                const removable = p.ID_BUS === "usb" || p.ID_DRIVE_FLASH_SD === "1" || /mmcblk/.test(p.DEVNAME ?? "")
                if (!removable || !p.ID_FS_TYPE || !(p.DEVTYPE === "partition" || p.DEVTYPE === "disk")) return
                if (action === "add") root.driveAdded(p)
                else if (action === "remove") root.driveRemoved(p.DEVNAME)
                break
            }
            case "input":
                if (p.ID_INPUT_JOYSTICK === "1" && /\/js\d+$/.test(p.DEVNAME ?? "")) {
                    if (action === "add") root.controllerAdded(p)
                    else if (action === "remove") root.controllerRemoved(p)
                }
                break
            case "usb":
                if (action === "add" && p.DEVTYPE === "usb_device" && /:09/.test(p.ID_USB_INTERFACES ?? "")) root.queue("hub", null)
                break
            case "net":
                if (action === "add" && /^(en|eth)/.test(p.INTERFACE ?? "")) root.queue("net", null)
                break
        }
    }

    // Removable drives
    function driveAdded(p) {
        const device = p.DEVNAME
        const label = p.ID_FS_LABEL || (p.ID_MODEL ?? "").replace(/_/g, " ") || device.split("/").pop()
        const sd = p.ID_DRIVE_FLASH_SD === "1" || /mmcblk/.test(device)
        root.queue("drive", {
            kind: "drive", icon: sd ? "sd_card" : "usb", tone: "progress",
            title: Translation.tr("%1 connected").arg(IslandEvents.shortName(label)),
            subtitle: [root.formatSize(Number(p.ID_PART_ENTRY_SIZE ?? 0) * 512), (p.ID_FS_TYPE ?? "").toUpperCase()].filter(Boolean).join(" · "),
            value: "", device: device, disk: device.replace(/p?\d+$/, ""), label: label,
            actions: [
                { id: "open", label: Translation.tr("Open"), icon: "folder_open" },
                { id: "copyPrints", label: Translation.tr("Copy today's prints"), icon: "photo_library" },
                { id: "eject", label: Translation.tr("Eject"), icon: "eject" }
            ]
        })
    }

    function driveRemoved(device) {
        if (root.active && root.payload.device === device && root.payload.kind === "drive") root.dismiss()
    }

    function driveAction(id) {
        const d = root.current
        if (!d?.device) return
        const device = StringUtils.shellSingleQuoteEscape(d.device)
        const disk = StringUtils.shellSingleQuoteEscape(d.disk ?? d.device)
        const mount = `mp=$(lsblk -no MOUNTPOINT '${device}' 2>/dev/null | head -1); `
            + `[ -n "$mp" ] || mp=$(udisksctl mount -b '${device}' --no-user-interaction 2>/dev/null | sed -n 's/.* at \\(.*\\)$/\\1/p'); `
            + `[ -n "$mp" ] || exit 3; `
        const free = `echo "free|$(df -h --output=avail "$mp" | tail -1 | tr -d ' ')"; `
        let script = ""
        if (id === "open") {
            root.update({ status: Translation.tr("Mounting…") })
            script = `${mount}${free}xdg-open "$mp" >/dev/null 2>&1 & echo "opened|"`
        } else if (id === "copyPrints") {
            root.update({ status: Translation.tr("Copying…") })
            script = `${mount}dest="$mp/Prints"; mkdir -p "$dest"; `
                + `n=0; for f in $(find "$HOME/Imagens/Prints" -maxdepth 1 -type f -newermt "$(date +%F)" 2>/dev/null); do cp -n "$f" "$dest/" && n=$((n+1)); done; `
                + `sync; ${free}echo "copied|$n"`
        } else if (id === "eject") {
            root.update({ status: Translation.tr("Ejecting…") })
            script = `sync; udisksctl unmount -b '${device}' --no-user-interaction >/dev/null 2>&1; `
                + `udisksctl power-off -b '${disk}' --no-user-interaction >/dev/null 2>&1 || exit 4; echo "ejected|"`
        }
        driveProc.action = id
        driveProc.command = ["bash", "-c", script]
        driveProc.running = true
    }

    Process {
        id: driveProc
        property string action: ""
        stdout: SplitParser {
            onRead: line => {
                const [what, value] = line.split("|")
                if (what === "free") root.update({ free: value })
                else if (what === "opened") root.update({ status: value !== "" ? value : (root.payload.free ? Translation.tr("%1 free").arg(root.payload.free) : "") })
                else if (what === "copied") root.update({ status: Translation.tr("%1 prints copied").arg(value) })
                else if (what === "ejected")
                    root.show({ kind: "driveSafe", icon: "check_circle", tone: "success", title: Translation.tr("Safe to remove"),
                        subtitle: IslandEvents.shortName(root.payload.label ?? ""), value: "", actions: [] }, 5000)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 3) root.update({ status: Translation.tr("Couldn't open the drive") })
            else if (exitCode === 4) root.update({ status: Translation.tr("Couldn't eject · something is still using it") })
            else if (exitCode === 0 && driveProc.action === "open" && root.payload.free) root.update({ status: Translation.tr("%1 free").arg(root.payload.free) })
        }
    }

    // Game controllers
    property double lastControllerAt: 0
    property string lastControllerName: ""

    function gamepadBattery() {
        const pad = UPower.devices.values.find(d => d.type === UPowerDeviceType.GamingInput)
        return pad && pad.percentage > 0 ? `${Math.round(pad.percentage * 100)}%` : ""
    }

    function controllerAdded(p) {
        if (Date.now() - root.lastControllerAt < 3000) return
        root.lastControllerAt = Date.now()
        const name = (p.ID_MODEL_FROM_DATABASE || p.ID_MODEL || "").replace(/_/g, " ").trim() || Translation.tr("Game controller")
        root.lastControllerName = name
        root.queue("controller", { kind: "controller", icon: "stadia_controller", tone: "success", title: Translation.tr("Controller connected"),
            subtitle: IslandEvents.shortName(name), value: root.gamepadBattery(), actions: [] })
    }

    function controllerRemoved(p) {
        if (Date.now() - root.lastControllerAt < 1500) return
        root.show({ kind: "controllerOff", icon: "stadia_controller", tone: "neutral", title: Translation.tr("Controller disconnected"),
            subtitle: IslandEvents.shortName(root.lastControllerName), value: "", actions: [] }, 3000)
    }

    // ---------------------------------------------------------------------------------------------
    // Charger: plugging in counts toward a dock; a slow one is worth a word once charging settles
    Connections {
        target: Battery
        function onIsPluggedInChanged() {
            if (!Battery.isPluggedIn) {
                chargerCheck.stop()
                return
            }
            root.queue("power", null)
            chargerCheck.restart()
        }
    }

    Timer {
        id: chargerCheck
        interval: 7000
        onTriggered: {
            const watts = Math.round(Battery.energyRate)
            if (!Battery.isCharging || watts <= 0 || Battery.percentage >= 0.95 || watts >= root.slowChargerWatts) return
            root.show({ kind: "charger", icon: "battery_charging_20", tone: "attention", title: Translation.tr("Slow charger"),
                subtitle: Translation.tr("Charging at %1 W · it will take longer").arg(watts), value: `${watts} W`, actions: [] }, 8000)
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Every battery that is not the laptop's, in one list: earbuds, mouse, keyboard, controller, phone.
    // They arrive from two places (UPower for USB dongles, BlueZ for Bluetooth), which is why one charge
    // used to be reported in one corner of the shell and another somewhere else.
    // No refresh timer: UPower and BlueZ both announce a charge change themselves, and this re-evaluates then
    readonly property var peripherals: {
        const items = []
        const seen = {}

        for (const device of UPower.devices.values) {
            if (device.isLaptopBattery || device.type === UPowerDeviceType.LinePower) continue
            const level = Number(device.percentage) || 0
            if (level <= 0) continue
            const name = IslandEvents.shortName(device.model || device.nativePath || "")
            if (name === "" || seen[name.toLowerCase()]) continue
            seen[name.toLowerCase()] = true
            items.push({
                name: name,
                level: level,
                kind: root.upowerKind(device.type) || "device",
                icon: root.peripheralIcon(root.upowerKind(device.type)),
                charging: device.state === UPowerDeviceState.Charging,
                source: "upower"
            })
        }

        for (const device of Bluetooth.devices.values) {
            if (!device.connected || !device.batteryAvailable) continue
            const level = Number(device.battery) || 0
            if (level <= 0) continue
            const name = IslandEvents.shortName(device.name || device.deviceName || "")
            if (name === "" || seen[name.toLowerCase()]) continue
            seen[name.toLowerCase()] = true
            const icon = device.icon ?? ""
            const kind = /mouse/.test(icon) ? "mouse" : /keyboard/.test(icon) ? "keyboard"
                : /gaming|joystick/.test(icon) ? "controller" : /audio|headset|headphone/.test(icon) ? "audio" : "device"
            items.push({
                name: name,
                level: level,
                kind: kind,
                icon: root.peripheralIcon(kind),
                charging: false,
                source: "bluetooth"
            })
        }

        return items.sort((a, b) => a.level - b.level)
    }

    readonly property var peripheralLowest: root.peripherals.length > 0 ? root.peripherals[0] : null

    function peripheralIcon(kind) {
        switch (kind) {
            case "mouse":      return "mouse"
            case "keyboard":   return "keyboard"
            case "controller": return "stadia_controller"
            case "audio":      return "headphones"
            case "phone":      return "smartphone"
            default:           return "devices_other"
        }
    }

    // Wireless peripherals: warn at 15% and again at 5%, once per charge
    property var peripheralWarned: ({})

    function checkPeripheral(id, name, kind, level) {
        if (!root.enabled || !(level > 0)) return
        const step = level <= 0.05 ? 0.05 : level <= 0.15 ? 0.15 : 1
        const warned = root.peripheralWarned[id] ?? 1
        if (step < warned) {
            root.peripheralWarned = Object.assign({}, root.peripheralWarned, { [id]: step })
            const icon = kind === "keyboard" ? "keyboard" : kind === "controller" ? "stadia_controller" : "mouse"
            const title = kind === "keyboard" ? Translation.tr("Keyboard battery low")
                : kind === "controller" ? Translation.tr("Controller battery low") : Translation.tr("Mouse battery low")
            root.show({ kind: "peripheral", icon: icon, tone: "error", title: title, subtitle: IslandEvents.shortName(name),
                value: `${Math.round(level * 100)}%`, actions: [] }, 8000)
        } else if (level > 0.3 && warned < 1) {
            root.peripheralWarned = Object.assign({}, root.peripheralWarned, { [id]: 1 })
        }
    }

    function upowerKind(type) {
        if (type === UPowerDeviceType.Mouse) return "mouse"
        if (type === UPowerDeviceType.Keyboard) return "keyboard"
        if (type === UPowerDeviceType.GamingInput) return "controller"
        return ""
    }

    Instantiator {
        model: UPower.devices
        delegate: Connections {
            required property UPowerDevice modelData
            target: modelData
            function onPercentageChanged() {
                const kind = root.upowerKind(modelData.type)
                if (kind !== "") root.checkPeripheral(modelData.nativePath || modelData.model, modelData.model, kind, modelData.percentage)
            }
        }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property BluetoothDevice modelData
            target: modelData
            function onBatteryChanged() {
                if (!modelData.connected || !modelData.batteryAvailable) return
                const icon = modelData.icon ?? ""
                const kind = /mouse/.test(icon) ? "mouse" : /keyboard/.test(icon) ? "keyboard" : /gaming|joystick/.test(icon) ? "controller" : ""
                if (kind !== "") root.checkPeripheral(modelData.address, modelData.name || modelData.deviceName, kind, Number(modelData.battery))
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Caps Lock: the keyboard LEDs, read a few times per second (no process, just the sysfs file)
    property var capsPaths: []
    property bool capsOn: false
    property bool capsKnown: false

    Process {
        running: root.enabled
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsPaths = text.split("\n").filter(Boolean).map(p => `${p}/brightness`)
        }
    }

    Instantiator {
        id: capsFiles
        model: root.capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: root.readCaps()
        }
    }

    Timer {
        // Polling LEDs is the only way to see Caps Lock without a keyboard grab, but four times a second forever
        // is a lot of wakeups for something that changes a few times a day. Twice a second still feels instant.
        interval: 500
        repeat: true
        running: root.enabled && root.capsPaths.length > 0
        onTriggered: {
            for (let i = 0; i < capsFiles.count; i++) capsFiles.objectAt(i)?.reload()
        }
    }

    function readCaps() {
        let on = false
        for (let i = 0; i < capsFiles.count; i++) {
            if ((capsFiles.objectAt(i)?.text() ?? "").trim() === "1") on = true
        }
        if (!root.capsKnown) {
            root.capsKnown = true
            root.capsOn = on
            return
        }
        if (on === root.capsOn) return
        root.capsOn = on
        root.show({ kind: "caps", icon: "keyboard_capslock", tone: on ? "attention" : "neutral",
            title: on ? Translation.tr("Caps Lock on") : Translation.tr("Caps Lock off"), subtitle: "", value: on ? "ABC" : "abc",
            urgent: true, actions: [] }, 1400)
    }

    // ---------------------------------------------------------------------------------------------
    // Waking up: how long it slept and what it cost in battery (logind's PrepareForSleep)
    property double sleptAt: 0
    property real batteryBeforeSleep: -1

    Process {
        running: root.enabled
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep")) return
                if (line.includes("true")) {
                    root.sleptAt = Date.now()
                    root.batteryBeforeSleep = Battery.available ? Battery.percentage : -1
                } else if (line.includes("false") && root.sleptAt > 0) {
                    wakeDelay.restart()
                }
            }
        }
    }

    function formatSleep(ms) {
        const minutes = Math.round(ms / 60000)
        if (minutes < 60) return `${minutes} min`
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min`
    }

    // What pulled it out of sleep. A machine that wakes up seconds after closing the lid is a bug, not a feature,
    // and the kernel names the culprit: the IRQ that fired is in /sys/power/pm_wakeup_irq, and /proc/interrupts
    // says which device that IRQ belongs to.
    property string wakeCause: ""

    Process {
        id: wakeCauseProc
        command: ["sh", "-c", `
            irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null)
            [ -z "$irq" ] && exit 0
            awk -v want="$irq" '$1 ~ /^[0-9]+:/ { n = substr($1, 1, length($1) - 1); if (n == want) { print $NF; exit } }' /proc/interrupts
        `]
        stdout: StdioCollector {
            onStreamFinished: root.wakeCause = text.trim()
        }
    }

    Timer {
        id: wakeDelay
        interval: 2500
        onTriggered: {
            const ms = Date.now() - root.sleptAt
            root.sleptAt = 0
            // Woke up almost immediately: that is the failure mode worth reporting, with the device that did it
            if (ms < 60000) {
                if (ms > 45000 || !root.enabled) return
                wakeCauseProc.running = true
                shortWakeDelay.slept = ms
                shortWakeDelay.restart()
                return
            }
            const delta = root.batteryBeforeSleep >= 0 && Battery.available ? Math.round((Battery.percentage - root.batteryBeforeSleep) * 100) : null
            root.show({
                kind: "resume", icon: "bedtime", tone: "progress", title: Translation.tr("Slept for %1").arg(root.formatSleep(ms)),
                subtitle: delta === null ? "" : delta === 0 ? Translation.tr("Battery unchanged")
                    : Translation.tr("Battery %1%").arg(delta > 0 ? `+${delta}` : `−${Math.abs(delta)}`),
                value: delta === null || delta === 0 ? "" : `${delta > 0 ? "+" : "−"}${Math.abs(delta)}%`, actions: []
            }, 6000)
        }
    }

    Timer {
        id: shortWakeDelay
        property real slept: 0
        interval: 1200
        onTriggered: root.show({
            kind: "wakeShort", icon: "bedtime_off", tone: "attention", urgent: true,
            title: Translation.tr("Woke up after %1 s").arg(Math.round(shortWakeDelay.slept / 1000)),
            subtitle: root.wakeCause !== "" ? Translation.tr("Woken by %1").arg(root.wakeCause) : Translation.tr("Something woke it up"),
            value: "", actions: [{ id: "wakeSources", label: Translation.tr("Wake sources"), icon: "list" }]
        }, 10000)
    }

    // ---------------------------------------------------------------------------------------------
    // Heat: 15 s above the limit (at most every 10 min), with the fan speed and the busiest process
    property int hotSamples: 0
    property double lastHotAt: 0
    property string fanPath: ""

    // The same numbers the alert uses, kept readable so the system view can show them without waiting for an alert
    readonly property real temperature: ResourceUsage.cpuTemp
    readonly property bool temperatureHot: root.temperature >= root.hotTemperature - 10
    property int fanRpm: 0
    property string powerProfile: "balanced"
    readonly property string powerProfileName: {
        switch (root.powerProfile) {
            case "power-saver":  return Translation.tr("Saver")
            case "performance":  return Translation.tr("Performance")
            default:             return Translation.tr("Balanced")
        }
    }

    function setPowerProfile(profile) {
        Quickshell.execDetached(["powerprofilesctl", "set", profile])
        root.powerProfile = profile
        refreshPowerSoon.restart()
    }

    Timer {
        id: refreshPowerSoon
        interval: 800
        onTriggered: root.refreshPower()
    }

    Process {
        id: powerProfileProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                if (value !== "") root.powerProfile = value
            }
        }
    }

    // These spawn a process, so they run slowly in the background and are refreshed on demand the moment
    // something actually wants to show them (the system panel opening, a profile being switched).
    property bool powerWatch: false

    function refreshPower() {
        powerProfileProc.running = true
        if (root.fanPath !== "") {
            fanFile.reload()
            root.fanRpm = parseInt(fanFile.text()) || 0
        }
    }

    // Only while the System view is open (it sets powerWatch): nothing else needs the fan or a live profile.
    // One read at start so the battery's profile shortcut knows where it's cycling from.
    Timer {
        interval: 5000
        repeat: true
        running: root.enabled && root.powerWatch
        triggeredOnStart: true
        onTriggered: root.refreshPower()
    }
    Component.onCompleted: {
        if (root.enabled) root.refreshPower()
        root.loadDiskState()
    }

    Process {
        running: root.enabled
        command: ["sh", "-c", "ls /sys/class/hwmon/*/fan*_input 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.fanPath = text.trim()
        }
    }

    FileView {
        id: fanFile
        path: root.fanPath
        printErrors: false
    }

    // No timer of its own: listens to the temperature ResourceUsage already samples for the bar
    Connections {
        target: ResourceUsage
        enabled: root.enabled
        function onCpuTempChanged() {
            const temp = ResourceUsage.cpuTemp
            if (temp >= root.hotTemperature) {
                root.hotSamples++
                if (root.fanPath !== "") fanFile.reload()
            } else if (temp < root.hotTemperature - 10) {
                root.hotSamples = 0
            }
            if (root.hotSamples >= 3 && Date.now() - root.lastHotAt > 10 * 60000) root.showHot(temp)
        }
    }

    function showHot(temp) {
        root.lastHotAt = Date.now()
        const rpm = parseInt(fanFile.text()) || 0
        const process = IslandEvents.topProcess
        root.show({
            kind: "thermal", icon: "device_thermostat", tone: "error", title: Translation.tr("Running hot · %1 °C").arg(Math.round(temp)),
            subtitle: [rpm > 0 ? Translation.tr("fan %1 rpm").arg(rpm) : "", process ? `${process} ${Math.round(IslandEvents.topProcessCpu)}%` : ""].filter(Boolean).join(" · "),
            value: `${Math.round(temp)}°`,
            actions: [
                { id: "powerSaver", label: Translation.tr("Power saver"), icon: "energy_savings_leaf" },
                { id: "system", label: Translation.tr("See processes"), icon: "monitoring" }
            ]
        }, 12000)
    }

    // ---------------------------------------------------------------------------------------------
    // Storage almost full. No timer of its own: listens to the `df /` ResourceUsage already runs for the bar.
    // Low (< 10 GB or < 5 %) warns at most every 6 h; critical (< 2 GB or < 2 %) every 30 min. The last time is
    // kept on disk so a shell reload doesn't nag again.
    readonly property int diskLevel: {
        // df fills total, used and free one after another: until all three are in, the numbers don't add up
        const totalKb = ResourceUsage.diskTotal
        if (totalKb <= 1 || ResourceUsage.diskFree <= 0 || ResourceUsage.diskUsed <= 0) return 0
        const freeGb = ResourceUsage.diskFree / 1048576
        const ratio = ResourceUsage.diskFree / totalKb
        return freeGb < 2 || ratio < 0.02 ? 2 : (freeGb < 10 || ratio < 0.05) ? 1 : 0
    }
    property var diskAlertState: ({ at: 0, level: 0 })
    property bool diskStateReady: false

    // Tiny file, read synchronously at start (a missing file raises no signal to wait for)
    FileView {
        id: diskStateFile
        path: `${Quickshell.env("HOME")}/.cache/quickshell/island-disk-alert.json`
        blockLoading: true
        printErrors: false
    }

    function loadDiskState() {
        try {
            root.diskAlertState = JSON.parse(diskStateFile.text()) ?? root.diskAlertState
        } catch (e) {}
        root.diskStateReady = true
        root.checkDisk()
    }

    onDiskLevelChanged: root.checkDisk()
    onEnabledChanged: root.checkDisk()

    function checkDisk() {
        if (!root.enabled || !root.diskStateReady || root.diskLevel === 0 || ResourceUsage.diskTotal <= 1) return
        const since = Date.now() - (root.diskAlertState.at ?? 0)
        const escalated = root.diskLevel > (root.diskAlertState.level ?? 0) && since > 60000
        const cooldown = root.diskLevel === 2 ? 30 * 60000 : 6 * 3600000
        if (!escalated && since < cooldown) return
        root.diskAlertState = { at: Date.now(), level: root.diskLevel }
        diskStateFile.setText(JSON.stringify(root.diskAlertState))
        diskSizesProc.running = true
    }

    // What could be freed right away, measured once when the alert fires
    Process {
        id: diskSizesProc
        command: ["bash", "-c", `du -sb "$HOME/.local/share/Trash" 2>/dev/null | cut -f1; du -sb /var/cache/pacman/pkg 2>/dev/null | cut -f1`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [trash, pkg] = text.trim().split("\n").map(v => parseInt(v) || 0)
                root.showDisk(trash, pkg)
            }
        }
    }

    function showDisk(trashBytes, pkgBytes) {
        const critical = root.diskLevel === 2
        const free = root.formatSize(ResourceUsage.diskFree * 1024)
        const actions = [{ id: "diskUsage", label: Translation.tr("What's using it"), icon: "data_usage" }]
        if (trashBytes > 200e6) actions.push({ id: "trash", label: Translation.tr("Trash · %1").arg(root.formatSize(trashBytes)), icon: "delete" })
        if (pkgBytes > 1e9) actions.push({ id: "pkgCache", label: Translation.tr("Package cache · %1").arg(root.formatSize(pkgBytes)), icon: "inventory_2" })
        root.show({
            kind: "diskLow", icon: critical ? "hard_drive" : "storage", tone: critical ? "error" : "attention", urgent: critical,
            title: critical ? Translation.tr("Disk full") : Translation.tr("Disk almost full"),
            subtitle: Translation.tr("%1 free · %2% used").arg(free).arg(Math.round(ResourceUsage.diskUsedPercentage * 100)),
            value: free, actions: actions
        }, critical ? 20000 : 12000)
    }

    // ---------------------------------------------------------------------------------------------
    function runAction(id) {
        const p = root.current
        if (!p) return
        switch (p.kind) {
            case "monitor":
            case "dock":
                root.applyMonitorLayout(p.output, id)
                break
            case "drive":
                root.driveAction(id)
                break
            case "thermal":
                if (id === "powerSaver") {
                    Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
                    root.update({ status: Translation.tr("Power saver on") })
                } else if (id === "system") {
                    IslandEvents.viewRequested("system")
                }
                break
            case "diskLow":
                if (id === "diskUsage") {
                    Quickshell.execDetached(["kitty", "--class", "ilha-disk", "--title", "Uso do disco",
                        "fish", "-c", "dust -n 40 -d 3 ~; echo; read -P 'Enter para fechar '"])
                } else if (id === "trash") {
                    Quickshell.execDetached(["dolphin", "trash:/"])
                } else if (id === "pkgCache") {
                    // In a terminal, on purpose: you see what goes before it goes
                    Quickshell.execDetached(["kitty", "--class", "ilha-disk", "--title", "Cache de pacotes",
                        "fish", "-c", "echo 'Mantendo só a versão instalada de cada pacote:'; sudo paccache -rk1; sudo paccache -ruk0; echo; df -h /; read -P 'Enter para fechar '"])
                }
                break
            case "monitorConfirm":
                if (id === "keepLayout") {
                    layoutCountdown.stop()
                    root.layoutPending = ""
                    root.update({ title: Translation.tr("Layout kept"), subtitle: "", actions: [] })
                    root.dismiss()
                }
                break
            case "wakeShort":
                if (id === "wakeSources") {
                    Quickshell.execDetached(["kitty", "--class", "ilha-wakeups", "--title", "Fontes de wake",
                        "fish", "-c", "cat /proc/acpi/wakeup; echo; echo 'IRQ do último wake:'; cat /sys/power/pm_wakeup_irq; echo; read -P 'Enter para fechar '"])
                }
                break
        }
    }

    // Test payloads (ilha-teste). Actions on fake devices just report that they couldn't run.
    function simulate(kind) {
        const monitorActions = [
            { id: "extend", label: Translation.tr("Extend"), icon: "splitscreen_right" },
            { id: "mirror", label: Translation.tr("Mirror"), icon: "screen_share" },
            { id: "only", label: Translation.tr("External only"), icon: "tv" }
        ]
        switch (kind) {
            case "monitor":
                root.show({ kind: "monitor", icon: "desktop_windows", tone: "progress", title: Translation.tr("Monitor connected"),
                    subtitle: "DELL U2723QE · 2560×1440 · 60 Hz", value: "", output: "", resolution: "2560×1440", layout: "extend", actions: monitorActions }, 12000)
                break
            case "drive":
                root.show({ kind: "drive", icon: "usb", tone: "progress", title: Translation.tr("%1 connected").arg("KINGSTON"),
                    subtitle: "32 GB · VFAT", value: "", device: "/dev/ilha-teste1", disk: "/dev/ilha-teste", label: "KINGSTON",
                    actions: [
                        { id: "open", label: Translation.tr("Open"), icon: "folder_open" },
                        { id: "copyPrints", label: Translation.tr("Copy today's prints"), icon: "photo_library" },
                        { id: "eject", label: Translation.tr("Eject"), icon: "eject" }
                    ] }, 12000)
                break
            case "driveSafe":
                root.show({ kind: "driveSafe", icon: "check_circle", tone: "success", title: Translation.tr("Safe to remove"), subtitle: "KINGSTON", value: "", actions: [] }, 5000)
                break
            case "dock":
                root.show({ kind: "dock", icon: "dock", tone: "progress", title: Translation.tr("Dock connected"),
                    subtitle: `${Translation.tr("1 monitor")} · ${Translation.tr("network")} · USB · 65 W`, value: "", output: "", resolution: "2560×1440",
                    layout: "extend", actions: monitorActions }, 12000)
                break
            case "charger":
                root.show({ kind: "charger", icon: "battery_charging_20", tone: "attention", title: Translation.tr("Slow charger"),
                    subtitle: Translation.tr("Charging at %1 W · it will take longer").arg(15), value: "15 W", actions: [] }, 8000)
                break
            case "peripheral":
                root.show({ kind: "peripheral", icon: "mouse", tone: "error", title: Translation.tr("Mouse battery low"), subtitle: "MX Master 3S", value: "12%", actions: [] }, 8000)
                break
            case "controller":
                root.show({ kind: "controller", icon: "stadia_controller", tone: "success", title: Translation.tr("Controller connected"),
                    subtitle: "Xbox Wireless Controller", value: "80%", actions: [] }, 5000)
                break
            case "caps":
                root.show({ kind: "caps", icon: "keyboard_capslock", tone: "attention", title: Translation.tr("Caps Lock on"), subtitle: "", value: "ABC", urgent: true, actions: [] }, 1400)
                break
            case "layout":
                root.show({ kind: "layout", icon: "keyboard", tone: "progress", title: Translation.tr("Keyboard layout"), subtitle: "English (US)", value: "US", urgent: true, actions: [] }, 1600)
                break
            case "resume":
                root.show({ kind: "resume", icon: "bedtime", tone: "progress", title: Translation.tr("Slept for %1").arg("2 h 14 min"),
                    subtitle: Translation.tr("Battery %1%").arg("−3"), value: "−3%", actions: [] }, 6000)
                break
            case "diskLow":
                diskSizesProc.running = true
                break
            case "thermal":
                root.show({ kind: "thermal", icon: "device_thermostat", tone: "error", title: Translation.tr("Running hot · %1 °C").arg(94),
                    subtitle: `${Translation.tr("fan %1 rpm").arg(5200)} · cargo 380%`, value: "94°",
                    actions: [
                        { id: "powerSaver", label: Translation.tr("Power saver"), icon: "energy_savings_leaf" },
                        { id: "system", label: Translation.tr("See processes"), icon: "monitoring" }
                    ] }, 12000)
                break
        }
    }

    IpcHandler {
        target: "hardware"

        function simulate(kind: string): void {
            root.simulate(kind)
        }
        function action(id: string): void {
            root.runAction(id)
        }
    }
}
