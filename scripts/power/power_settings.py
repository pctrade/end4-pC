#!/usr/bin/env python3
"""System power policy for the settings page: lid, power key, hibernate delay, idle action,
critical-battery safety net and which USB input devices may wake the machine.

    power_settings.py get                 print the current state as JSON
    power_settings.py set <key> <value>   change one setting

The system itself is the source of truth: `get` reads what logind, systemd-sleep, UPower and
udev are actually using, and `set` writes drop-ins owned by this script (never the distro's
files). Root writes go through `sudo -n`, falling back to `pkexec`.
"""

import glob
import json
import os
import re
import subprocess
import sys

LOGIND = "/etc/systemd/logind.conf.d/90-shell-power.conf"
SLEEP = "/etc/systemd/sleep.conf.d/90-shell-power.conf"
UPOWER = "/etc/UPower/UPower.conf.d/90-shell-power.conf"
UDEV = "/etc/udev/rules.d/90-shell-wakeup.rules"
HYPRIDLE = os.path.expanduser("~/.config/hypr/hypridle.conf")
HEADER = "# Written by the shell's settings page (scripts/power/power_settings.py). Edit there.\n"

SLEEP_ACTIONS = ["suspend", "suspend-then-hibernate", "hibernate"]
LID_ACTIONS = SLEEP_ACTIONS + ["lock", "ignore", "poweroff"]
IDLE_COMMANDS = {
    "suspend": "systemctl suspend || loginctl suspend",
    "suspend-then-hibernate": "systemctl suspend-then-hibernate || systemctl suspend || loginctl suspend",
    "hibernate": "systemctl hibernate || systemctl suspend || loginctl suspend",
}
CRITICAL_ACTIONS = ["Hibernate", "PowerOff"]
# key -> (file, section, option, allowed values)
SYSTEM_KEYS = {
    "lid": (LOGIND, "Login", "HandleLidSwitch", LID_ACTIONS),
    "lidPlugged": (LOGIND, "Login", "HandleLidSwitchExternalPower", ["same"] + LID_ACTIONS),
    "powerKey": (LOGIND, "Login", "HandlePowerKey", LID_ACTIONS),
    "criticalAction": (UPOWER, "UPower", "CriticalPowerAction", CRITICAL_ACTIONS),
}


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


# ---- reading -------------------------------------------------------------


def logind(prop):
    out = run(["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1",
               "org.freedesktop.login1.Manager", prop])
    found = re.search(r'"(.*)"', out)
    return found.group(1) if found else ""


def last_option(text, option):
    """Last uncommented `option=value` in a merged config dump (later drop-ins win)."""
    found = re.findall(rf"^\s*{option}\s*=\s*(.*?)\s*$", text, re.M)
    return found[-1] if found else ""


def hibernate_delay_minutes():
    span = last_option(run(["systemd-analyze", "cat-config", "systemd/sleep.conf"]), "HibernateDelaySec")
    if not span:
        return 0
    micro = re.search(r"μs:\s*(\d+)", run(["systemd-analyze", "timespan", span]))
    return round(int(micro.group(1)) / 60e6) if micro else 0


def upower_option(option, default):
    text = ""
    for path in ["/etc/UPower/UPower.conf"] + sorted(glob.glob("/etc/UPower/UPower.conf.d/*.conf")):
        try:
            text += open(path).read() + "\n"
        except OSError:
            pass
    return last_option(text, option) or default


def idle_action():
    try:
        line = re.search(r"^\$suspend_cmd\s*=\s*(.*)$", open(HYPRIDLE).read(), re.M)
    except OSError:
        return ""
    command = line.group(1) if line else ""
    for action in ("suspend-then-hibernate", "hibernate", "suspend"):
        if f"systemctl {action}" in command.split("||")[0]:
            return action
    return ""


def read(path):
    try:
        return open(path).read().strip()
    except OSError:
        return ""


def wake_devices():
    """USB input devices (keyboards, mice, receivers) and whether they may wake the machine."""
    devices = []
    for dev in sorted(glob.glob("/sys/bus/usb/devices/*")):
        wakeup = read(f"{dev}/power/wakeup")
        vendor, product = read(f"{dev}/idVendor"), read(f"{dev}/idProduct")
        if not wakeup or not vendor:
            continue
        if not any(read(path) == "03" for path in glob.glob(f"{dev}/*/bInterfaceClass")):
            continue
        name = " ".join(part for part in (read(f"{dev}/manufacturer"), read(f"{dev}/product")) if part)
        devices.append({"id": f"{vendor}:{product}", "name": name or f"{vendor}:{product}",
                        "enabled": wakeup == "enabled"})
    return devices


def get():
    print(json.dumps({
        "lid": logind("HandleLidSwitch"),
        "lidPlugged": logind("HandleLidSwitchExternalPower") or "same",
        "powerKey": logind("HandlePowerKey"),
        "hibernateDelay": hibernate_delay_minutes(),
        "idle": idle_action(),
        "criticalPercent": round(float(upower_option("PercentageAction", "2"))),
        "criticalAction": upower_option("CriticalPowerAction", "Hibernate"),
        "canHibernate": "yes" in run(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                                      "org.freedesktop.login1.Manager", "CanHibernate"]),
        "wake": wake_devices(),
    }))


