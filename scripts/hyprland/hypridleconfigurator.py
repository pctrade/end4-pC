#!/usr/bin/env -S /bin/sh -c "source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate&&exec python -E \"$0\" \"$@\""
import argparse
import os
import re
import tempfile

LISTENERS = {
    "lock": {
        "match": ["loginctl lock-session"],
        "on-timeout": "loginctl lock-session",
    },
    "screenOff": {
        "match": ["dpms"],
        "on-timeout": "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'",
        "on-resume": "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'",
    },
    "suspend": {
        "match": ["$suspend_cmd"],
        "on-timeout": "$suspend_cmd",
    },
}


def write_atomic(path, content):
    dir_name = os.path.dirname(os.path.abspath(path))
    os.makedirs(dir_name, exist_ok=True)
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=dir_name, delete=False) as f:
            f.write(content)
            tmp_path = f.name
        if os.path.exists(path):
            os.chmod(tmp_path, os.stat(path).st_mode)
        os.replace(tmp_path, path)
    except Exception as e:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise e


def is_listener_open(line):
    return re.match(r"^\s*listener\s*\{", line) is not None


def split_blocks(lines):
    blocks = []
    current = None
    depth = 0

    for line in lines:
        if current is None:
            if is_listener_open(line):
                current = [line]
                depth = line.count("{") - line.count("}")
                continue
            blocks.append({"kind": "raw", "lines": [line]})
            continue

        current.append(line)
        depth += line.count("{") - line.count("}")
        if depth <= 0:
            blocks.append({"kind": "listener", "lines": current})
            current = None

    if current is not None:
        blocks.append({"kind": "raw", "lines": current})

    return blocks


def identify(block):
    text = "".join(block["lines"])
    for name, spec in LISTENERS.items():
        if all(needle in text for needle in spec["match"]):
            return name
    return None


def render_listener(name, timeout):
    spec = LISTENERS[name]
    lines = ["listener {\n", f"    timeout = {timeout}\n"]
    lines.append(f"    on-timeout = {spec['on-timeout']}\n")
    if "on-resume" in spec:
        lines.append(f"    on-resume = {spec['on-resume']}\n")
    lines.append("}\n")
    return "".join(lines)


def edit_idle(file_path, values):
    try:
        with open(file_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []

    blocks = split_blocks(lines)
    found = {}
    new_lines = []

    for block in blocks:
        if block["kind"] == "raw":
            new_lines.extend(block["lines"])
            continue

        name = identify(block)
        if name is None:
            new_lines.extend(block["lines"])
            continue

        found[name] = True
        timeout = values.get(name)
        if timeout is None or timeout <= 0:
            while new_lines and new_lines[-1].strip() == "":
                new_lines.pop()
            print(f"Removed listener: {name}")
        else:
            new_lines.append(render_listener(name, timeout))
            print(f"Updated listener: {name} -> {timeout}s")

    for name in LISTENERS:
        timeout = values.get(name)
        if found.get(name) or timeout is None or timeout <= 0:
            continue
        if new_lines and not new_lines[-1].endswith("\n"):
            new_lines[-1] += "\n"
        if new_lines and new_lines[-1].strip() != "":
            new_lines.append("\n")
        new_lines.append(render_listener(name, timeout))
        print(f"Added listener: {name} -> {timeout}s")

    write_atomic(file_path, "".join(new_lines))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--file", default="~/.config/hypr/hypridle.conf")
    p.add_argument("--lock", type=int)
    p.add_argument("--screen-off", type=int)
    p.add_argument("--suspend", type=int)
    args = p.parse_args()

    values = {
        "lock": args.lock,
        "screenOff": args.screen_off,
        "suspend": args.suspend,
    }
    edit_idle(os.path.expanduser(args.file), values)
