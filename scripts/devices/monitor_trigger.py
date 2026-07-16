#!/usr/bin/env python3
import subprocess
import select
import sys

# We run subprocesses with "stdbuf -oL" to force line-buffering,
# ensuring select.select receives data immediately when events occur.

try:
    dbus_sys = subprocess.Popen(
        ["stdbuf", "-oL", "dbus-monitor", "--system", "type='signal',sender='org.bluez'"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
except Exception:
    dbus_sys = None

try:
    dbus_upower = subprocess.Popen(
        ["stdbuf", "-oL", "dbus-monitor", "--system", "type='signal',sender='org.freedesktop.UPower'"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
except Exception:
    dbus_upower = None

try:
    dbus_kde = subprocess.Popen(
        ["stdbuf", "-oL", "dbus-monitor", "--session", "type='signal',sender='org.kde.kdeconnect'"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
except Exception:
    dbus_kde = None

try:
    udev = subprocess.Popen(
        ["stdbuf", "-oL", "udevadm", "monitor", "--subsystem-match=usb"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
except Exception:
    udev = None

# Watch their stdout descriptors
inputs = []
for p in [dbus_sys, dbus_upower, dbus_kde, udev]:
    if p and p.stdout:
        inputs.append(p.stdout)

if not inputs:
    sys.exit(0)

# Block and read line-by-line, filtering out headers and startup lines
while True:
    readable, _, _ = select.select(inputs, [], [])
    for stream in readable:
        line = stream.readline().decode("utf-8", errors="ignore")
        if not line:
            if stream in inputs:
                inputs.remove(stream)
            continue
            
        line_strip = line.strip()
        
        # Robust filtering rules:
        # 1. udev events start with KERNEL[ or UDEV[
        is_udev = line_strip.startswith("KERNEL[") or line_strip.startswith("UDEV[")
        # 2. dbus signals contain sender=, but exclude bus startup name registration lines
        is_dbus = "sender=" in line_strip and "org.freedesktop.DBus" not in line_strip and "NameAcquired" not in line_strip and "NameLost" not in line_strip
        
        if not (is_udev or is_dbus):
            continue
            
        # Real event detected! Kill subprocesses and exit to trigger QML refresh.
        for p in [dbus_sys, dbus_upower, dbus_kde, udev]:
            if p:
                try:
                    p.terminate()
                except Exception:
                    pass
        sys.exit(0)
