#!/usr/bin/env -S /bin/sh -c "source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate&&exec python -E \"$0\" \"$@\""
import argparse
import os
import re
import tempfile

BOOL_KEYS = {
    "decoration:blur:enabled",
    "decoration:shadow:enabled",
    "decoration:dim_inactive",
    "animations:enabled",
    "general:resize_on_border",
    "general:allow_tearing",
    "input:numlock_by_default",
    "input:force_no_accel",
    "input:left_handed",
    "input:touchpad:natural_scroll",
    "input:touchpad:disable_while_typing",
    "input:touchpad:clickfinger_behavior",
    "input:touchpad:tap-to-click",
    "input:touchpad:tap-and-drag",
    "input:touchpad:middle_button_emulation",
    "misc:focus_on_activate",
    "misc:disable_hyprland_logo",
    "misc:disable_splash_rendering",
    "misc:mouse_move_enables_dpms",
    "misc:key_press_enables_dpms",
    "misc:animate_manual_resizes",
    "misc:enable_swallow",
    "misc:middle_click_paste",
    "misc:close_special_on_empty",
    "cursor:hide_on_key_press",
    "dwindle:preserve_split",
    "dwindle:smart_split",
    "xwayland:force_zero_scaling",
    "binds:workspace_back_and_forth",
    "binds:allow_workspace_cycles",
    "group:auto_group",
}

ANIM_PRESETS = {
    "fast": """\
hl.curve("pc_wobble", { type = "bezier", points = { {0.15, 1.15}, {0.35, 1.0}  } })
hl.curve("pc_decel",  { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.05} } })
hl.curve("pc_accel",  { type = "bezier", points = { {0.3,  0},    {0.8,  0.15} } })
hl.animation({ leaf = "windowsIn",           enabled = true, speed = 5, bezier = "pc_wobble", style = "slide"     })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 5, bezier = "pc_accel",  style = "slide"     })
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 5, bezier = "pc_decel",  style = "slide"     })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 4, bezier = "pc_decel"                       })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 4, bezier = "pc_accel"                       })
hl.animation({ leaf = "layersIn",            enabled = true, speed = 4, bezier = "pc_decel",  style = "slide"     })
hl.animation({ leaf = "layersOut",           enabled = true, speed = 4, bezier = "pc_accel",  style = "slide"     })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 6, bezier = "pc_decel",  style = "slide"     })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2, bezier = "pc_wobble", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "pc_accel",  style = "slidevert" })
""",
    "normal": """\
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7},  {0.1,  1}    } })
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3,  0},    {0.8,  0.15} } })
hl.curve("menu_decel",      { type = "bezier", points = { {0.1,  1},    {0,    1}    } })
hl.curve("menu_accel",      { type = "bezier", points = { {0.52, 0.03}, {0.72, 0.08} } })
hl.curve("stall",           { type = "bezier", points = { {1,    -0.1}, {0.7,  0.85} } })
hl.animation({ leaf = "windowsIn",           enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 2,   bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "slide"     })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 3,   bezier = "emphasizedDecel"  })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 2,   bezier = "emphasizedDecel"  })
hl.animation({ leaf = "border",              enabled = true, speed = 10,  bezier = "emphasizedDecel"  })
hl.animation({ leaf = "layersIn",            enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut",           enabled = true, speed = 2.4, bezier = "menu_accel",      style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn",        enabled = true, speed = 0.5, bezier = "menu_decel"       })
hl.animation({ leaf = "fadeLayersOut",       enabled = true, speed = 2.7, bezier = "stall"            })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 7,   bezier = "menu_decel",      style = "slide"     })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })
""",
    "niri": """\
hl.curve("niri_wobble", { type = "bezier", points = { {0.15, 1.15}, {0.35, 1.0}  } })
hl.curve("niri_decel",  { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.05} } })
hl.curve("niri_accel",  { type = "bezier", points = { {0.3,  0},    {0.8,  0.15} } })
hl.animation({ leaf = "windowsIn",           enabled = true, speed = 5, bezier = "niri_wobble", style = "slide"     })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 5, bezier = "niri_accel",  style = "slide"     })
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 5, bezier = "niri_decel",  style = "slide"     })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 4, bezier = "niri_decel"                       })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 4, bezier = "niri_accel"                       })
hl.animation({ leaf = "layersIn",            enabled = true, speed = 4, bezier = "niri_decel",  style = "slide"     })
hl.animation({ leaf = "layersOut",           enabled = true, speed = 4, bezier = "niri_accel",  style = "slide"     })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 6, bezier = "niri_decel",  style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 4, bezier = "niri_wobble", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "niri_accel",  style = "slidevert" })
""",
}


