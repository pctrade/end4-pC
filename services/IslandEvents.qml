pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Short-lived system events and live activities surfaced by the dynamic island.
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.bar.dynamicIsland

    // Startup emits a burst of "changes" (clipboard load, sink discovery, first weather fetch)
    property bool armed: false
    Timer {
        interval: 5000
        running: Config.ready
        onTriggered: root.armed = true
    }

    component Flash: QtObject {
        id: flash
        property int duration: 3000
        property bool active: false
        property var payload: null
        property bool held: false
        readonly property Timer timer: Timer {
            interval: flash.duration
            onTriggered: if (!flash.held) flash.active = false
        }
        function show(p, ms) {
            flash.payload = p
            flash.timer.interval = ms ?? flash.duration
            flash.active = true
            flash.timer.restart()
        }
        function hold(value) {
            flash.held = value
            if (!value) {
                flash.timer.interval = flash.duration
                flash.timer.restart()
            }
        }
        function dismiss() {
            flash.held = false
            flash.active = false
        }
    }

    // Semantic colors, one meaning on every island: needs you, problem, done, in progress
    readonly property color colorAttention: "#FF9F0A"
    readonly property color colorError: Appearance.colors.colError
    readonly property color colorSuccess: Appearance.m3colors.m3success
    readonly property color colorProgress: Appearance.colors.colPrimary

    function toneColor(tone) {
        switch (tone) {
            case "attention": return root.colorAttention
            case "error": return root.colorError
            case "success": return root.colorSuccess
            case "neutral": return Appearance.colors.colOnLayer0
            default: return root.colorProgress
        }
    }

    // The Material symbol for an OpenWeather condition code, shared by every island that shows the weather
    function weatherSymbol(code) {
        switch (Math.floor((code ?? 800) / 100)) {
            case 2: return "thunderstorm"
            case 3: return "rainy_light"
            case 5: return "rainy"
            case 6: return "weather_snowy"
            case 7: return "foggy"
            default:
                if (code !== 800) return "cloud"
                const hour = new Date().getHours()
                return hour >= 18 || hour < 6 ? "clear_night" : "clear_day"
        }
    }

    // Short names: brands, vendors, serial numbers and paths take room without saying anything new
    function shortName(text) {
        const original = (text ?? "").toString().trim()
        if (original === "") return ""
        if (/^\/\S+$/.test(original)) return original.split("/").pop()
        const known = { "Google Chrome": "Chrome", "Mozilla Firefox": "Firefox", "Visual Studio Code": "VS Code", "Zen Browser": "Zen" }
        if (known[original]) return known[original]
        const name = original
            .replace(/^(soundcore|anker|jbl|sony|samsung|logitech|dell inc\.|lg electronics|google|mozilla|microsoft)\s+/i, "")
            .replace(/\s*\([^)]*\)\s*$/, "")
            .replace(/\s+[A-Z0-9]{8,}$/, "")
            .trim()
        return name !== "" ? name : original
    }

    property Flash clipboard: Flash { duration: 10000 }
    property Flash screenshot: Flash { duration: 5500 }
    property Flash bluetooth: Flash { duration: 3200 }
    property Flash audioOutput: Flash { duration: 3000 }
    property Flash weather: Flash { duration: 6500 }
    property Flash songRecResult: Flash { duration: 8000 }

    signal activityFinished(var activity)
    signal expandRequested()
    signal levelRequested(int level)
    signal cycleRequested(int direction)
    signal pinnedCycleRequested(int direction)
    signal pinToggleRequested()
    signal simulateRequested(string name)
    signal viewRequested(string view)
    signal splitRequested(string id)
    signal scrollRequested(int direction)
    signal homeRequested()
    signal dismissRequested()
    signal silenceRequested()

    // Clipboard
    property string lastClipEntry: ""
    property int lastClipCount: 0
    property real lastScreenshotAt: 0
    property real quietClipboardUntil: 0

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            const top = Cliphist.entries[0] ?? ""
            const count = Cliphist.entries.length
            const firstLoad = root.lastClipEntry === ""
            const changed = top !== root.lastClipEntry && count >= root.lastClipCount
            root.lastClipEntry = top
            root.lastClipCount = count
            if (firstLoad || !changed || !root.armed || !(root.cfg.clipboard ?? true) || top === "") return
            if (Date.now() < root.quietClipboardUntil) return
            const isImage = Cliphist.entryIsImage(top)
            if (isImage && Date.now() - root.lastScreenshotAt < 3000) return
            root.clipboard.show(root.payloadFor(top))
            root.clipboardImagePath = ""
            if (isImage) {
                clipDecodeProc.entry = top
                clipDecodeProc.target = `/tmp/quickshell/island/clipboard-${Date.now()}.png`
                clipDecodeProc.running = true
            }
        }
    }

    function payloadFor(entry) {
        const isImage = Cliphist.entryIsImage(entry)
        const text = entry.replace(/^\d+\t/, "").trim()
        // Files copied in a file manager arrive as file:// lines (or plain absolute paths)
        const files = isImage ? [] : text.split(/\r?\n/).map(s => s.trim())
            .filter(s => /^file:\/\//.test(s) || /^\/\S.*\.[A-Za-z0-9]{1,8}$/.test(s))
            .map(s => s.startsWith("file://") ? decodeURIComponent(s.slice(7)) : s)
        return { entry: entry, isImage: isImage, text: text, files: files }
    }

    // What the pinned clipboard island shows when nothing was just copied
    readonly property var latestClipboard: Cliphist.entries.length > 0 ? root.payloadFor(Cliphist.entries[0]) : ({})

    // Copied images get a real file so they can be dragged, saved or converted
    property string clipboardImagePath: ""

    Process {
        id: clipDecodeProc
        property string entry: ""
        property string target: ""
        command: ["bash", "-c", `mkdir -p /tmp/quickshell/island && printf '%s' '${StringUtils.shellSingleQuoteEscape(clipDecodeProc.entry)}' | ${Cliphist.cliphistBinary} decode > '${clipDecodeProc.target}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.clipboardImagePath = clipDecodeProc.target
        }
    }

    // Screenshots saved to ~/Pictures/Prints
    FolderListModel {
        id: printsModel
        property int knownCount: -1
        folder: `file://${Directories.pictures}/Prints`
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Time

        onStatusChanged: if (status === FolderListModel.Ready && knownCount < 0) knownCount = count
        onCountChanged: {
            if (status !== FolderListModel.Ready || knownCount < 0) return
            const grew = count > knownCount
            knownCount = count
            if (!grew || !root.armed || !(root.cfg.screenshots ?? true)) return
            root.lastScreenshotAt = Date.now()
            screenshotSettleTimer.restart()
        }
    }

    Timer {
        id: screenshotSettleTimer
        interval: 450
        onTriggered: {
            let newest = 0
            let path = ""
            for (let i = 0; i < printsModel.count; i++) {
                const modified = printsModel.get(i, "fileModified")
                if (modified > newest) {
                    newest = modified
                    path = printsModel.get(i, "filePath")
                }
            }
            if (path !== "") root.screenshot.show({ path: path, name: path.split("/").pop() })
        }
    }

    // Bluetooth devices
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property BluetoothDevice modelData
            target: modelData
            function onStateChanged() {
                root.bluetoothDeviceChanged(modelData)
            }
            function onBatteryChanged() {
                root.bluetoothBatteryChanged(modelData)
            }
        }
    }

    function bluetoothDeviceChanged(device) {
        if (!root.armed || !(root.cfg.bluetooth ?? true)) return
        let phase = ""
        switch (device.state) {
            case BluetoothDeviceState.Connecting: phase = "connecting"; break
            case BluetoothDeviceState.Connected: phase = "connected"; break
            case BluetoothDeviceState.Disconnected: phase = "disconnected"; break
            default: return
        }
        if (/audio/.test(device.icon ?? "") && (root.cfg.pauseOnHeadphonesDisconnect ?? true)) root.headphonesChanged(phase)
        // Headphones that connect should get the sound. PipeWire only publishes their sink a beat after BlueZ
        // says "connected", so the switch waits for the sink to show up instead of firing into the void.
        if (phase === "connected" && /audio|headset|headphone/.test(device.icon ?? "") && (root.cfg.followHeadphones ?? true)) {
            root.pendingSinkAddress = device.address
            root.pendingSinkName = device.name || device.deviceName || ""
            sinkFollowTimer.restart()
        }
        const payload = {
            address: device.address,
            name: device.name || device.deviceName || Translation.tr("Bluetooth device"),
            icon: device.icon ?? "",
            phase: phase
        }
        root.bluetooth.show(payload, phase === "connecting" ? 20000 : undefined)
    }

    // Moving the sound to a device that just arrived
    property string pendingSinkAddress: ""
    property string pendingSinkName: ""
    property int sinkFollowTries: 0

    function sinkForAddress(address) {
        const key = (address ?? "").toUpperCase().replace(/:/g, "_")
        if (key === "") return null
        return Audio.outputDevices.find(sink => {
            const props = sink?.properties ?? {}
            const haystack = `${sink?.name ?? ""} ${props["device.name"] ?? ""} ${props["api.bluez5.address"] ?? ""}`.toUpperCase()
            return haystack.includes(key) || haystack.includes(key.replace(/_/g, ":"))
        }) ?? null
    }

    Timer {
        id: sinkFollowTimer
        interval: 700
        repeat: true
        running: false
        onTriggered: {
            const sink = root.sinkForAddress(root.pendingSinkAddress)
            if (sink) {
                sinkFollowTimer.stop()
                root.sinkFollowTries = 0
                if (Audio.sink === sink) return
                root.audioOutput.show({
                    name: root.pendingSinkName || Audio.friendlyDeviceName(sink),
                    icon: root.sinkIcon(sink),
                    isBluetooth: true,
                    switching: true
                }, 4200)
                Audio.setDefaultSink(sink)
                return
            }
            // Give it about seven seconds: after that the device simply has no sink (a controller, a keyboard)
            root.sinkFollowTries++
            if (root.sinkFollowTries > 10) {
                sinkFollowTimer.stop()
                root.sinkFollowTries = 0
            }
        }
    }

    function appColor(appName, fallback) {
        const name = (appName ?? "").toLowerCase()
        const known = [
            ["whatsapp", "#25D366"], ["zapzap", "#25D366"], ["telegram", "#2AABEE"], ["discord", "#5865F2"],
            ["vesktop", "#5865F2"], ["signal", "#3A76F0"], ["slack", "#E01E5A"], ["spotify", "#1DB954"],
            ["firefox", "#FF7139"], ["zen", "#F76F53"], ["chrom", "#4285F4"], ["gmail", "#EA4335"],
            ["thunderbird", "#0A84FF"], ["steam", "#66C0F4"], ["teams", "#6264A7"], ["instagram", "#E1306C"]
        ]
        for (const [key, color] of known) {
            if (name.includes(key)) return color
        }
        return fallback
    }

    function bluetoothSymbol(iconName) {
        const name = iconName ?? ""
        if (/audio-head/.test(name)) return "earbuds"
        if (/audio/.test(name)) return "speaker"
        if (/mouse/.test(name)) return "mouse"
        if (/keyboard/.test(name)) return "keyboard"
        if (/phone/.test(name)) return "smartphone"
        if (/gaming|joystick/.test(name)) return "stadia_controller"
        return "bluetooth"
    }

    function bluetoothDevice(address) {
        return Bluetooth.devices.values.find(d => d.address === address) ?? null
    }

    // Headphone battery: warn once at 20% and again at 10% per charge
    property var lowBatteryWarned: ({})

    function bluetoothBatteryChanged(device) {
        if (!root.armed || !(root.cfg.bluetooth ?? true) || !device.connected || !device.batteryAvailable) return
        if (!/audio/.test(device.icon ?? "")) return
        const level = Number(device.battery)
        const address = device.address
        const warned = root.lowBatteryWarned[address] ?? 1
        const step = level <= 0.1 ? 0.1 : level <= 0.2 ? 0.2 : 1
        if (step < warned) {
            root.lowBatteryWarned = Object.assign({}, root.lowBatteryWarned, { [address]: step })
            root.bluetooth.show({ address: address, name: device.name || device.deviceName, icon: device.icon ?? "", phase: "lowBattery", battery: level }, 7000)
        } else if (level > 0.3 && warned < 1) {
            root.lowBatteryWarned = Object.assign({}, root.lowBatteryWarned, { [address]: 1 })
        }
    }

    // Earbuds case art: loaded once, recolored to the theme's primary hue keeping each shade's lightness
    property string caseClosedRaw: ""
    property string caseOpenRaw: ""
    readonly property string caseClosedArt: root.themedSvg(root.caseClosedRaw, Appearance.colors.colPrimary)
    readonly property string caseOpenArt: root.themedSvg(root.caseOpenRaw, Appearance.colors.colPrimary)

    FileView {
        path: Quickshell.shellPath("assets/island/soundcore/case-closed.svg")
        printErrors: false
        onLoaded: root.caseClosedRaw = text()
    }
    FileView {
        path: Quickshell.shellPath("assets/island/soundcore/case-open.svg")
        printErrors: false
        onLoaded: root.caseOpenRaw = text()
    }

    function themedSvg(svg, tint) {
        if (svg === "") return ""
        const hue = Math.max(0, tint.hslHue)
        const saturation = Math.min(1, Math.max(0.25, tint.hslSaturation))
        const recolored = svg.replace(/fill="#([0-9A-Fa-f]{6})"/g, (match, hex) => {
            const shade = Qt.color(`#${hex}`)
            return `fill="${Qt.hsla(hue, saturation, shade.hslLightness, 1)}"`
        })
        return `data:image/svg+xml;base64,${Qt.btoa(recolored)}`
    }

    function hasCaseArt(name) {
        const lower = (name ?? "").toLowerCase()
        return lower !== "" && (root.cfg.caseArtDevices ?? []).some(d => lower.includes(d.toLowerCase()))
    }

    // Default audio output
    property string lastSinkName: ""

    function sinkIcon(sink) {
        const name = sink?.name ?? ""
        const props = sink?.properties ?? {}
        const formFactor = `${props["device.form-factor"] ?? props["device.form_factor"] ?? ""} ${props["device.icon-name"] ?? props["device.icon_name"] ?? ""}`
        if (name.startsWith("bluez") || /head(phone|set)/.test(formFactor)) return "earbuds"
        if (/hdmi|displayport/i.test(name)) return "tv"
        return "speaker"
    }

    Connections {
        target: Audio
        function onSinkChanged() {
            const sink = Audio.sink
            const name = sink?.name ?? ""
            if (name === "" || name === root.lastSinkName) return
            const firstSink = root.lastSinkName === ""
            root.lastSinkName = name
            if (firstSink || !root.armed || !(root.cfg.audioOutput ?? true)) return
            if (name.startsWith("bluez") && (root.bluetooth.active || root.audioOutput.active)) return
            root.audioOutput.show({ name: Audio.friendlyDeviceName(sink), icon: root.sinkIcon(sink), isBluetooth: name.startsWith("bluez") })
        }
    }

    // Weather turning into rain/snow/storm
    property int lastWeatherGroup: -1

    Connections {
        target: Weather
        function onDataChanged() {
            const code = Weather.data?.wCode ?? 0
            if (!code) return
            const group = Math.floor(code / 100)
            const previous = root.lastWeatherGroup
            root.lastWeatherGroup = group
            if (previous < 0 || previous === group || !root.armed || !(root.cfg.weatherAlerts ?? true)) return
            if (![2, 3, 5, 6].includes(group)) return
            root.weather.show({ group: group, code: code, temp: Weather.data.temp, description: Weather.data.description, city: Weather.data.city })
        }
    }

    // Sustained CPU load
    property real loadSeconds: 0
    property bool systemLoadActive: false
    property string topProcess: ""
    property real topProcessCpu: 0

    // No timer of its own: ResourceUsage already samples the CPU for the bar, so this just listens to it and
    // counts real seconds between samples (the bar's interval, 3 s by default)
    property double lastLoadSample: 0

    Connections {
        target: ResourceUsage
        enabled: root.cfg.systemLoad ?? true
        function onCpuUsageChanged() {
            if (root.fakeLoad) return
            const now = Date.now()
            const seconds = root.lastLoadSample > 0 ? Math.min(10, (now - root.lastLoadSample) / 1000) : 1
            root.lastLoadSample = now
            const threshold = (root.cfg.systemLoadThreshold ?? 90) / 100
            const cpu = ResourceUsage.cpuUsage
            if (cpu >= threshold) root.loadSeconds = Math.min(root.loadSeconds + seconds, 30)
            else if (cpu < threshold - 0.1) root.loadSeconds = Math.max(root.loadSeconds - 2 * seconds, 0)
            if (!root.systemLoadActive && root.loadSeconds >= 10) root.systemLoadActive = true
            else if (root.systemLoadActive && root.loadSeconds <= 0) root.systemLoadActive = false
        }
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.systemLoadActive
        onTriggered: topProcessProc.running = true
    }

    Process {
        id: topProcessProc
        command: ["bash", "-c", "ps -eo comm=,%cpu= --sort=-%cpu | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.trim().match(/^(.*\S)\s+([\d.]+)$/)
                if (!match) return
                root.topProcess = match[1]
                root.topProcessCpu = parseFloat(match[2])
            }
        }
    }

    // Song recognition result
    property string lastSongTitle: ""

    Connections {
        target: SongRec
        function onRecognizedTrackChanged() {
            const track = SongRec.recognizedTrack
            if (!track?.title || track.title === root.lastSongTitle) return
            root.lastSongTitle = track.title
            root.songRecResult.show({ title: track.title, subtitle: track.subtitle, url: track.url })
        }
    }

    // Privacy: microphone, camera and screen capture consumers
    readonly property var privacyLinks: Pipewire.linkGroups.values.filter(g => g.source && g.target && (
        (g.source.type === PwNodeType.AudioSource && g.target.type === PwNodeType.AudioInStream)
        || g.source.type === PwNodeType.VideoSource))

    PwObjectTracker {
        objects: [...root.privacyLinks.map(g => g.target), ...root.privacyLinks.map(g => g.source)]
    }

    function nodeAppLabel(node) {
        const props = node?.properties ?? {}
        return props["application.name"] || props["application.process.binary"] || node?.description || node?.name || "?"
    }

    function privacyIgnored(label) {
        const lower = label.toLowerCase()
        return (root.cfg.privacyIgnoredApps ?? []).some(app => lower.includes(app.toLowerCase()))
    }

    readonly property var privacy: {
        const mic = []
        const camera = []
        const screen = []
        for (const link of root.privacyLinks) {
            const label = root.nodeAppLabel(link.target)
            if (root.privacyIgnored(label)) continue
            if (link.source.type === PwNodeType.AudioSource) {
                if (!mic.includes(label)) mic.push(label)
                continue
            }
            const props = link.source.properties ?? {}
            const isCamera = (props["device.api"] ?? "") === "v4l2" || props["api.v4l2.path"] !== undefined
                || (props["media.role"] ?? "") === "Camera" || (link.source.name ?? "").startsWith("v4l2")
            const target = isCamera ? camera : screen
            if (!target.includes(label)) target.push(label)
        }
        if (root.fakePrivacy) {
            mic.push("Teste")
            camera.push("Teste")
        }
        return { mic: mic, camera: camera, screen: screen }
    }
    readonly property bool micInUse: root.privacy.mic.length > 0
    readonly property bool cameraInUse: root.privacy.camera.length > 0
    readonly property bool screenInUse: root.privacy.screen.length > 0
    readonly property bool anyPrivacy: root.micInUse || root.cameraInUse || root.screenInUse

    // Headphones: pause when they drop, resume when they come back (after the audio route settles)
    property bool pausedByHeadphones: false

    function headphonesChanged(phase) {
        const player = MprisController.activePlayer
        if (phase === "disconnected") {
            headphonesResume.stop()
            if (player?.isPlaying) {
                player.pause()
                root.pausedByHeadphones = true
            }
        } else if (phase === "connected" && root.pausedByHeadphones) {
            root.pausedByHeadphones = false
            headphonesResume.restart()
        }
    }

    Timer {
        id: headphonesResume
        interval: 1500
        onTriggered: MprisController.activePlayer?.play()
    }

    // ZeroTier's virtual interface breaks WebRTC voice in Vesktop/Discord: warn during calls, offer to stop it,
    // and offer to bring it back once the call is over
    readonly property bool voiceCallActive: root.privacyLinks.some(link => link.source.type === PwNodeType.AudioSource
        && /vesktop|discord|webcord/i.test(`${link.target.properties?.["application.name"] ?? ""} ${link.target.properties?.["application.process.binary"] ?? ""}`))
    property bool ztWarned: false
    property bool ztStoppedForCall: false

    // How long you have been on the call: worth anchoring, since a call is exactly when you lose track of time
    property double voiceCallSince: 0
    property int voiceCallMinutes: 0

    Timer {
        interval: 15000
        repeat: true
        running: root.voiceCallActive
        triggeredOnStart: true
        onTriggered: root.voiceCallMinutes = root.voiceCallSince > 0
            ? Math.floor((Date.now() - root.voiceCallSince) / 60000) : 0
    }

    onVoiceCallActiveChanged: {
        root.voiceCallSince = root.voiceCallActive ? Date.now() : 0
        root.voiceCallMinutes = 0
        if (root.voiceCallActive) {
            ztProbe.running = true
            return
        }
        root.ztWarned = false
        if (root.ztStoppedForCall) {
            root.ztStoppedForCall = false
            root.networkAlert.show({ kind: "ztRestore", name: "ZeroTier" }, 15000)
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.voiceCallActive && !root.ztWarned
        onTriggered: ztProbe.running = true
    }

    Process {
        id: ztProbe
        command: ["sh", "-c", "ls /sys/class/net | grep -q '^zt'"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || !root.voiceCallActive || root.ztWarned || !(root.cfg.network ?? true)) return
            root.ztWarned = true
            root.networkAlert.show({ kind: "zerotier", name: "ZeroTier" }, 15000)
        }
    }

    Process {
        id: ztControl
        property bool starting: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.networkAlert.show({ kind: "ztFailed", name: "ZeroTier" })
                return
            }
            if (ztControl.starting) {
                root.networkAlert.show({ kind: "connected", name: "ZeroTier" })
            } else {
                root.ztStoppedForCall = root.voiceCallActive
                root.networkAlert.show({ kind: "ztOff", name: "ZeroTier" })
            }
        }
    }

    function setZeroTier(on) {
        if (ztControl.running) return
        ztControl.starting = on
        ztControl.command = ["sudo", "-n", "systemctl", on ? "start" : "stop", "zerotier-one"]
        ztControl.running = true
    }

    function toggleZeroTier() {
        root.setZeroTier(!root.ztUp)
    }

    // Whether ZeroTier is actually up, and on which network — it breaks voice calls, so it is worth seeing
    // at a glance instead of only hearing about it once a call is already broken.
    property bool ztUp: false
    property string ztNetwork: ""
    property bool ztBusy: ztControl.running

    Process {
        id: ztState
        command: ["sh", "-c", "ip -o -4 addr show | awk '$2 ~ /^zt/ { print $2\" \"$4 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] ?? ""
                root.ztUp = line !== ""
                root.ztNetwork = line === "" ? "" : line.split(" ")[1].split("/")[0]
            }
        }
    }

    // A VPN interface appears and disappears a couple of times a week, so polling it every ten seconds is pure
    // waste. It is checked slowly, and immediately whenever it starts mattering: during a call, or while the
    // ZeroTier island is the one on screen.
    property bool ztWatch: false

    Timer {
        interval: (root.ztWatch || root.voiceCallActive) ? 5000 : 120000
        repeat: true
        running: (root.cfg.network ?? true) && Config.ready
        triggeredOnStart: true
        onTriggered: ztState.running = true
    }

    // 14. A Wi-Fi that connects but does not reach the internet is almost always a captive portal (a café, a
    // hotel, the university). Instead of leaving you to discover it by a page that never loads, the island
    // checks for the redirect the moment a network comes up and offers to open the login page.
    property bool portalChecking: false

    Connections {
        target: Network
        function onNetworkNameChanged() {
            if (!(root.cfg.network ?? true) || !root.armed) return
            portalDelay.restart()
        }
    }

    Timer {
        id: portalDelay
        interval: 3500
        onTriggered: {
            root.portalChecking = true
            portalProbe.running = true
        }
    }

    Process {
        id: portalProbe
        // The standard "am I behind a portal" endpoint: a 204 with no body means the internet is really there
        command: ["curl", "-s", "-m", "6", "-o", "/dev/null", "-w", "%{http_code} %{redirect_url}",
            "http://connectivitycheck.gstatic.com/generate_204"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.portalChecking = false
                const parts = text.trim().split(" ")
                const code = parts[0] ?? ""
                const redirect = parts.slice(1).join(" ")
                if (code === "204" || code === "") return
                root.networkAlert.show({
                    kind: "portal",
                    name: Network.networkName || Translation.tr("this network"),
                    url: redirect
                }, 20000)
            }
        }
    }

    function openCaptivePortal(url) {
        Qt.openUrlExternally(url && url !== "" ? url : "http://connectivitycheck.gstatic.com/generate_204")
        root.networkAlert.dismiss()
    }

    // 15. Keeping the machine awake on purpose: a download that must finish, a video playing to the room, a
    // long build. systemd-inhibit holds the lock for as long as its child lives, so the island owns that child.
    property bool caffeineOn: false
    property double caffeineUntil: 0

    function toggleCaffeine(minutes) {
        if (root.caffeineOn) {
            caffeineProc.running = false
            root.caffeineOn = false
            root.caffeineUntil = 0
            root.upsertActivity("caffeine", Translation.tr("Sleep allowed again"), "", "bedtime", 1, "done")
            return
        }
        const span = minutes ?? 60
        root.caffeineUntil = span > 0 ? Date.now() + span * 60000 : 0
        caffeineProc.command = ["systemd-inhibit", "--what=idle:sleep", "--who=Ilha", "--why=Café",
            "sleep", span > 0 ? `${span * 60}` : "infinity"]
        caffeineProc.running = true
        root.caffeineOn = true
    }

    Process {
        id: caffeineProc
        onExited: (exitCode, exitStatus) => {
            root.caffeineOn = false
            root.caffeineUntil = 0
            root.removeActivity("caffeine")
        }
    }

    property double caffeineNow: 0
    readonly property int caffeineMinutesLeft: root.caffeineUntil > 0
        ? Math.max(0, Math.ceil((root.caffeineUntil - root.caffeineNow) / 60000)) : -1

    Timer {
        interval: 20000
        repeat: true
        running: root.caffeineOn && root.caffeineUntil > 0
        triggeredOnStart: true
        onTriggered: {
            root.caffeineNow = Date.now()
            if (root.caffeineUntil > 0) {
                root.upsertActivity("caffeine", Translation.tr("Staying awake"),
                    root.caffeineMinutesLeft > 0 ? Translation.tr("%1 min left").arg(root.caffeineMinutesLeft) : "",
                    "local_cafe", -1, "running")
            }
        }
    }

    // Focus Mode (seção 33): a context, not a timer app. While it's on, non-critical notifications skip
    // the Peek entirely and go straight to History — Critical still gets through. No forced duration;
    // it just changes how the island behaves until you turn it off yourself.
    property bool focusOn: false
    property double focusSince: 0
    property int focusSuppressedCount: 0

    function toggleFocus() {
        if (root.focusOn) {
            root.focusOn = false
            const minutes = Math.max(1, Math.round((Date.now() - root.focusSince) / 60000))
            const suppressed = root.focusSuppressedCount
            root.focusSuppressedCount = 0
            root.upsertActivity("focus", Translation.tr("Focus finished"),
                suppressed > 0 ? Translation.tr("%1 min · %2 waiting").arg(minutes).arg(suppressed) : Translation.tr("%1 min").arg(minutes),
                "psychology", 1, "done")
            return
        }
        root.focusOn = true
        root.focusSince = Date.now()
        root.focusSuppressedCount = 0
        root.upsertActivity("focus", Translation.tr("Focus"), "", "psychology", -1, "running")
    }

    Connections {
        target: Notifications
        function onNotify(notification) {
            if (!root.focusOn) return
            if ((notification?.urgency ?? "").toLowerCase() === "critical") return
            root.focusSuppressedCount++
        }
    }

    property double focusNow: 0
    readonly property int focusMinutes: root.focusOn ? Math.max(0, Math.round((root.focusNow - root.focusSince) / 60000)) : 0

    Timer {
        interval: 20000
        repeat: true
        running: root.focusOn
        triggeredOnStart: true
        onTriggered: {
            root.focusNow = Date.now()
            root.upsertActivity("focus", Translation.tr("Focus"),
                root.focusSuppressedCount > 0 ? Translation.tr("%1 min · %2 waiting").arg(root.focusMinutes).arg(root.focusSuppressedCount)
                    : Translation.tr("%1 min").arg(root.focusMinutes),
                "psychology", -1, "running")
        }
    }

    // Copied YouTube links: download the video or just the audio straight into the drawer
    readonly property bool mediaDownloadBusy: mediaDownloadProc.running

    function downloadMedia(url, audioOnly) {
        if (mediaDownloadProc.running) return
        mediaDownloadProc.activityId = `ytdlp-${Date.now()}`
        mediaDownloadProc.file = ""
        root.upsertActivity(mediaDownloadProc.activityId, audioOnly ? Translation.tr("Downloading audio") : Translation.tr("Downloading video"),
            url.replace(/^https?:\/\/(www\.|m\.)?/, ""), audioOnly ? "music_note" : "movie", -1, "running")
        mediaDownloadProc.command = ["yt-dlp", "--newline", "--no-playlist", "--progress", "-P", DropShelf.storeDir,
            "-o", "%(title).80B.%(ext)s", "--progress-template", "download:ISLAND %(progress._percent_str)s",
            "--print", "after_move:FILE %(filepath)s",
            ...(audioOnly ? ["-x", "--audio-format", "mp3"] : ["-f", "bv*[height<=1080]+ba/b[height<=1080]/b", "--merge-output-format", "mp4"]),
            url]
        mediaDownloadProc.running = true
    }

    Process {
        id: mediaDownloadProc
        property string activityId: ""
        property string file: ""
        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim()
                const progress = /^ISLAND\s+([\d.]+)%/.exec(trimmed)
                if (progress) root.upsertActivity(mediaDownloadProc.activityId, "", undefined, "", Math.min(1, Number(progress[1]) / 100), "running")
                const file = /^FILE (.+)$/.exec(trimmed)
                if (file) mediaDownloadProc.file = file[1]
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && mediaDownloadProc.file !== "") {
                DropShelf.addItems([`file://${mediaDownloadProc.file}`])
                root.upsertActivity(mediaDownloadProc.activityId, Translation.tr("Saved to the drawer"), DropShelf.fileName(mediaDownloadProc.file), "", 1, "done")
            } else {
                root.upsertActivity(mediaDownloadProc.activityId, "", Translation.tr("Download failed"), "", -1, "error")
            }
        }
    }

    // Copied text in another language: translate to Portuguese (translate-shell)
    property var translation: ({ source: "", result: "", busy: false })

    function looksForeign(text) {
        const t = (text ?? "").trim()
        if (t.length < 12 || /^https?:\/\//.test(t) || t.split(/\s+/).length < 3) return false
        if (/[Ѐ-ӿ؀-ۿ぀-ヿ一-鿿가-힯]/.test(t)) return true
        const words = t.toLowerCase().match(/[a-zà-úñ']+/g) ?? []
        const portuguese = ["não", "nao", "você", "voce", "é", "que", "de", "do", "da", "os", "as", "um", "uma", "para", "com", "isso", "está", "esta", "muito", "também", "mas", "eu", "ele", "ela", "no", "na", "em"]
        const foreign = ["the", "and", "is", "are", "you", "to", "of", "it", "that", "for", "with", "this", "be", "not", "have", "was", "what", "your", "will", "can", "el", "los", "las", "es", "y", "pero", "muy", "usted", "está", "gracias", "der", "die", "und", "ist", "le", "les", "est", "et", "vous"]
        const foreignCount = words.filter(w => foreign.includes(w)).length
        const portugueseCount = words.filter(w => portuguese.includes(w)).length
        return foreignCount >= 2 && foreignCount > portugueseCount
    }

    function translateText(text) {
        root.translation = { source: text, result: "", busy: true }
        translateProc.command = ["trans", "-b", "-no-autocorrect", ":pt-BR", text]
        translateProc.running = true
    }

    Process {
        id: translateProc
        stdout: StdioCollector {
            onStreamFinished: root.translation = { source: root.translation.source, result: text.trim(), busy: false }
        }
    }

    // "#FF9F0A", "#fa0" or "rgb(255, 159, 10)" -> the color plus HEX, RGB and HSL notations
    function parseColor(text) {
        const t = (text ?? "").trim()
        let r, g, b, m
        if ((m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(t))) {
            const hex = m[1].length === 3 ? m[1].split("").map(c => c + c).join("") : m[1]
            r = parseInt(hex.slice(0, 2), 16)
            g = parseInt(hex.slice(2, 4), 16)
            b = parseInt(hex.slice(4, 6), 16)
        } else if ((m = /^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})/i.exec(t))) {
            r = Number(m[1])
            g = Number(m[2])
            b = Number(m[3])
            if (r > 255 || g > 255 || b > 255) return null
        } else {
            return null
        }
        const color = Qt.rgba(r / 255, g / 255, b / 255, 1)
        const toHex = v => v.toString(16).padStart(2, "0")
        return {
            color: color,
            hex: `#${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase(),
            rgb: `rgb(${r}, ${g}, ${b})`,
            hsl: `hsl(${Math.round(Math.max(0, color.hslHue) * 360)}, ${Math.round(color.hslSaturation * 100)}%, ${Math.round(color.hslLightness * 100)}%)`
        }
    }

    function looksLikeAddress(text) {
        const t = (text ?? "").trim()
        if (t === "" || t.length > 160 || t.split("\n").length > 3 || /^https?:\/\//.test(t)) return false
        return (/(^|\s)(rua|r\.|avenida|av\.|travessa|tv\.|alameda|al\.|praça|pça|rodovia|estrada|largo|quadra|qd\.?)\s+\S+/i.test(t) && /\d/.test(t))
            || /\b\d{5}-\d{3}\b/.test(t)
            || /\b\d+\s+[A-Za-z]+\s+(street|st\.|avenue|ave\.|road|rd\.|boulevard|blvd)\b/i.test(t)
    }

    // Weak Wi-Fi while it matters (a call or a download): signal and link rate, at most every 10 minutes
    property double weakWifiAt: 0

    Timer {
        interval: 20000
        repeat: true
        running: (root.cfg.network ?? true) && (root.voiceCallActive || root.downloadActive) && !Network.ethernet && Network.wifiStatus === "connected"
        onTriggered: {
            if (Network.networkStrength >= 40 || Date.now() - root.weakWifiAt < 10 * 60 * 1000) return
            wifiRateProc.running = true
        }
    }

    Process {
        id: wifiRateProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,RATE", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = (text.split("\n").find(l => l.startsWith("*")) ?? "").split(":")
                const strength = parseInt(fields[1] ?? "") || Network.networkStrength
                if (strength >= 40) return
                root.weakWifiAt = Date.now()
                root.networkAlert.show({ kind: "weak", name: Network.networkName, strength: strength, rate: (fields[2] ?? "").replace("Mbit/s", "Mbps") }, 8000)
            }
        }
    }

    // Hyprland (Lua config): dispatchers are Lua expressions
    function hyprDispatch(expression) {
        Quickshell.execDetached(["hyprctl", "dispatch", expression])
    }

    function focusWindowPid(pid) {
        if (pid > 0) root.hyprDispatch(`hl.dsp.focus({ window = "pid:${pid}" })`)
    }

    function likeSpotifyTrack() {
        root.hyprDispatch('hl.dsp.send_shortcut({ mods = "ALT SHIFT", key = "B", window = "class:^([Ss]potify)$" })')
    }

    // A finished terminal command can be run again, in a new terminal at the same folder
    function rerunCommand(data) {
        if (!data?.command) return
        Quickshell.execDetached(["foot", "--working-directory", data.cwd || Quickshell.env("HOME"), "fish", "-C", data.command])
    }

    // System updates: a terminal with yay, re-checked when it closes
    function runSystemUpdate() {
        if (updateProc.running) return
        updateProc.running = true
    }

    Process {
        id: updateProc
        command: ["kitty", "--class", "ilha-update", "--title", "Atualizações do sistema", "fish", "-c", "yay -Syu; echo; read -P 'Enter para fechar '"]
        onExited: (exitCode, exitStatus) => Updates.refresh()
    }

    // Live activities (IPC and notify-send hints)
    property var activities: []
    readonly property var latestActivity: root.activities.length > 0 ? root.activities[root.activities.length - 1] : null

    // "attention": something is waiting for you (a question, a permission); stays until it changes
    signal activityNeedsAttention(var activity)

    // Getting an island out of the way. "Dismiss" is not "turn off": a song you already know about should leave
    // the front, but the next song is news again. So a dismissal is stored together with the state that was
    // dismissed (the track name, the file being downloaded); when that state changes the island comes back on
    // its own. "Silence" is the stronger one — the island stays away for the rest of the session.
    property var dismissedIslands: ({})
    property var silencedIslands: []

    function dismissIsland(id, stamp) {
        const dismissed = Object.assign({}, root.dismissedIslands)
        dismissed[id] = stamp ?? ""
        root.dismissedIslands = dismissed
    }

    function silenceIsland(id) {
        if (root.silencedIslands.includes(id)) return
        root.silencedIslands = [...root.silencedIslands, id]
    }

    function restoreIsland(id) {
        const dismissed = Object.assign({}, root.dismissedIslands)
        delete dismissed[id]
        root.dismissedIslands = dismissed
        root.silencedIslands = root.silencedIslands.filter(i => i !== id)
    }

    function isIslandHidden(id, stamp) {
        if (root.silencedIslands.includes(id)) return true
        const dismissed = root.dismissedIslands[id]
        return dismissed !== undefined && dismissed === (stamp ?? "")
    }

    // What already went by. An island lives for a few seconds and then the moment is gone: a notification you
    // looked away from, a command that failed, a download that landed. This keeps the last ones so they can be
    // found again instead of being lost the instant the island shrinks.
    property var eventLog: []

    function logEvent(kind, icon, title, subtitle, action) {
        const entry = {
            kind: kind,
            icon: icon || "bolt",
            title: title || "",
            subtitle: subtitle || "",
            time: Date.now(),
            action: action ?? null
        }
        if (entry.title === "") return
        const last = root.eventLog[0]
        // The same thing updating itself (a progress bar, a repeated notification) is one event, not twenty
        if (last && last.kind === kind && last.title === entry.title && entry.time - last.time < 4000) {
            root.eventLog = [entry, ...root.eventLog.slice(1)]
            return
        }
        root.eventLog = [entry, ...root.eventLog].slice(0, 30)
    }

    function clearEventLog() {
        root.eventLog = []
    }

    Connections {
        target: Notifications
        function onNotify(notif) {
            const parts = root.notificationParts(notif)
            root.logEvent("notification", "notifications", parts.title || parts.app,
                [parts.author, parts.body].filter(Boolean).join(": "),
                { type: "notification", id: notif.notificationId })
        }
    }

    onActivityFinished: activity => {
        root.logEvent(activity.state === "error" ? "error" : "activity", activity.icon, activity.title, activity.subtitle,
            activity.data ? { type: "command", data: activity.data } : null)
    }

    function upsertActivity(id, title, subtitle, icon, progress, state, data) {
        if (!(root.cfg.liveActivities ?? true)) return
        const now = Date.now()
        const previous = root.activities.find(a => a.id === id)
        const activity = {
            id: id,
            title: title || previous?.title || id,
            subtitle: subtitle ?? previous?.subtitle ?? "",
            icon: icon || previous?.icon || "bolt",
            progress: progress,
            state: state || "running",
            started: previous?.started ?? now,
            updated: now,
            // Extra details for the expanded view (terminal commands: cwd, command, terminal pid, output log)
            data: data ?? previous?.data ?? null
        }
        root.activities = [...root.activities.filter(a => a.id !== id), activity]
        if (["done", "error"].includes(activity.state) && previous?.state !== activity.state) root.activityFinished(activity)
        if (activity.state === "attention" && previous?.state !== "attention") root.activityNeedsAttention(activity)
    }

    function removeActivity(id) {
        root.activities = root.activities.filter(a => a.id !== id)
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.activities.length > 0
        onTriggered: {
            const now = Date.now()
            const kept = root.activities.filter(a => ["running", "attention"].includes(a.state) ? now - a.updated < 30 * 60 * 1000 : now - a.updated < 6000)
            if (kept.length !== root.activities.length) root.activities = kept
        }
    }

    // notify-send -h string:x-island-id:build -h int:value:40 [-h string:x-island-icon:build] [-h string:x-island-state:done] "Title" "Body"
    function handleNotification(notification) {
        const hints = notification.hints ?? {}
        const id = hints["x-island-id"]
        if (id === undefined || id === "") return false
        const value = hints["value"]
        const state = hints["x-island-state"] ?? "running"
        root.upsertActivity(String(id), notification.summary, notification.body, hints["x-island-icon"] ?? "",
            value !== undefined ? Math.max(0, Math.min(1, Number(value) / 100)) : (state === "done" ? 1 : -1), state)
        notification.tracked = false
        return true
    }

    // Browser web apps (WhatsApp Web in Chrome, etc.) send the site on the first body line and the browser as
    // the app name. Split that back into a readable app name, title and message.
    readonly property var siteNames: ({
        "web.whatsapp.com": "WhatsApp", "web.telegram.org": "Telegram", "discord.com": "Discord",
        "mail.google.com": "Gmail", "outlook.live.com": "Outlook", "outlook.office.com": "Outlook",
        "www.instagram.com": "Instagram", "teams.microsoft.com": "Teams", "app.slack.com": "Slack",
        "www.messenger.com": "Messenger", "calendar.google.com": "Google Calendar", "www.youtube.com": "YouTube"
    })

    // Brand marks for apps that reach us through a browser: their own mark, not the browser's icon
    readonly property var appBrands: ({
        "whatsapp": "whatsapp", "telegram": "telegram", "discord": "discord", "vesktop": "discord",
        "gmail": "gmail", "outlook": "microsoftoutlook", "instagram": "instagram", "messenger": "messenger",
        "teams": "microsoftteams", "slack": "slack", "youtube": "youtube", "spotify": "spotify",
        "google calendar": "googlecalendar"
    })

    function brandIcon(app) {
        const name = (app ?? "").toLowerCase()
        if (name === "") return ""
        const key = Object.keys(root.appBrands).find(k => name.includes(k))
        return key ? Quickshell.shellPath(`assets/island/apps/${root.appBrands[key]}.svg`) : ""
    }

    function notificationParts(notif) {
        const lines = (notif?.body ?? "").replace(/<[^>]*>/g, "").split(/\r?\n/)
        let origin = ""
        if (lines.length > 1 && /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(lines[0].trim())) origin = lines.shift().trim().toLowerCase()
        const app = origin !== "" ? (root.siteNames[origin] ?? origin.replace(/^www\./, "")) : root.shortName(notif?.appName ?? "")
        const title = (notif?.summary ?? "").replace(/\s+/g, " ").trim()
        let body = lines.join(" ").replace(/\s+/g, " ").trim()
        // Group chats send "Author: message"
        let author = ""
        const authorMatch = body.match(/^([^:]{1,32}):\s+(.+)$/)
        if (authorMatch && root.isMessagingApp(app) && authorMatch[1] !== title && !/^https?$/i.test(authorMatch[1])) {
            author = authorMatch[1]
            body = authorMatch[2]
        }
        const media = root.mediaKind(body, notif?.image ?? "")
        if (media) {
            body = body.replace(/^[\u{1F000}-\u{1FAFF}☀-➿️\s]+/u, "")
            if (body === "" || new RegExp(`^(${media.words})$`, "i").test(body)) body = media.label
        }
        return { origin: origin, app: app, title: title, author: author, body: body, media: media, brand: root.brandIcon(app) }
    }

    // Only these apps get to pull attention on their own (the island reveals itself); everything else waits its turn
    function isPriorityNotification(notif) {
        const app = root.notificationParts(notif).app.toLowerCase()
        return app !== "" && (root.cfg.priorityNotificationApps ?? ["whatsapp"]).some(a => app.includes(a.toLowerCase()))
    }

    function isMessagingApp(app) {
        return /whats|zap|telegram|discord|vesktop|signal|slack|teams|instagram|messenger/i.test(app ?? "")
    }

    // Photos, voice notes, stickers… arrive as an emoji plus a word; turn them into an icon and a clean label
    function mediaKind(body, image) {
        const kinds = [
            { test: /^(📷|🖼|📸)|^(foto|photo|imagem|image)$/i, icon: "photo_camera", label: Translation.tr("Photo"), words: "foto|photo|imagem|image" },
            { test: /^(🎤|🎙|🎵)|mensagem de voz|voice message|^(áudio|audio)\b/i, icon: "mic", label: Translation.tr("Voice message"), words: "áudio|audio|mensagem de voz|voice message" },
            { test: /^(🎥|📹)|^(vídeo|video)$/i, icon: "videocam", label: Translation.tr("Video"), words: "vídeo|video" },
            { test: /^(💟)|^(figurinha|sticker)$/i, icon: "add_reaction", label: Translation.tr("Sticker"), words: "figurinha|sticker" },
            { test: /^(📄|📎)|^(documento|document|arquivo|file)\b/i, icon: "description", label: Translation.tr("Document"), words: "documento|document|arquivo|file" },
            { test: /^(📍)|^(localização|location)\b/i, icon: "location_on", label: Translation.tr("Location"), words: "localização|location" },
            { test: /^GIF$/i, icon: "gif_box", label: "GIF", words: "gif" }
        ]
        const found = kinds.find(k => k.test.test(body))
        if (found) return found
        if (body === "" && image !== "") return kinds[0]
        return null
    }

    function conversationKey(notif) {
        const parts = root.notificationParts(notif)
        return `${parts.app}|${parts.title}`
    }

    function isMuted(notif) {
        if ((root.cfg.mutedConversations ?? []).includes(root.conversationKey(notif))) return true
        if (root.focusOn && (notif?.urgency ?? "").toLowerCase() !== "critical") return true
        return false
    }

    function toggleMute(notif) {
        const key = root.conversationKey(notif)
        const muted = Array.from(root.cfg.mutedConversations ?? [])
        Config.options.bar.dynamicIsland.mutedConversations = muted.includes(key) ? muted.filter(k => k !== key) : [...muted, key]
    }

    // How long a notification needs to be read: ~60 ms per character, between 3 and 8 seconds
    function readingTime(notif) {
        const length = `${notif?.summary ?? ""} ${(notif?.body ?? "").replace(/<[^>]*>/g, "")}`.length
        return Math.max(3000, Math.min(8000, 1500 + length * 60))
    }

    // How long a notification stays up. A personal chat message (one person, not a group) stays much longer:
    // it's the kind you actually want to read, and it used to be gone before you'd finished it.
    function displayTime(notif) {
        const reading = root.readingTime(notif)
        const parts = root.notificationParts(notif)
        if (root.isMessagingApp(parts.app) && parts.author === "")
            return Math.max(15000, Math.min(25000, reading * 2.5))
        return reading
    }

    // Brings up the app a notification came from: its default action, its desktop entry, or the web app's site
    function openNotificationSource(notif) {
        if (!notif) return
        if ((notif.actions ?? []).some(a => a.identifier === "default")) {
            Notifications.attemptInvokeAction(notif.notificationId, "default")
            return
        }
        const parts = root.notificationParts(notif)
        const desktopEntry = notif.notification?.desktopEntry ?? ""
        if (parts.origin !== "") Qt.openUrlExternally(`https://${parts.origin}`)
        else if (desktopEntry !== "") Quickshell.execDetached(["gtk-launch", desktopEntry])
        else if (/whats/i.test(notif.appName ?? "")) Qt.openUrlExternally("https://web.whatsapp.com")
        Notifications.timeoutNotification(notif.notificationId)
    }

    // Chat apps running as web apps (WhatsApp in Chrome, for one) don't offer the inline reply the notification
    // protocol has, so there is nothing to send the text to. The next best thing: copy it, bring the chat to the
    // front and paste it there, leaving the Enter to you — never send something you haven't seen in the chat.
    // WhatsApp Web: a real reply. The notification's own "default" action (what clicking it does) makes the web
    // app open *that* conversation; reply-send.sh then waits for the focused window to really be WhatsApp,
    // types the text without touching the clipboard and presses Enter. If the chat never comes up nothing is
    // typed anywhere — the text is left on the clipboard and the island says so.
    function replyToChat(notif, text) {
        if (!notif || text.trim() === "") return false
        const parts = root.notificationParts(notif)
        const canOpen = (notif.actions ?? []).some(a => a.identifier === "default")
        if (/whats/i.test(parts.app) && canOpen) {
            replySendProc.contact = parts.title || parts.app
            Notifications.attemptInvokeAction(notif.notificationId, "default")
            replySendProc.command = ["bash", Quickshell.shellPath("scripts/island/reply-send.sh"), text, "WhatsApp"]
            replySendProc.running = true
            return true
        }
        return root.pasteReplyInto(notif, text)
    }

    Process {
        id: replySendProc
        property string contact: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.upsertActivity("reply", Translation.tr("Reply sent"), replySendProc.contact, "send", 1, "done")
            else
                root.upsertActivity("reply", Translation.tr("Couldn't find the chat"), Translation.tr("The reply is on the clipboard"), "content_paste", -1, "error")
        }
    }

    // "Ask Gemini": the conversation goes to Gemini on the web. The prompt rides in the link's #fragment (never
    // sent to any server) and scripts/island/gemini-prompt.user.js, on gemini.google.com, puts it in the box and
    // sends it; it's copied to the clipboard as well, as a fallback.
    function askGemini(notifs) {
        const list = (notifs ?? []).filter(n => n)
        if (list.length === 0) return
        const parts = root.notificationParts(list[list.length - 1])
        const who = parts.title || parts.app
        const lines = list.map(n => {
            const p = root.notificationParts(n)
            const body = p.body || (p.media?.label ?? "")
            return `- ${p.author !== "" ? p.author + ": " : ""}${body}`
        })
        const prompt = Translation.tr("Conversation on %1 with %2 (oldest first):").arg(parts.app).arg(who)
            + "\n" + lines.join("\n") + "\n\n"
            + Translation.tr("Suggest 3 short, natural replies in Portuguese, in the tone of a personal chat. Only the replies, numbered.")
        // Also on the clipboard: if the userscript isn't there (or the page changed), it's one paste away
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", prompt])
        Qt.openUrlExternally(`https://gemini.google.com/app#ilha=${encodeURIComponent(prompt)}`)
    }

    function pasteReplyInto(notif, text) {
        if (text.trim() === "") return false
        const app = `${notif?.notification?.desktopEntry ?? ""} ${notif?.appName ?? ""}`.trim()
        pasteProc.command = ["bash", Quickshell.shellPath("scripts/island/reply-paste.sh"), text, app]
        pasteProc.running = true
        return true
    }

    Process {
        id: pasteProc
    }

    // Outputs that exist *and* outputs that could exist. A sound card only publishes the sinks of its active
    // profile: plug in a monitor, the card switches to hdmi-stereo, and the laptop speakers stop being a device
    // at all — which is why they vanished from the list instead of simply being unselected. So the island also
    // offers the card's other output profiles, and picking one switches the profile before switching the sink.
    property var audioProfiles: []

    Process {
        id: cardProfilesProc
        running: false
        command: ["sh", "-c", `
            LC_ALL=C pactl list cards | awk '
                /^Card #/ { card = "" }
                /^\tName: / { card = $2 }
                /Active Profile: / { active[card] = $3 }
                /^\t\t(output:|input:)/ {
                    line = $0
                    sub(/^[ \t]+/, "", line)
                    split(line, parts, ": ")
                    name = parts[1]
                    if (name !~ /^output:/) next
                    if (line !~ /available: yes/) next
                    desc = parts[2]
                    sub(/ \(sinks.*$/, "", desc)
                    print card "\t" name "\t" desc "\t" (active[card] == name ? "active" : "")
                }
            '
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = []
                for (const line of text.split("\n")) {
                    const parts = line.split("\t")
                    if (parts.length < 3 || parts[1] === "") continue
                    profiles.push({
                        card: parts[0],
                        name: parts[1],
                        description: parts[2],
                        active: (parts[3] ?? "") === "active",
                        hdmi: /hdmi/i.test(parts[1])
                    })
                }
                root.audioProfiles = profiles
            }
        }
    }

    function refreshAudioProfiles() {
        if (!cardProfilesProc.running) cardProfilesProc.running = true
    }

    function setAudioProfile(profile) {
        if (!profile) return
        Quickshell.execDetached(["pactl", "set-card-profile", profile.card, profile.name])
        root.audioOutput.show({
            name: profile.description, icon: profile.hdmi ? "tv" : "speaker",
            isBluetooth: false, switching: true
        }, 4200)
        profileSettle.restart()
    }

    Timer {
        id: profileSettle
        interval: 1200
        onTriggered: root.refreshAudioProfiles()
    }

    // Who is making noise, and how loud. One master volume is a blunt instrument when a video, a call and
    // music are all playing: these are the individual streams, straight from PipeWire.
    readonly property var audioStreams: {
        const items = []
        for (const node of Pipewire.nodes.values) {
            if (!node.isStream || !node.isSink || !node.audio) continue
            const props = node.properties ?? ({})
            const name = props["application.name"] || props["media.name"] || node.name || ""
            if (name === "") continue
            items.push({
                node: node,
                name: root.shortName(name),
                detail: props["media.name"] && props["media.name"] !== name ? props["media.name"] : "",
                icon: props["application.icon-name"] || "",
                muted: node.audio.muted,
                volume: node.audio.volume
            })
        }
        return items
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.isStream && node.isSink)
    }

    function setStreamVolume(node, value) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1.5, value))
    }

    function toggleStreamMute(node) {
        if (node?.audio) node.audio.muted = !node.audio.muted
    }

    // Image tools (OCR, Google Lens), reported as live activities
    function ocrImage(path) {
        if (!path) return
        root.upsertActivity("ocr", Translation.tr("Reading text from image"), path.split("/").pop(), "document_scanner", -1, "running")
        ocrProc.command = ["bash", "-c",
            `mkdir -p /tmp/quickshell/island && tesseract '${StringUtils.shellSingleQuoteEscape(path)}' - -l por+eng 2>/dev/null | sed '/^[[:space:]]*$/d' > /tmp/quickshell/island/ocr.txt; wl-copy < /tmp/quickshell/island/ocr.txt; wc -m < /tmp/quickshell/island/ocr.txt`]
        ocrProc.running = true
    }

    Process {
        id: ocrProc
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim()) || 0
                // The OCR activity already reports the copy; don't also flash "Copied"
                root.quietClipboardUntil = Date.now() + 4000
                if (count > 0) root.upsertActivity("ocr", "", `${count} ${Translation.tr("characters copied")}`, "", 1, "done")
                else root.upsertActivity("ocr", "", Translation.tr("No text found"), "", -1, "error")
            }
        }
    }

    function lensSearch(path) {
        if (!path) return
        root.upsertActivity("lens", "Google Lens", Translation.tr("Uploading image…"), "image_search", -1, "running")
        lensProc.command = ["bash", "-c",
            `url=$(curl -sF "files[]=@${StringUtils.shellSingleQuoteEscape(path)}" https://uguu.se/upload | jq -r '.files[0].url') && [ -n "$url" ] && [ "$url" != null ] && xdg-open "https://lens.google.com/uploadbyurl?url=$url"`]
        lensProc.running = true
    }

    Process {
        id: lensProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.upsertActivity("lens", "", Translation.tr("Opened in the browser"), "", 1, "done")
            else root.upsertActivity("lens", "", Translation.tr("Upload failed"), "", -1, "error")
        }
    }

    // Network: sustained downloads and connection changes
    property real downloadRate: 0
    property real uploadRate: 0
    property real burstBytes: 0
    property bool downloadActive: false
    property bool trafficBurst: false
    property bool fakeNet: false
    property real fastSeconds: 0
    property real prevRx: -1
    property real prevTx: -1
    property double prevNetTime: 0
    property Flash networkAlert: Flash { duration: 5500 }

    // What counts as a download. Traffic alone is a bad signal: a video playing or a game patching pulls more
    // megabytes than an installer, and the island ended up announcing every YouTube tab. In "files" mode the
    // island only speaks when a file is actually landing in the downloads folder (browsers write .crdownload/.part
    // while they fetch); the per-process traffic is still measured, it just no longer decides on its own.
    readonly property string downloadMode: root.cfg.downloadDetection ?? "files"
    readonly property var partialSuffixes: [".crdownload", ".part", ".partial", ".download", ".opdownload", ".!ut"]

    // Live downloads, as seen on disk: name, bytes so far, the browser's own total (so the progress is real,
    // not a guess) and speed. A partial file nobody has written to for a while is abandoned, not a download —
    // a forgotten 4 GB .crdownload would otherwise keep the island up forever.
    property var partialFiles: []
    readonly property bool fileDownloadActive: root.partialFiles.length > 0
    readonly property var downloadFile: root.partialFiles[0] ?? null
    readonly property string downloadFileName: root.downloadFile?.name ?? ""
    readonly property real downloadFileProgress: {
        const file = root.downloadFile
        if (!file || !file.total) return -1
        return Math.max(0, Math.min(1, file.bytes / file.total))
    }
    property var finishedDownload: null
    property Flash downloadDone: Flash { duration: 9000 }
    // IMDb rating of the episode/film that just started in the browser (services/WatchRating.qml)
    property Flash watchRating: Flash { duration: 6000 }

    // Passive: the kernel tells Qt when the folder changes (FolderListModel sits on inotify), and only a partial
    // file appearing starts the watcher, which follows the download and exits once nothing is arriving anymore.
    // Before, the watcher lived all day and listed the folder every 4 seconds.
    readonly property bool downloadWatchEnabled: (root.cfg.network ?? true) && root.downloadMode === "files" && !root.fakeNet

    FolderListModel {
        id: partialDownloads
        folder: Directories.downloads
        showDirs: false
        showHidden: true
        nameFilters: ["*.crdownload", "*.part", "*.partial", "*.download", "*.opdownload", "*.!ut"]
        onCountChanged: root.startDownloadWatch()
    }

    // Only a partial file that's actually being written counts: an abandoned .crdownload from weeks ago would
    // otherwise keep the watcher alive forever (and restart it every time it left)
    function startDownloadWatch() {
        if (!root.downloadWatchEnabled || downloadWatcher.running) return
        for (let i = 0; i < partialDownloads.count; i++) {
            const modified = partialDownloads.get(i, "fileModified")
            if (modified && Date.now() - modified.getTime() < 60000) {
                downloadWatcher.running = true
                return
            }
        }
    }
    onDownloadWatchEnabledChanged: {
        if (root.downloadWatchEnabled) root.startDownloadWatch()
        else downloadWatcher.running = false
    }

    Process {
        id: downloadWatcher
        command: ["python3", Quickshell.shellPath("scripts/island/download_watch.py"), "--until-idle",
            FileUtils.trimFileProtocol(Directories.downloads)]
        stdout: SplitParser {
            onRead: line => root.handleDownloadWatch(line)
        }
        // A new download may have started in the instant it was leaving
        onExited: Qt.callLater(root.startDownloadWatch)
    }

    function handleDownloadWatch(line) {
        let data
        try {
            data = JSON.parse(line)
        } catch (e) {
            return
        }
        root.partialFiles = (data.downloads ?? []).filter(file => !file.stale)
        for (const done of data.finished ?? []) {
            root.finishedDownload = done
            root.downloadDone.show(done)
            root.logEvent("download", "download_done", done.name, root.formatBytes(done.bytes, false),
                { type: "file", path: done.path })
            if (done.checksum !== "") root.verifyChecksum(done)
        }
    }

    // A .sha256 sitting next to the file is there to be checked
    function verifyChecksum(download) {
        root.upsertActivity("checksum", Translation.tr("Checking %1").arg(download.name), Translation.tr("Comparing SHA-256…"),
            "verified_user", -1, "running")
        checksumProc.download = download
        checksumProc.command = ["sh", "-c",
            'cd "$(dirname "$1")" && sha256sum -c --status "$2" && echo ok || echo fail',
            "sh", download.path, download.checksum]
        checksumProc.running = true
    }

    Process {
        id: checksumProc
        property var download: null
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.trim() === "ok"
                IslandEvents.upsertActivity("checksum",
                    ok ? Translation.tr("File checks out") : Translation.tr("Checksum does not match"),
                    checksumProc.download?.name ?? "", ok ? "verified" : "gpp_bad", 1, ok ? "done" : "error")
            }
        }
    }

    // Actions offered when a download lands
    function openDownload(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    function revealDownload(path) {
        Quickshell.execDetached(["dolphin", "--select", path])
    }

    function extractDownload(path) {
        root.upsertActivity("extract", Translation.tr("Extracting %1").arg(path.split("/").pop()), "", "folder_zip", -1, "running")
        extractProc.command = ["sh", "-c",
            'cd "$(dirname "$1")" && mkdir -p "${2}" && bsdtar -xf "$1" -C "${2}" && echo "$2"',
            "sh", path, path.replace(/\.(zip|tar|tgz|7z|rar|tar\.gz|tar\.xz|tar\.zst|tar\.bz2)$/i, "")]
        extractProc.running = true
    }

    Process {
        id: extractProc
        stdout: StdioCollector {
            onStreamFinished: {
                const folder = text.trim()
                IslandEvents.upsertActivity("extract",
                    folder !== "" ? Translation.tr("Extracted") : Translation.tr("Couldn't extract"),
                    folder.split("/").pop(), "folder_zip", 1, folder !== "" ? "done" : "error")
            }
        }
    }

    onFileDownloadActiveChanged: {
        if (root.downloadMode !== "files" || root.fakeNet) return
        if (root.fileDownloadActive) {
            root.burstBytes = 0
            root.downloadActive = true
        } else {
            root.downloadActive = false
        }
    }

    // Who is downloading: nethogs (TCP + UDP) per process while a burst lasts or its details are open
    property var downloadSources: []
    property string downloadSourcesError: ""
    property var downloadHistory: []
    property double downloadSince: 0
    property real downloadPeak: 0
    property var downloadTotals: ({})
    property var recentDownloads: []
    property bool downloadWatch: false
    readonly property var downloadTop: root.downloadSources.length > 0 ? root.downloadSources[0] : null
    readonly property string downloadLogPath: `${Quickshell.env("HOME")}/.local/state/quickshell/ilha-downloads.log`

    // The island and the log answer different questions. The island shows a file arriving; the log keeps every
    // sustained burst, island or not, so traffic that appears out of nowhere can still be traced afterwards.
    onTrafficBurstChanged: {
        if (root.trafficBurst) {
            root.downloadSince = Date.now()
            root.burstBytes = 0
            root.downloadHistory = []
            root.downloadPeak = 0
            root.downloadTotals = ({})
        } else if (root.downloadSince > 0) {
            root.finishDownloadBurst()
        }
    }

    onDownloadActiveChanged: {
        if (root.downloadActive && !root.trafficBurst) {
            root.downloadHistory = []
            root.downloadPeak = 0
        }
    }

    // "12 s", "3 min", "1 h 12 min" — what is left of a download
    function remainingTime(seconds) {
        const total = Math.max(0, Math.round(seconds))
        if (total < 60) return Translation.tr("%1 s").arg(total)
        if (total < 3600) return Translation.tr("%1 min").arg(Math.round(total / 60))
        return `${Math.floor(total / 3600)} h ${Math.round((total % 3600) / 60)} min`
    }

    function sourceLabel(source) {
        return source?.name === "unknown" ? Translation.tr("No process (system or container)") : root.shortName(source?.label ?? "")
    }

    function handleNetSources(line) {
        let data
        try {
            data = JSON.parse(line)
        } catch (e) {
            return
        }
        if (data.error) {
            root.downloadSourcesError = data.error
            return
        }
        root.downloadSourcesError = ""
        root.downloadSources = data.sources
        if (!root.downloadActive && !root.trafficBurst) return
        const totals = Object.assign({}, root.downloadTotals)
        for (const source of data.sources) {
            const key = root.sourceLabel(source)
            totals[key] = { icon: source.icon, bytes: (totals[key]?.bytes ?? 0) + source.rx * data.interval }
        }
        root.downloadTotals = totals
    }

    // Each burst goes to a log, so a download that shows up out of nowhere can be traced later
    function finishDownloadBurst() {
        const seconds = Math.round((Date.now() - root.downloadSince) / 1000)
        const top = Object.entries(root.downloadTotals).sort((a, b) => b[1].bytes - a[1].bytes).slice(0, 3)
        const entry = {
            time: root.downloadSince,
            seconds: seconds,
            bytes: root.burstBytes,
            peak: root.downloadPeak,
            sources: top.map(([label, total]) => ({ label: label, icon: total.icon, bytes: total.bytes }))
        }
        root.recentDownloads = [entry, ...root.recentDownloads].slice(0, 5)
        root.downloadSince = 0
        if (root.fakeNet) return
        const origin = entry.sources.map(s => `${s.label} ${root.formatBytes(s.bytes, false)}`).join(", ") || "origem desconhecida"
        const line = `${Qt.formatDateTime(new Date(entry.time), "yyyy-MM-dd hh:mm:ss")}  ${seconds}s  ${root.formatBytes(entry.bytes, false)}  pico ${root.formatBytes(entry.peak, true)}  ${origin}`
        logProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"', "sh", root.downloadLogPath, line]
        logProc.running = true
    }

    Process {
        id: netSourcesProc
        // Who is using the network: only for a real download or with the network view open. A plain traffic
        // burst (a film streaming) used to keep this running for the whole film.
        running: !root.fakeNet && (root.downloadActive || root.downloadWatch || (root.trafficBurst && root.downloadMode === "traffic"))
            && (root.cfg.network ?? true)
        command: ["python3", Quickshell.shellPath("scripts/island/net_sources.py")]
        stdout: SplitParser {
            onRead: line => root.handleNetSources(line)
        }
        onRunningChanged: if (!running && !root.fakeNet) root.downloadSources = []
    }

    Process {
        id: logProc
    }

    function formatBytes(bytes, perSecond) {
        const units = perSecond ? ["B/s", "KB/s", "MB/s", "GB/s"] : ["B", "KB", "MB", "GB"]
        let value = Math.max(0, bytes)
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return `${value.toFixed(unit > 0 && value < 100 ? 1 : 0)} ${units[unit]}`
    }

    function updateNet(contents) {
        if (root.fakeNet) return
        let rx = 0
        let tx = 0
        for (const line of contents.split("\n")) {
            const sep = line.indexOf(":")
            if (sep < 0) continue
            const name = line.slice(0, sep).trim()
            if (!name || name === "lo" || name.startsWith("veth") || name.startsWith("docker") || name.startsWith("zt")) continue
            const fields = line.slice(sep + 1).trim().split(/\s+/)
            if (fields.length < 9) continue
            rx += Number(fields[0]) || 0
            tx += Number(fields[8]) || 0
        }
        const now = Date.now()
        if (root.prevNetTime > 0 && rx >= root.prevRx && tx >= root.prevTx) {
            const seconds = (now - root.prevNetTime) / 1000
            root.downloadRate = (rx - root.prevRx) / seconds
            root.uploadRate = (tx - root.prevTx) / seconds
            // Counted in real seconds, since the sampling slows down to 5 s when the network is quiet
            if (root.downloadRate > 350 * 1024) root.fastSeconds = Math.min(root.fastSeconds + seconds, 10)
            else if (root.downloadRate < 80 * 1024) root.fastSeconds = Math.max(root.fastSeconds - 2 * seconds, 0)
            if (!root.trafficBurst && root.fastSeconds >= 4 && (root.cfg.network ?? true)) {
                root.trafficBurst = true
                if (root.downloadMode === "traffic") root.downloadActive = true
            }
            if (root.trafficBurst || root.downloadActive) {
                root.burstBytes += rx - root.prevRx
                root.downloadPeak = Math.max(root.downloadPeak, root.downloadRate)
                root.downloadHistory = [...root.downloadHistory, root.downloadRate].slice(-40)
            }
            if (root.trafficBurst && root.fastSeconds <= 0) {
                root.trafficBurst = false
                if (root.downloadMode === "traffic") root.downloadActive = false
            }
        }
        root.prevRx = rx
        root.prevTx = tx
        root.prevNetTime = now
    }

    FileView {
        id: netStats
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.updateNet(netStats.text())
    }

    // Network traffic has no event to listen to, so it's sampled — but slowly while nothing is happening, and
    // every second only while something is actually moving (a burst, a download, the network view open)
    Timer {
        interval: root.trafficBurst || root.downloadActive || root.downloadWatch || root.voiceCallActive ? 1000 : 5000
        repeat: true
        running: root.cfg.network ?? true
        onTriggered: netStats.reload()
    }

    property bool lastOnline: true
    property string lastNetworkName: ""

    function networkChanged() {
        const online = Network.ethernet || Network.wifiStatus === "connected"
        const name = Network.ethernet ? "Ethernet" : (Network.networkName ?? "")
        if (root.armed && (root.cfg.network ?? true)) {
            if (root.lastOnline && !online) root.networkAlert.show({ kind: "lost", name: root.lastNetworkName })
            else if (online && name !== "" && (!root.lastOnline || name !== root.lastNetworkName)) root.networkAlert.show({ kind: "connected", name: name })
        }
        root.lastOnline = online
        if (name !== "") root.lastNetworkName = name
    }

    Connections {
        target: Network
        function onWifiStatusChanged() { networkDebounce.restart() }
        function onEthernetChanged() { networkDebounce.restart() }
        function onNetworkNameChanged() { networkDebounce.restart() }
    }

    // Wi-Fi status flickers while roaming; judge it once it settles
    Timer {
        id: networkDebounce
        interval: 1500
        onTriggered: root.networkChanged()
    }

    // Real backlight level. The Brightness service only reads it at startup and then trusts its own writes,
    // so changes made elsewhere (brightnessctl fallback, power profiles) would show a stale value.
    property real realBrightness: -1
    property bool brightnessWatch: false

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m", "--class", "backlight"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(",")
                const current = parseFloat(parts[2])
                const max = parseFloat(parts[4])
                if (max > 0 && !isNaN(current)) root.realBrightness = current / max
            }
        }
    }

    Timer {
        interval: 300
        repeat: true
        triggeredOnStart: true
        running: GlobalStates.osdIndicatorType === "brightness" && (GlobalStates.osdVolumeOpen || root.brightnessWatch)
        onTriggered: if (!brightnessRead.running) brightnessRead.running = true
    }

    // Test helpers: fake the events that normally need real hardware or weather
    property bool fakeLoad: false
    property bool fakePrivacy: false
    property var pendingStep: null

    Timer {
        id: simStep
        onTriggered: {
            const step = root.pendingStep
            root.pendingStep = null
            if (step) step()
        }
    }

    Timer {
        id: fakeDownloadTick
        interval: 1000
        repeat: true
        onTriggered: {
            root.downloadRate = (7 + Math.random() * 5) * 1024 * 1024
            root.uploadRate = (20 + Math.random() * 30) * 1024
            root.burstBytes += root.downloadRate
            root.downloadPeak = Math.max(root.downloadPeak, root.downloadRate)
            root.downloadHistory = [...root.downloadHistory, root.downloadRate].slice(-40)
            root.handleNetSources(JSON.stringify({ interval: 1, sources: [
                { name: "chrome", label: "Google Chrome", icon: "google-chrome", pid: 1661, rx: root.downloadRate * 0.82, tx: 18000 },
                { name: "playitd", label: "playit.gg", icon: "network-server", pid: 601, rx: root.downloadRate * 0.15, tx: 3000 },
                { name: "unknown", label: "", icon: "network-transmit-receive", pid: 0, rx: root.downloadRate * 0.03, tx: 900 }
            ] }))
        }
    }

    function later(ms, step) {
        root.pendingStep = step
        simStep.interval = ms
        simStep.restart()
    }

    function simulate(name) {
        switch (name) {
            case "bluetooth":
                root.bluetooth.show({ address: "simulado", name: "Soundcore Liberty 4 NC", icon: "audio-headset", phase: "connecting" }, 20000)
                root.later(2600, () => root.bluetooth.show({ address: "simulado", name: "Soundcore Liberty 4 NC", icon: "audio-headset", phase: "connected" }))
                break
            case "audioOutput":
                root.audioOutput.show({ name: "Liberty 4 NC", icon: "earbuds", isBluetooth: true, switching: true }, 4200)
                break
            case "weather":
                root.weather.show({ group: 5, code: 501, temp: Weather.data?.temp || "21°C", description: "chuva moderada", city: Weather.data?.city ?? "" })
                break
            case "systemLoad":
                root.fakeLoad = true
                root.topProcess = "cargo"
                root.topProcessCpu = 384
                root.systemLoadActive = true
                root.later(15000, () => {
                    root.fakeLoad = false
                    root.systemLoadActive = false
                })
                break
            case "songRec":
                root.songRecResult.show({ title: "Blinding Lights", subtitle: "The Weeknd", url: "https://www.shazam.com" })
                break
            case "privacy":
                root.fakePrivacy = true
                root.later(15000, () => root.fakePrivacy = false)
                break
            case "timer":
                TimerService.addCountdownMinutes(1)
                if (!TimerService.countdownRunning) TimerService.toggleCountdown()
                break
            case "download":
                root.fakeNet = true
                root.downloadActive = true
                root.burstBytes = 0
                root.downloadRate = 9.6 * 1024 * 1024
                fakeDownloadTick.restart()
                root.later(14000, () => {
                    fakeDownloadTick.stop()
                    root.downloadActive = false
                    root.fakeNet = false
                    root.downloadSources = []
                })
                break
            case "netLost":
                root.networkAlert.show({ kind: "lost", name: root.lastNetworkName || "Casa 5G" })
                break
            case "zerotier":
                root.networkAlert.show({ kind: "zerotier", name: "ZeroTier" }, 15000)
                break
            case "wifiWeak":
                root.networkAlert.show({ kind: "weak", name: Network.networkName || "Casa 5G", strength: 22, rate: "13 Mbps" }, 8000)
                break
            case "headphonesLow":
                root.bluetooth.show({ address: "simulado", name: "Soundcore Liberty 4 NC", icon: "audio-headset", phase: "lowBattery", battery: 0.2 }, 7000)
                break
            case "netNew":
                root.networkAlert.show({ kind: "connected", name: "Café Wi-Fi" })
                break
            default:
                root.simulateRequested(name)
        }
    }

    IpcHandler {
        target: "island"

        function activity(id: string, title: string, subtitle: string, icon: string, progress: real): void {
            root.upsertActivity(id, title, subtitle, icon, progress, "running")
        }
        function indeterminate(id: string, title: string, subtitle: string, icon: string): void {
            root.upsertActivity(id, title, subtitle, icon, -1, "running")
        }
        function done(id: string, subtitle: string): void {
            root.upsertActivity(id, "", subtitle, "", 1, "done")
        }
        function fail(id: string, subtitle: string): void {
            root.upsertActivity(id, "", subtitle, "", -1, "error")
        }
        function command(id: string, title: string, subtitle: string, ok: bool, cwd: string, command: string, terminal: int, log: string): void {
            root.upsertActivity(id, title, subtitle, "terminal", 1, ok ? "done" : "error", { cwd: cwd, command: command, terminal: terminal, log: log })
        }
        function finish(id: string, title: string, subtitle: string, icon: string, ok: bool): void {
            root.upsertActivity(id, title, subtitle, icon, 1, ok ? "done" : "error")
        }
        function remove(id: string): void {
            root.removeActivity(id)
        }
        // Dev Activity (seção 26): a local dev server, framework-agnostic. state: "building" | "ready" | "error".
        // First support is a generic hook (scripts/island/dev-island.sh) that scans stdout for a localhost URL
        // and common error/ready keywords — not per-framework parsing. url travels in `data` for whatever reads
        // it next (there is no live action button on the card yet, same as the "command" activity).
        // "ready" stays LIVE (state: "running", static full ring instead of a spinner) because the server keeps
        // running for as long as you're using it — unlike "done", which the cleanup timer sweeps after 6s. The
        // wrapper script re-touches it periodically (well under the 30 min running-state grace window) so a
        // server left open all afternoon doesn't quietly vanish.
        function dev(id: string, title: string, subtitle: string, state: string, url: string): void {
            if (state === "error") { root.upsertActivity(id, title, subtitle, "web", -1, "error", { url: url, kind: "dev" }); return }
            root.upsertActivity(id, title, subtitle, "web", state === "building" ? -1 : 1, "running", { url: url, kind: "dev" })
        }
        function toggleExpanded(): void {
            root.expandRequested()
        }
        function setLevel(level: int): void {
            root.levelRequested(level)
        }
        function cycle(direction: int): void {
            root.cycleRequested(direction)
        }
        function cyclePinned(direction: int): void {
            root.pinnedCycleRequested(direction)
        }
        function togglePin(): void {
            root.pinToggleRequested()
        }
        function simulate(name: string): void {
            root.simulate(name)
        }
        function ocr(path: string): void {
            root.ocrImage(path)
        }
        // Compact split: "island split system" puts System beside the main pill; "island split" (empty) ends it
        function split(id: string): void {
            root.splitRequested(id)
        }
        function open(view: string): void {
            root.viewRequested(view)
        }
        function scroll(direction: int): void {
            root.scrollRequested(direction)
        }
        function home(): void {
            root.homeRequested()
        }
        function dismiss(): void {
            root.dismissRequested()
        }
        function silence(): void {
            root.silenceRequested()
        }
        function silenceId(id: string): void {
            root.silenceIsland(id)
        }
        function restore(id: string): void {
            root.restoreIsland(id)
        }
        function lens(path: string): void {
            root.lensSearch(path)
        }
    }
}
