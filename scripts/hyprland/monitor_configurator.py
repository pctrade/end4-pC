#!/usr/bin/env -S /bin/sh -c "source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate&&exec python -E \"$0\" \"$@\""
import argparse
import json
import os
import re
import tempfile

STRING_KEYS = {"output", "mode", "position", "cm", "mirror"}
BOOL_KEYS = {"disabled"}
FIELD_RE = re.compile(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*,?\s*(--.*)?$')
OUTPUT_RE = re.compile(r'output\s*=\s*"([^"]*)"')


def to_lua_value(key, value):
    if key in STRING_KEYS:
        return f'"{value}"'
    if key in BOOL_KEYS:
        return "false" if str(value) in ("0", "false", "False") else "true"
    try:
        return str(int(value))
    except ValueError:
        pass
    try:
        return str(float(value))
    except ValueError:
        pass
    return f'"{value}"'


def parse_lua_value(raw):
    raw = raw.strip()
    if raw in ("true", "false"):
        return raw == "true"
    m = re.match(r'^"(.*)"$', raw)
    if m:
        return m.group(1)
    try:
        return int(raw)
    except ValueError:
        pass
    try:
        return float(raw)
    except ValueError:
        pass
    return raw


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


def split_blocks(lines):
    # Tracks paren/brace balance to find each hl.monitor({ ... }) call without needing a real Lua parser.
    segments = []
    in_block = False
    balance = 0
    block_lines = []

    for line in lines:
        if not in_block:
            if re.search(r'hl\.monitor\s*\(', line):
                in_block = True
                balance = 0
                block_lines = []
            else:
                segments.append(('line', line))
                continue

        block_lines.append(line)
        balance += line.count('(') + line.count('{') - line.count(')') - line.count('}')
        if balance <= 0:
            joined = "".join(block_lines)
            m = OUTPUT_RE.search(joined)
            segments.append(('block', m.group(1) if m else None, block_lines))
            in_block = False

    if in_block:
        # Malformed/unterminated block - keep as plain lines instead of dropping content.
        segments.extend(('line', l) for l in block_lines)

    return segments


def rebuild_field_line(m, key, value):
    indent, comment = m.group(1), m.group(4)
    line = f"{indent}{key} = {value},"
    if comment:
        line += f" {comment}"
    return line + "\n"


def edit_block_lines(block_lines, set_dict, reset_keys):
    header = block_lines[0]
    footer = block_lines[-1]
    body = block_lines[1:-1]

    default_indent = "    "
    for line in body:
        m = FIELD_RE.match(line)
        if m and m.group(1):
            default_indent = m.group(1)
            break

    new_body = []
    found = set()
    for line in body:
        if line.strip().startswith('--'):
            new_body.append(line)
            continue
        m = FIELD_RE.match(line)
        if not m:
            new_body.append(line)
            continue

        key = m.group(2)
        if key in reset_keys:
            print(f"Removed: {key}")
            continue
        if key in set_dict:
            new_line = rebuild_field_line(m, key, to_lua_value(key, set_dict[key]))
            found.add(key)
            print(f"Updated: {new_line.strip()}")
        else:
            # Force a trailing comma even on untouched lines so that we can safely append new lines later.
            new_line = rebuild_field_line(m, key, m.group(3))
        new_body.append(new_line)

    for key, value in set_dict.items():
        if key not in found:
            new_line = f"{default_indent}{key} = {to_lua_value(key, value)},\n"
            new_body.append(new_line)
            print(f"Added:   {new_line.strip()}")

    return [header] + new_body + [footer]


def build_new_block(output, set_dict):
    lines = ["hl.monitor({\n", f'    output = "{output}",\n']
    for key, value in set_dict.items():
        if key == "output":
            continue
        line = f"    {key} = {to_lua_value(key, value)},\n"
        lines.append(line)
        print(f"Added:   {line.strip()}")
    lines.append("})\n")
    return lines


def edit_lua(file_path, output, set_pairs, reset_keys):
    try:
        with open(file_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []

    set_dict = dict(set_pairs)
    reset_set = set(reset_keys)
    segments = split_blocks(lines)

    target_idx = None
    for i, seg in enumerate(segments):
        if seg[0] == 'block' and seg[1] == output:
            target_idx = i
            break

    if target_idx is not None:
        _, _, block_lines = segments[target_idx]
        new_block_lines = edit_block_lines(block_lines, set_dict, reset_set)
        segments[target_idx] = ('block', output, new_block_lines)
    elif reset_set and not set_dict:
        print(f"No existing block for output '{output}', nothing to reset.")
    else:
        full_set = dict(set_dict)
        full_set.setdefault("output", output)
        new_block_lines = build_new_block(output, full_set)
        if segments and not (segments[-1][0] == 'line' and segments[-1][1].strip() == ""):
            segments.append(('line', "\n"))
        segments.append(('block', output, new_block_lines))

    out_lines = []
    for seg in segments:
        if seg[0] == 'line':
            out_lines.append(seg[1])
        else:
            out_lines.extend(seg[2])

    write_atomic(file_path, "".join(out_lines))


def extract_fields(block_lines):
    result = {}
    for line in block_lines[1:-1]:
        if line.strip().startswith('--'):
            continue
        m = FIELD_RE.match(line)
        if m:
            result[m.group(2)] = parse_lua_value(m.group(3))
    return result


def read_segments(file_path):
    try:
        with open(file_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return []
    return split_blocks(lines)


def dump_block(file_path, output):
    for seg in read_segments(file_path):
        if seg[0] == 'block' and seg[1] == output:
            print(json.dumps(extract_fields(seg[2])))
            return
    print(json.dumps({}))


def dump_all(file_path):
    result = {}
    for seg in read_segments(file_path):
        if seg[0] == 'block' and seg[1]:
            result[seg[1]] = extract_fields(seg[2])
    print(json.dumps(result))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--file", default="~/.config/hypr/monitors.lua")
    p.add_argument("--output", help="Monitor output name, e.g. DP-1 (required for --set/--reset/--dump)")
    p.add_argument("--set", nargs=2, action="append", metavar=("KEY", "VALUE"))
    p.add_argument("--reset", action="append", metavar="KEY")
    p.add_argument("--dump", action="store_true", help="Print this output's current fields as JSON instead of writing")
    p.add_argument("--dump-all", action="store_true", help="Print every output's current fields as JSON, keyed by output name")
    args = p.parse_args()

    file_path = os.path.expanduser(args.file)

    if args.dump_all:
        dump_all(file_path)
    elif args.dump:
        if not args.output:
            p.error("--dump requires --output")
        dump_block(file_path, args.output)
    else:
        if not args.output:
            p.error("--set/--reset require --output")
        raw_sets = args.set or []
        reset_keys = args.reset or []
        set_pairs = []
        for k, v in raw_sets:
            if v == "[[EMPTY]]":
                reset_keys.append(k)
            else:
                set_pairs.append((k, v))

        if set_pairs or reset_keys:
            edit_lua(file_path, args.output, set_pairs, reset_keys)
        else:
            print("Error: specify --set, --reset, --dump, or --dump-all")