def to_lua_value(key, value):
    if key in BOOL_KEYS:
        return "false" if value == "0" else "true"
    try:
        return str(int(value))
    except ValueError:
        pass
    try:
        return str(float(value))
    except ValueError:
        pass
    return f'"{value}"'


def to_lua_line(key, value):
    parts = key.replace("-", "_").replace(":", ".").split(".")
    val = to_lua_value(key, value)
    inner = f"{{ {parts[-1]} = {val} }}"
    for part in reversed(parts[:-1]):
        inner = f"{{ {part} = {inner} }}"
    return f"hl.config({inner})\n"


def make_marker(key):
    parts = key.replace("-", "_").replace(":", ".").split(".")

    fragment = " = { ".join(parts[:-1])
    if fragment:
        fragment += " = { " + parts[-1] + " ="
    else:
        fragment = parts[-1] + " ="
    return fragment


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


def edit_lua(file_path, set_pairs, reset_keys):
    try:
        with open(file_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []

    set_dict   = dict(set_pairs)
    reset_set  = set(reset_keys)
    all_keys   = list(set_dict) + list(reset_set)
    markers    = {k: make_marker(k) for k in all_keys}

    new_lines  = []
    found_keys = set()

    for line in lines:
        matched = None
        for k in all_keys:
            if markers[k] in line:
                matched = k
                break
        if matched is None:
            new_lines.append(line)
        elif matched in reset_set:
            print(f"Removed: {matched}")
        else:
            new_lines.append(to_lua_line(matched, set_dict[matched]))
            found_keys.add(matched)
            print(f"Updated: {to_lua_line(matched, set_dict[matched]).strip()}")

    for k, v in set_dict.items():
        if k not in found_keys:
            new_lines.append(to_lua_line(k, v))
            print(f"Added:   {to_lua_line(k, v).strip()}")

    write_atomic(file_path, "".join(new_lines))


def save_preset(anim_file, preset_name):
    content = ANIM_PRESETS.get(preset_name)
    if not content:
        print(f"Unknown preset '{preset_name}'")
        return
    write_atomic(anim_file, content)
    print(f"Wrote preset '{preset_name}' -> {anim_file}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--file", default="~/.config/hypr/hyprland/shellOverrides/main.lua")
    p.add_argument("--set", nargs=2, action="append", metavar=("KEY", "VALUE"))
    p.add_argument("--reset", action="append", metavar="KEY")
    p.add_argument("--anim-preset", metavar="PRESET")
    p.add_argument("--anim-file", default="~/.config/hypr/hyprland/shellOverrides/animations.lua")
    args = p.parse_args()

    if args.anim_preset:
        save_preset(os.path.expanduser(args.anim_file), args.anim_preset)

    raw_sets   = args.set or []
    reset_keys = args.reset or []
    set_pairs  = []
    for k, v in raw_sets:
        if v == "[[EMPTY]]":
            reset_keys.append(k)
        else:
            set_pairs.append((k, v))

    if set_pairs or reset_keys:
        edit_lua(os.path.expanduser(args.file), set_pairs, reset_keys)
    elif not args.anim_preset:
        print("Error: specify --set, --reset, or --anim-preset")