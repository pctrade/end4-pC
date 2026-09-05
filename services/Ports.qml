pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ports & Local Endpoints Service.
 * Periodically polls listening TCP ports and provides 1-click kill/open actions.
 */
Singleton {
    id: root

    property var portsList: []
    property int count: portsList.length
    property bool loading: getPortsProc.running

    function refresh() {
        if (getPortsProc.running) return;
        getPortsProc.running = true;
    }

    function killPort(port, pid, processName) {
        if (pid && pid.length > 0 && pid !== "0") {
            Quickshell.execDetached(["kill", "-9", pid])
            Quickshell.execDetached(["notify-send",
                "Port Killed",
                `Terminated ${processName || "process"} (PID ${pid}) on :${port}`,
                "-a", "Ports Inspector", "-u", "normal"
            ])
        } else {
            Quickshell.execDetached(["bash", "-c", `fuser -k -9 ${port}/tcp 2>/dev/null || true`])
            Quickshell.execDetached(["notify-send",
                "Port Killed",
                `Killed processes listening on :${port}`,
                "-a", "Ports Inspector", "-u", "normal"
            ])
        }
        refreshTimer.restart()
    }

    function killAllByName(name) {
        Quickshell.execDetached(["pkill", "-9", "-f", name])
        Quickshell.execDetached(["notify-send",
            "Processes Terminated",
            `Killed all processes matching '${name}'`,
            "-a", "Ports Inspector", "-u", "normal"
        ])
        refreshTimer.restart()
    }

    function openBrowser(port) {
        Quickshell.execDetached(["xdg-open", `http://localhost:${port}`])
    }

    function copyUrl(port) {
        Quickshell.execDetached(["bash", "-c", `printf "http://localhost:${port}" | wl-copy`])
        Quickshell.execDetached(["notify-send",
            "URL Copied",
            `http://localhost:${port} copied to clipboard`,
            "-a", "Ports Inspector", "-u", "low"
        ])
    }

    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: autoPollTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: getPortsProc
        command: ["bash", "-c", "python3 -c '
import subprocess, re, json

try:
    res = subprocess.run([\"ss\", \"-tlpn\"], capture_output=True, text=True, timeout=2)
    lines = res.stdout.strip().split(\"\\n\")[1:]
except Exception:
    lines = []

ports = []
seen = set()

system_ports = {53, 5355, 631}

for line in lines:
    parts = line.split()
    if len(parts) < 4:
        continue
    local_addr = parts[3]
    port_match = re.search(r\":(\\d+)$\", local_addr)
    if not port_match:
        continue
    port = int(port_match.group(1))
    
    if port in seen:
        continue
    seen.add(port)
    
    ip_raw = local_addr.rsplit(\":\", 1)[0]
    is_localhost = \"127.0.0.1\" in ip_raw or \"::1\" in ip_raw or \"127.0.0.5\" in ip_raw
    ip_label = \"localhost\" if is_localhost else (\"0.0.0.0\" if \"0.0.0.0\" in ip_raw or \"*\" in ip_raw or \"::\" == ip_raw else ip_raw)
    
    proc_name = \"unknown\"
    pid = \"\"
    if len(parts) >= 6:
        proc_part = \" \".join(parts[5:])
        m = re.search(r\"users:\\(\\(\\\"([^\\\"]+)\\\",pid=(\\d+)\", proc_part)
        if m:
            proc_name = m.group(1)
            pid = m.group(2)
    
    known_ports = {
        80: \"HTTP\", 443: \"HTTPS\", 3000: \"Node/React/Next\",
        5173: \"Vite Dev\", 8000: \"FastAPI/Django\", 8080: \"HTTP-Alt/App\",
        8001: \"Web Server\", 8002: \"Web Server\", 8050: \"Python App\",
        8090: \"Proxy/Service\", 5432: \"PostgreSQL\", 5433: \"PostgreSQL\",
        6379: \"Redis\", 6380: \"Redis\", 27017: \"MongoDB\",
        3306: \"MySQL\", 11434: \"Ollama\", 4200: \"Angular\",
        5000: \"Flask\", 8888: \"Jupyter\", 9200: \"Elasticsearch\"
    }
    if proc_name == \"unknown\" and port in known_ports:
        proc_name = known_ports[port]
        
    category = \"other\"
    icon = \"dns\"
    if port in [80, 443, 3000, 5173, 8000, 8080, 8001, 8002, 8050, 8090, 4200, 5000, 8888]:
        category = \"web\"
        icon = \"language\"
    elif port in [5432, 5433, 6379, 6380, 27017, 3306, 9200]:
        category = \"database\"
        icon = \"database\"
    elif port in [11434]:
        category = \"ai\"
        icon = \"neurology\"
    elif \"code\" in proc_name:
        category = \"ide\"
        icon = \"code\"
    elif \"spotify\" in proc_name:
        category = \"media\"
        icon = \"music_note\"
        
    is_system = port in system_ports
    
    ports.append({
        \"port\": port,
        \"ip\": ip_label,
        \"process\": proc_name,
        \"pid\": pid,
        \"category\": category,
        \"icon\": icon,
        \"isSystem\": is_system
    })

ports.sort(key=lambda x: (1 if x[\"isSystem\"] else 0, 0 if x[\"category\"] in [\"web\", \"database\", \"ai\"] else 1, x[\"port\"]))
print(json.dumps(ports))
'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim())
                    root.portsList = parsed || []
                } catch (e) {
                }
            }
        }
    }

    Component.onCompleted: {
        refresh()
    }
}
