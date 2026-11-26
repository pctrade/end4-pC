pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // just fb fixme later
    readonly property var fallbackTimezones: [
        // O
        "Pacific/Auckland", "Pacific/Fiji", "Pacific/Guam", "Pacific/Honolulu", 
        "Pacific/Pago_Pago", "Pacific/Apia", "Pacific/Tahiti",
        "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane", 
        "Australia/Adelaide", "Australia/Darwin", "Australia/Perth",

        // A
        "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong", 
        "Asia/Taipei", "Asia/Singapore", "Asia/Kuala_Lumpur", "Asia/Manila", 
        "Asia/Makassar", "Asia/Jakarta", "Asia/Bangkok", "Asia/Ho_Chi_Minh", 
        "Asia/Yangon", "Asia/Dhaka", "Asia/Kathmandu", "Asia/Kolkata", 
        "Asia/Karachi", "Asia/Tashkent", "Asia/Kabul", "Asia/Dubai", 
        "Asia/Muscat", "Asia/Tehran", "Asia/Baghdad", "Asia/Riyadh", 
        "Asia/Kuwait", "Asia/Qatar", "Asia/Jerusalem", "Asia/Beirut", 
        "Asia/Damascus", "Asia/Nicosia",

        // UE
        "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Bucharest", 
        "Europe/Helsinki", "Europe/Kiev", "Europe/Minsk", "Europe/Warsaw", 
        "Europe/Vienna", "Europe/Prague", "Europe/Budapest", "Europe/Berlin", 
        "Europe/Paris", "Europe/Brussels", "Europe/Amsterdam", "Europe/Zurich", 
        "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Dublin", 
        "Europe/Lisbon", "Atlantic/Reykjavik", "Atlantic/Azores",

        // A
        "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Addis_Ababa", 
        "Africa/Khartoum", "Africa/Lagos", "Africa/Kinshasa", "Africa/Algiers", 
        "Africa/Casablanca", "Africa/Tunis", "Africa/Accra", "Africa/Dakar",

        // SA
        "America/Sao_Paulo", "America/Rio_Branco", "America/Buenos_Aires", 
        "America/Cordoba", "America/Santiago", "America/Asuncion", "America/Montevideo", 
        "America/La_Paz", "America/Cuiaba", "America/Lima", "America/Bogota", 
        "America/Guayaquil", "America/Caracas",

        // CA
        "America/Panama", "America/Costa_Rica", "America/El_Salvador", 
        "America/Guatemala", "America/Managua", "America/Tegucigalpa", 
        "America/Havana", "America/Santo_Domingo", "America/Puerto_Rico", 
        "America/Jamaica",

        // NA
        "America/Mexico_City", "America/Monterrey", "America/Tijuana", 
        "America/New_York", "America/Detroit", "America/Chicago", 
        "America/Denver", "America/Phoenix", "America/Los_Angeles", 
        "America/Anchorage", "America/Vancouver", "America/Edmonton", 
        "America/Winnipeg", "America/Toronto", "America/Halifax", "America/St_Johns"
    ]

    property var systemTimezones: []

    readonly property var timezoneList: {
        if (root.systemTimezones.length > 0) return root.systemTimezones
        if (typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function") {
            try {
                return Intl.supportedValuesOf("timeZone")
            } catch (e) {
                return root.fallbackTimezones
            }
        }
        return root.fallbackTimezones
    }

    Process {
        id: timezoneListProc
        running: true
        command: ["bash", "-c", "timedatectl list-timezones 2>/dev/null || (cd /usr/share/zoneinfo && find Africa America Antarctica Arctic Asia Atlantic Australia Europe Indian Pacific -type f | sort)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const zones = text.trim().split("\n").map(line => line.trim()).filter(line => line.includes("/"))
                if (zones.length > 0) root.systemTimezones = zones
            }
        }
    }

    function labelFor(tz) {
        const parts = tz.split("/")
        const city = (parts[parts.length - 1] ?? tz).replace(/_/g, " ")
        const region = parts[0] ?? ""
        return region ? `${city} (${region})` : city
    }

    readonly property var comboModel: root.timezoneList.map(tz => ({ label: root.labelFor(tz), tz: tz, icon: "" }))

    property list<string> timezones: Config.options?.background?.widgets?.worldClock?.timezones ?? [
        "Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"
    ]

    function setTimezone(index, tz) {
        let updated = root.timezones.slice()
        updated[index] = tz
        root.timezones = updated
        Config.options.background.widgets.worldClock.timezones = updated
    }

    readonly property bool active: Config.options?.background?.widgets?.worldClock?.enable ?? false

    onTimezonesChanged: root.refreshOffsets()
    onActiveChanged: root.refreshOffsets()
    Component.onCompleted: root.refreshOffsets()

    readonly property string ampmToken: {
        const fmt = Config.options?.time.format ?? "HH:mm"
        if (fmt.includes("AP")) return "AP"
        if (fmt.includes("ap")) return "ap"
        return ""
    }
    readonly property bool use24h: root.ampmToken === ""

    property var now: new Date()
    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    property var offsetCache: ({})

    property bool refreshQueued: false

    function refreshOffsets() {
        if (!root.active) return
        refreshDebounce.restart()
    }

    Timer {
        id: refreshDebounce
        interval: 150
        onTriggered: {
            if (offsetProc.running) {
                root.refreshQueued = true
                return
            }
            offsetProc.command = root.offsetCommand()
            offsetProc.running = true
        }
    }

    readonly property var zoneAliases: ({
        "America/Miami": "America/New_York",
        "America/Houston": "America/Chicago"
    })

    function effectiveZone(tz) {
        return root.zoneAliases[tz] ?? tz
    }

    function offsetCommand() {
        const pairs = root.timezones.map(tz => "'" + tz.replace(/[':]/g, "") + ":" + root.effectiveZone(tz).replace(/[':]/g, "") + "'").join(" ")
        return ["bash", "-c", `for pair in ${pairs}; do tz="\${pair%%:*}"; eff="\${pair##*:}"; if [ -f "/usr/share/zoneinfo/$eff" ]; then printf '%s %s\\n' "$tz" "$(TZ="$eff" date +%z)"; else printf '%s invalid\\n' "$tz"; fi; done`]
    }

    Timer {
        interval: 10 * 60 * 1000
        running: root.active
        repeat: true
        onTriggered: root.refreshOffsets()
    }

    Process {
        id: offsetProc
        onExited: {
            if (root.refreshQueued) {
                root.refreshQueued = false
                refreshDebounce.restart()
            }
        }
        stdout: StdioCollector {
            id: offsetCollector
            onStreamFinished: {
                const cache = Object.assign({}, root.offsetCache)
                for (const line of offsetCollector.text.trim().split("\n")) {
                    const [tz, value] = line.trim().split(" ")
                    const m = (value ?? "").match(/^([+-])(\d{2})(\d{2})$/)
                    if (!tz) continue
                    cache[tz] = m ? (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3])) : null
                }
                root.offsetCache = cache
            }
        }
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function cityDate(index) {
        const offsetMin = root.offsetCache[root.timezones[index]]
        if (offsetMin === undefined || offsetMin === null) return null
        return new Date(root.now.getTime() + offsetMin * 60000)
    }

    function timeStringFor(index) {
        const cd = root.cityDate(index)
        if (!cd) return "--:--"
        let h = cd.getUTCHours()
        let m = cd.getUTCMinutes()
        if (root.use24h) {
            return pad(h) + ":" + pad(m)
        }
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        const base = pad(h12) + ":" + pad(m)
        if (root.ampmToken === "AP") return base + " " + (h >= 12 ? "PM" : "AM")
        return base + " " + (h >= 12 ? "pm" : "am")
    }

    function offsetLabelFor(index) {
        const offsetMin = root.offsetCache[root.timezones[index]]
        if (offsetMin === undefined || offsetMin === null) return "UTC?"
        const sign = offsetMin >= 0 ? "+" : "-"
        const abs = Math.abs(offsetMin)
        const h = Math.floor(abs / 60)
        const m = abs % 60
        return "UTC" + sign + h + (m > 0 ? ":" + pad(m) : "")
    }

    function isDaytimeFor(index) {
        const cd = root.cityDate(index)
        if (!cd) return true
        const h = cd.getUTCHours()
        return h >= 6 && h < 18
    }

    readonly property var entries: root.timezones.map((tz, i) => ({
        tz: tz,
        name: root.labelFor(tz).split(" (")[0],
        time: root.timeStringFor(i),
        offset: root.offsetLabelFor(i),
        isDay: root.isDaytimeFor(i)
    }))
}
