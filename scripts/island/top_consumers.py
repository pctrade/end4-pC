#!/usr/bin/env python3
"""Who is eating the CPU, the memory or the GPU right now — for the island's pressure alert.

Usage: top_consumers.py <cpu|memory|gpu> [count]

Runs once and exits (the island only calls it while an alert is up or its panel is open). CPU and GPU are
measured over one second from the kernel's own counters (/proc/<pid>/stat, and the DRM fdinfo engine times
for the GPU); memory is the resident set right now. Prints one JSON object:

  {"kind": "memory", "procs": [{"pid": 1234, "name": "chrome", "label": "Chrome · aba", "value": 4.1e9,
    "text": "4.1 GB", "share": 0.43, "abnormal": true, "protected": false}, ...]}

"abnormal" is deliberately simple: one process holding a disproportionate part of the resource, and not a job
that is heavy by nature (compilers, encoders). "protected" marks what must never get a kill button: the
compositor, the shell itself, audio, the session plumbing.
"""
import json
import os
import sys
import time

KIND = sys.argv[1] if len(sys.argv) > 1 else "cpu"
COUNT = int(sys.argv[2]) if len(sys.argv) > 2 else 12
UID = os.getuid()
TICK = os.sysconf("SC_CLK_TCK")
CORES = os.cpu_count() or 1

PROTECTED = {
    "Hyprland", "hyprland", "quickshell", "qs", "systemd", "pipewire", "pipewire-pulse", "wireplumber",
    "dbus-daemon", "dbus-broker", "Xwayland", "sddm", "sddm-helper", "kwalletd6", "xdg-desktop-portal",
    "xdg-desktop-portal-hyprland", "gnome-keyring-daemon", "polkit-kde-authentication-agent-1", "hypridle",
}
# Heavy on purpose: flagging these as "abnormal" would be noise
EXPECTED_HEAVY = {
    "cc1", "cc1plus", "rustc", "cargo", "gcc", "g++", "clang", "clang++", "ld", "ld.lld", "mold", "make",
    "ninja", "cmake", "go", "javac", "gradle", "java", "tsc", "node", "ffmpeg", "HandBrakeCLI", "x264", "x265",
    "blender", "makepkg", "pacman", "paru", "yay", "zstd", "xz", "7z", "tar", "rsync", "btrfs", "baloo_file",
}
PRETTY = {
    "chrome": "Chrome", "google-chrome": "Chrome", "chromium": "Chromium", "firefox": "Firefox",
    "zen-bin": "Zen", "zen": "Zen", "code": "VS Code", "electron": "Electron", "vesktop": "Vesktop",
    "spotify": "Spotify", "qs": "Quickshell", "quickshell": "Quickshell", "claude": "Claude Code", "discord": "Discord", "java": "Java", "python3": "Python", "node": "Node",
}


def pids():
    for entry in os.listdir("/proc"):
        if entry.isdigit():
            yield int(entry)


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode(errors="replace")
    except OSError:
        return None


def owner(pid):
    try:
        return os.stat(f"/proc/{pid}").st_uid
    except OSError:
        return -1


def name_of(pid):
    return (read(f"/proc/{pid}/comm") or "?").strip()


def app_of(pid, name):
    """What to look the icon up by: the executable's name, with Chrome's helpers folded into Chrome."""
    try:
        exe = os.readlink(f"/proc/{pid}/exe")
    except OSError:
        exe = ""
    base = os.path.basename(exe).removesuffix(" (deleted)") or name
    if base == "chrome" or "google-chrome" in exe or name == "chrome":
        return "google-chrome"
    # Versioned binaries (e.g. ~/.local/share/claude/versions/2.1.282) say nothing; the process name does
    return name if not any(c.isalpha() for c in base) else base


def label_of(pid, name):
    """A name people recognise: Chrome's renderers are tabs, its GPU process says so."""
    cmd = (read(f"/proc/{pid}/cmdline") or "").split("\0")
    base = os.path.basename(cmd[0]) if cmd and cmd[0] else name
    pretty = PRETTY.get(name) or PRETTY.get(base) or (base if len(base) <= 24 else name)
    joined = " ".join(cmd)
    if "--type=renderer" in joined:
        return f"{pretty} · aba" if "--extension-process" not in joined else f"{pretty} · extensão"
    if "--type=gpu-process" in joined:
        return f"{pretty} · GPU"
    if "--type=utility" in joined:
        return f"{pretty} · serviço"
    if name in ("python3", "python") and len(cmd) > 1:
        script = next((os.path.basename(a) for a in cmd[1:] if a and not a.startswith("-")), "")
        if script:
            return f"Python · {script}"
    return pretty


