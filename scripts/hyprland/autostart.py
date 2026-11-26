#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

LOCK_FILE = "/tmp/qs-autostart.lock"
CONFIG_FILE = os.path.join(os.environ["HOME"], ".config", "illogical-impulse", "config.json")
force = "--force" in sys.argv


def dispatch(expression):
    subprocess.run(["hyprctl", "dispatch", expression], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def active_workspace():
    result = subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True)
    try:
        return json.loads(result.stdout)["id"]
    except (ValueError, KeyError):
        return None


if not force:
    if os.path.exists(LOCK_FILE):
        sys.exit(0)
    open(LOCK_FILE, "w").close()

with open(CONFIG_FILE) as handle:
    data = json.load(handle)

autostart = data.get("hyprland", {}).get("autostartApps", {})
if not autostart.get("enable", False):
    sys.exit(0)

original = active_workspace()

for app in autostart.get("apps", []):
    command = str(app.get("cmd", "")).strip()
    workspace = int(app.get("workspace", 1) or 1)
    delay = float(app.get("delay", 0) or 0)
    if not command:
        continue

    dispatch(f"hl.dsp.focus({{workspace = {workspace}}})")
    dispatch(f"hl.dsp.exec_cmd({lua_string(os.path.expanduser(command))})")
    time.sleep(max(delay, 0.4))

if original is not None:
    dispatch(f"hl.dsp.focus({{workspace = {original}}})")