# ---- writing (root) ------------------------------------------------------


def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w") as f:
        f.write(content)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def set_option(path, section, option, value):
    """Set (or, with value None, drop) one option in a drop-in this script owns."""
    options = {}
    for line in read(path).splitlines():
        found = re.match(r"^([A-Za-z]+)=(.*)$", line.strip())
        if found:
            options[found.group(1)] = found.group(2)
    if value is None:
        options.pop(option, None)
    else:
        options[option] = value
    if not options:
        if os.path.exists(path):
            os.remove(path)
        return
    write_file(path, HEADER + f"[{section}]\n" + "".join(f"{k}={v}\n" for k, v in options.items()))


def set_wake(device_id, enabled):
    vendor, product = device_id.split(":")
    disabled = set(re.findall(r'idVendor\}=="([0-9a-f]{4})", ATTR\{idProduct\}=="([0-9a-f]{4})"', read(UDEV)))
    (disabled.discard if enabled else disabled.add)((vendor, product))
    if disabled:
        write_file(UDEV, HEADER + "".join(
            f'ACTION=="add|change", SUBSYSTEM=="usb", ATTR{{idVendor}}=="{v}", ATTR{{idProduct}}=="{p}", '
            'ATTR{power/wakeup}="disabled"\n' for v, p in sorted(disabled)))
    elif os.path.exists(UDEV):
        os.remove(UDEV)
    subprocess.run(["udevadm", "control", "--reload"], check=False)
    for dev in glob.glob("/sys/bus/usb/devices/*"):
        if read(f"{dev}/idVendor") == vendor and read(f"{dev}/idProduct") == product:
            with open(f"{dev}/power/wakeup", "w") as f:
                f.write("enabled" if enabled else "disabled")


def apply_root(key, value):
    if key in SYSTEM_KEYS:
        path, section, option, _ = SYSTEM_KEYS[key]
        set_option(path, section, option, None if value == "same" else value)
    elif key == "hibernateDelay":
        set_option(SLEEP, "Sleep", "HibernateDelaySec", f"{int(value)}min" if int(value) > 0 else None)
    elif key == "criticalPercent":
        set_option(UPOWER, "UPower", "PercentageAction", f"{int(value)}.0")
    elif key == "wake":
        device_id, _, state = value.partition("=")
        set_wake(device_id, state == "on")
    if key in ("lid", "lidPlugged", "powerKey"):
        subprocess.run(["systemctl", "reload", "systemd-logind"], check=False)
    elif key in ("criticalAction", "criticalPercent"):
        subprocess.run(["systemctl", "restart", "upower"], check=False)


# ---- writing (entry point) -----------------------------------------------


def validate(key, value):
    if key in SYSTEM_KEYS:
        return value in SYSTEM_KEYS[key][3]
    if key == "hibernateDelay":
        return value.isdigit() and int(value) <= 1440
    if key == "criticalPercent":
        # UPower ignores the whole policy unless Action < Critical (5%)
        return value.isdigit() and 1 <= int(value) <= 4
    if key == "wake":
        return re.fullmatch(r"[0-9a-f]{4}:[0-9a-f]{4}=(on|off)", value) is not None
    if key == "idle":
        return value in IDLE_COMMANDS
    return False


def set_idle(action):
    try:
        text = open(HYPRIDLE).read()
    except OSError:
        fail(f"{HYPRIDLE} not found")
    if not re.search(r"^\$suspend_cmd\s*=", text, re.M):
        fail(f"no $suspend_cmd line in {HYPRIDLE}")
    text = re.sub(r"^\$suspend_cmd\s*=.*$", lambda _: f"$suspend_cmd = {IDLE_COMMANDS[action]}", text, flags=re.M)
    with open(HYPRIDLE, "w") as f:
        f.write(text)
    subprocess.run(["bash", "-c", "pkill -x hypridle; sleep 0.3; setsid -f hypridle >/dev/null 2>&1"], check=False)


def set_(key, value):
    if not validate(key, value):
        fail(f"invalid value for {key}: {value}")
    if key == "idle":
        set_idle(value)
        return
    if os.geteuid() == 0:
        apply_root(key, value)
        return
    elevated = [sys.executable, os.path.abspath(__file__), "set", key, value]
    sudo_ok = subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0
    result = subprocess.run((["sudo", "-n"] if sudo_ok else ["pkexec"]) + elevated, capture_output=True, text=True)
    if result.returncode != 0:
        fail(result.stderr.strip() or "could not get administrator rights")


if __name__ == "__main__":
    if sys.argv[1:] == ["get"]:
        get()
    elif len(sys.argv) == 4 and sys.argv[1] == "set":
        set_(sys.argv[2], sys.argv[3])
    else:
        fail(__doc__)