def cpu_ticks():
    ticks = {}
    for pid in pids():
        stat = read(f"/proc/{pid}/stat")
        if not stat:
            continue
        fields = stat[stat.rfind(")") + 2:].split()
        try:
            ticks[pid] = int(fields[11]) + int(fields[12])
        except (IndexError, ValueError):
            pass
    return ticks


def gpu_ns():
    """Engine time per process from the DRM fdinfo, counted once per DRM client (an fd can be duplicated)."""
    usage = {}
    for pid in pids():
        if owner(pid) != UID:
            continue
        try:
            fds = os.listdir(f"/proc/{pid}/fdinfo")
        except OSError:
            continue
        clients = {}
        for fd in fds:
            info = read(f"/proc/{pid}/fdinfo/{fd}")
            if not info or "drm-engine-" not in info:
                continue
            client, total = None, 0
            for line in info.splitlines():
                if line.startswith("drm-client-id:"):
                    client = line.split(":", 1)[1].strip()
                elif line.startswith("drm-engine-") and not line.startswith("drm-engine-capacity"):
                    try:
                        total += int(line.split(":", 1)[1].split()[0])
                    except (IndexError, ValueError):
                        pass
            clients[client or fd] = total
        if clients:
            usage[pid] = sum(clients.values())
    return usage


def human_bytes(value):
    for unit, size in (("GB", 1 << 30), ("MB", 1 << 20)):
        if value >= size:
            return f"{value / size:.1f} {unit}" if unit == "GB" else f"{value / size:.0f} {unit}"
    return f"{value / 1024:.0f} KB"


def measure():
    if KIND == "memory":
        total = 0
        meminfo = read("/proc/meminfo") or ""
        for line in meminfo.splitlines():
            if line.startswith("MemTotal:"):
                total = int(line.split()[1]) * 1024
        values = {}
        for pid in pids():
            status = read(f"/proc/{pid}/status") or ""
            for line in status.splitlines():
                if line.startswith("VmRSS:"):
                    values[pid] = int(line.split()[1]) * 1024
                    break
        return values, total
    if KIND == "gpu":
        first = gpu_ns()
        time.sleep(1)
        second = gpu_ns()
        return {pid: (second[pid] - first.get(pid, second[pid])) / 1e9 for pid in second}, 1.0
    first = cpu_ticks()
    time.sleep(1)
    second = cpu_ticks()
    return {pid: (second[pid] - first[pid]) / TICK for pid in second if pid in first}, float(CORES)


def main():
    values, capacity = measure()
    used = sum(v for v in values.values() if v > 0) or 1
    ranked = sorted(((v, pid) for pid, v in values.items() if v > 0), reverse=True)[:COUNT]
    procs = []
    for value, pid in ranked:
        name = name_of(pid)
        share = value / used
        if KIND == "memory":
            text = human_bytes(value)
            abnormal = value >= capacity * 0.25 or (share >= 0.4 and value >= 1.5 * (1 << 30))
        elif KIND == "gpu":
            text = f"{min(100, value * 100):.0f}%"
            abnormal = value >= 0.5 and share >= 0.5
        else:
            text = f"{value * 100:.0f}%"
            abnormal = value >= 0.9 and share >= 0.5
        mine = owner(pid) == UID
        procs.append({
            "pid": pid,
            "name": name,
            "label": label_of(pid, name),
            "app": app_of(pid, name),
            "value": value,
            "text": text,
            "share": round(share, 3),
            "abnormal": bool(abnormal and name not in EXPECTED_HEAVY and name not in PROTECTED),
            "protected": (not mine) or name in PROTECTED or pid == os.getppid(),
        })
    print(json.dumps({"kind": KIND, "procs": procs}, ensure_ascii=False))


if __name__ == "__main__":
    main()
