#!/usr/bin/env python3
import json, subprocess, time, os

with open(f"{os.environ['HOME']}/.config/illogical-impulse/config.json") as f:
    data = json.load(f)

autostart = data.get('hyprland', {}).get('autostartApps', {})

if not autostart.get('enable', False):
    exit(0)

for app in autostart.get('apps', []):
    cmd = app.get('cmd', '').strip()
    workspace = app.get('workspace', 1)
    delay = app.get('delay', 0)
    if not cmd:
        continue
    subprocess.run(['hyprctl', 'dispatch', 'workspace', str(workspace)])
    subprocess.Popen(
        [os.path.expanduser(c) for c in cmd.split()],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )
    time.sleep(delay)
