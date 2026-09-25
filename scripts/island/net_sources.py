#!/usr/bin/env python3
"""Per-process network usage for the dynamic island.

Runs nethogs in trace mode (TCP + UDP, so QUIC traffic from browsers counts too) and prints one JSON
line per refresh: {"interval": 2, "sources": [{name, label, icon, pid, rx, tx}]}, rates in bytes/s.
"""
import ctypes
import json
import os
import re
import shutil
import signal
import subprocess
import sys

INTERVAL = 2

# process name -> (friendly label, icon name)
KNOWN = {
    "chrome": ("Google Chrome", "google-chrome"),
    "chromium": ("Chromium", "chromium"),
    "brave": ("Brave", "brave-desktop"),
    "firefox": ("Firefox", "firefox"),
    "zen-bin": ("Zen Browser", "zen-browser"),
    "zen": ("Zen Browser", "zen-browser"),
    "vesktop": ("Vesktop", "vesktop"),
    "discord": ("Discord", "discord"),
    "spotify": ("Spotify", "spotify"),
    "steam": ("Steam", "steam"),
    "steamwebhelper": ("Steam", "steam"),
    "telegram-desktop": ("Telegram", "telegram"),
    "code": ("VS Code", "visual-studio-code"),
    "pacman": ("pacman", "system-software-update"),
    "paru": ("paru", "system-software-update"),
    "yay": ("yay", "system-software-update"),
    "flatpak": ("Flatpak", "flatpak"),
    "packagekitd": ("PackageKit", "system-software-update"),
    "dockerd": ("Docker", "docker"),
    "containerd": ("Docker", "docker"),
    "playitd": ("playit.gg", "network-server"),
    "qbittorrent": ("qBittorrent", "qbittorrent"),
    "transmission-gtk": ("Transmission", "transmission"),
    "syncthing": ("Syncthing", "syncthing"),
    "dropbox": ("Dropbox", "dropbox"),
    "ollama": ("Ollama", "utilities-terminal"),
    "curl": ("curl", "utilities-terminal"),
    "wget": ("wget", "utilities-terminal"),
    "git-remote-https": ("git", "git"),
    "uv": ("uv", "utilities-terminal"),
    "NetworkManager": ("NetworkManager", "network-wired"),
}

IDENT = re.compile(r"^(.*)/(\d+)/(\d+)$", re.S)


def die_with_parent():
    try:
        ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except OSError:
        pass


def emit(payload):
    print(json.dumps(payload), flush=True)


def describe(ident):
    match = IDENT.match(ident)
    path, pid = (match.group(1), int(match.group(2))) if match else (ident, 0)
    if pid == 0:
        return "unknown", "", "network-transmit-receive", 0
    try:
        with open(f"/proc/{pid}/comm") as f:
            name = f.read().strip()
    except OSError:
        name = os.path.basename(path.split(" ")[0])
    label, icon = KNOWN.get(name, (name, name.lower()))
    return name, label, icon, pid


def main():
    die_with_parent()
    if shutil.which("nethogs") is None:
        emit({"error": "missing"})
        return
    proc = subprocess.Popen(
        ["sudo", "-n", "nethogs", "-t", "-C", "-d", str(INTERVAL)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )

    def stop(*_):
        proc.terminate()
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    batch = {}
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line.startswith("sudo:"):
            emit({"error": "sudo"})
            break
        if line.startswith("Refreshing:"):
            sources = sorted(batch.values(), key=lambda s: s["rx"], reverse=True)
            emit({"interval": INTERVAL, "sources": [s for s in sources if s["rx"] >= 512][:6]})
            batch = {}
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            continue
        try:
            sent, received = float(fields[1]) * 1024, float(fields[2]) * 1024
        except ValueError:
            continue
        name, label, icon, pid = describe(fields[0])
        key = label or name
        source = batch.setdefault(key, {"name": name, "label": label, "icon": icon, "pid": pid, "rx": 0.0, "tx": 0.0})
        # The process doing most of the traffic gives the row its pid
        if received > source.get("topRx", -1):
            source["pid"], source["topRx"] = pid, received
        source["rx"] += received
        source["tx"] += sent
    proc.wait()
    if proc.returncode not in (0, None, -signal.SIGTERM):
        emit({"error": "failed"})


if __name__ == "__main__":
    main()
