#!/usr/bin/env python3
import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

SCHEMES_DIR = Path(__file__).resolve().parent / "schemes"
USER_SCHEMES_DIR = Path.home() / ".config/illogical-impulse/schemes"

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
SURFACE_KEYS = [
    "surface_dim", "surface", "surface_bright", "surface_container_lowest", "surface_container_low",
    "surface_container", "surface_container_high", "surface_container_highest",
    "on_surface", "on_surface_variant", "outline", "outline_variant", "error", "on_accent",
]

parser = argparse.ArgumentParser(description="Apply a named color scheme through the matugen templates")
parser.add_argument("--scheme")
parser.add_argument("--list", action="store_true")
parser.add_argument("--validate", metavar="FILE")
parser.add_argument("--import-file", metavar="FILE")
parser.add_argument("--primary", default="")
parser.add_argument("--secondary", default="")
parser.add_argument("--mode", choices=["dark", "light"], default="dark")
parser.add_argument("--image", default="")
parser.add_argument("--scss")
parser.add_argument("--cache")
parser.add_argument("--matugen-config", default=str(Path.home() / ".config/matugen/config.toml"))
args = parser.parse_args()


def validate_scheme(data):
    errors = []
    if not isinstance(data.get("name"), str) or not data["name"].strip():
        errors.append('"name" must be a non-empty string')
    accent_names = {}
    for mode in ("dark", "light"):
        block = data.get(mode)
        if not isinstance(block, dict):
            errors.append(f'"{mode}" block is missing')
            continue
        for key in SURFACE_KEYS:
            value = block.get(key)
            if not (isinstance(value, str) and HEX.match(value)):
                errors.append(f'{mode}.{key} must be a hex color like "#1e1e2e"')
        accents = block.get("accents")
        if not isinstance(accents, dict) or not accents:
            errors.append(f'{mode}.accents must list at least one accent color')
            accents = {}
        for name, value in accents.items():
            if not (isinstance(value, str) and HEX.match(value)):
                errors.append(f'{mode}.accents.{name} must be a hex color')
        accent_names[mode] = set(accents)
        term = block.get("term")
        if not (isinstance(term, list) and len(term) == 16 and all(isinstance(c, str) and HEX.match(c) for c in term)):
            errors.append(f"{mode}.term must be a list of exactly 16 hex colors")
    defaults = data.get("defaults")
    if not isinstance(defaults, dict):
        errors.append('"defaults" must set primary, secondary and tertiary accent names')
    else:
        for slot in ("primary", "secondary", "tertiary"):
            name = defaults.get(slot)
            for mode, names in accent_names.items():
                if name not in names:
                    errors.append(f'defaults.{slot} "{name}" is not an accent in {mode}.accents')
    return errors


def load_scheme_file(path):
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"cannot read JSON: {exc}"]
    errors = validate_scheme(data)
    return (None, errors) if errors else (data, [])


def discover_schemes():
    found = {}
    for source, directory in (("builtin", SCHEMES_DIR), ("user", USER_SCHEMES_DIR)):
        if not directory.is_dir():
            continue
        for file in sorted(directory.glob("*.json")):
            if file.stem.startswith("_"):
                continue
            data, errors = load_scheme_file(file)
            if data is None:
                print(f"[named_scheme] skipping {file}: {'; '.join(errors)}", file=sys.stderr)
                continue
            found[file.stem] = (source, data)
    return found

if args.validate:
    _, errors = load_scheme_file(args.validate)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("OK")
    sys.exit(0)

if args.import_file:
    source = Path(args.import_file)
    _, errors = load_scheme_file(source)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    USER_SCHEMES_DIR.mkdir(parents=True, exist_ok=True)
    target = USER_SCHEMES_DIR / re.sub(r"[^A-Za-z0-9_-]", "_", source.stem).lstrip("_")
    target = target.with_suffix(".json")
    target.write_text(source.read_text())
    print(target.stem)
    sys.exit(0)

if args.list:
    listing = {}
    for scheme_id, (source, data) in discover_schemes().items():
        listing[scheme_id] = {
            "name": data["name"],
            "source": source,
            "defaults": data["defaults"],
            "accents": {mode: data[mode]["accents"] for mode in ("dark", "light")},
        }
    print(json.dumps(listing))
    sys.exit(0)

if not (args.scheme and args.scss and args.cache):
    parser.error("--scheme, --scss and --cache are required")


def parse_hex(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*[max(0, min(255, round(c))) for c in rgb])


def mix(a, b, amount):
    ra, rb = parse_hex(a), parse_hex(b)
    return to_hex(tuple(x + (y - x) * amount for x, y in zip(ra, rb)))


def resolve_accents(data, mode):
    palette = dict(data[mode])
    accents = palette.pop("accents")
    chosen = dict(data["defaults"])
    for slot, name in (("primary", args.primary), ("secondary", args.secondary)):
        if name in accents:
            chosen[slot] = name
    for slot, name in chosen.items():
        palette[slot] = accents[name]
    return palette


def build_roles(palette, dark):
    roles = {key: value for key, value in palette.items() if key not in ("term", "on_accent")}
    on_accent = palette["on_accent"]
    surface = palette["surface"]
    on_surface = palette["on_surface"]
    container_amount = 0.30 if dark else 0.22

    for name in ("primary", "secondary", "tertiary", "error"):
        accent = palette[name]
        container = mix(surface, accent, container_amount)
        roles[f"on_{name}"] = on_accent
        roles[f"{name}_container"] = container
        roles[f"on_{name}_container"] = on_surface
        if name == "error":
            continue
        roles[f"{name}_fixed"] = accent
        roles[f"{name}_fixed_dim"] = mix(accent, surface, 0.25)
        roles[f"on_{name}_fixed"] = on_accent
        roles[f"on_{name}_fixed_variant"] = mix(on_accent, accent, 0.3)

    roles["background"] = surface
    roles["on_background"] = on_surface
    roles["surface_variant"] = palette["surface_container_high"]
    roles["surface_tint"] = palette["primary"]
    roles["inverse_surface"] = on_surface
    roles["inverse_on_surface"] = surface
    roles["inverse_primary"] = mix(palette["primary"], surface, 0.45)
    roles["shadow"] = "#000000"
    roles["scrim"] = "#000000"
    roles["source_color"] = palette["primary"]
    return roles


available = discover_schemes()
if args.scheme not in available:
    sys.exit(f"[named_scheme] unknown or invalid scheme '{args.scheme}' (run with --validate on its file for details)")

scheme = available[args.scheme][1]
palettes = {mode: resolve_accents(scheme, mode) for mode in ("dark", "light")}
roles = {mode: build_roles(palettes[mode], mode == "dark") for mode in ("dark", "light")}
roles["default"] = roles[args.mode]

token = re.compile(r"\{\{\s*colors\.(\w+)\.(default|dark|light)\.(hex|hex_stripped|red|green|blue)\s*\}\}")
image_token = re.compile(r"\{\{\s*image\s*\}\}")


def render_token(match):
    role, variant, form = match.groups()
    value = roles[variant].get(role)
    if value is None:
        return match.group(0)
    if form == "hex":
        return value
    if form == "hex_stripped":
        return value.lstrip("#")
    return str(parse_hex(value)["rgb".index(form[0])])


def render(template):
    return image_token.sub(args.image, token.sub(render_token, template))


config = tomllib.loads(Path(args.matugen_config).read_text())
for name, entry in config.get("templates", {}).items():
    source = Path(entry["input_path"]).expanduser()
    target = Path(entry["output_path"]).expanduser()
    if not source.is_file():
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(render(source.read_text()))

camel = lambda snake: re.sub(r"_([a-z])", lambda m: m.group(1).upper(), snake)
lines = [f"$darkmode: {'True' if args.mode == 'dark' else 'False'};", "$transparent: False;"]
for role, value in roles["default"].items():
    if role != "source_color":
        lines.append(f"${camel(role)}: {value.upper()};")
if args.mode == "dark":
    extra = {"success": "#B5CCBA", "onSuccess": "#213528", "successContainer": "#374B3E", "onSuccessContainer": "#D1E9D6"}
else:
    extra = {"success": "#4F6354", "onSuccess": "#FFFFFF", "successContainer": "#D1E8D5", "onSuccessContainer": "#0C1F13"}
for role, value in extra.items():
    lines.append(f"${role}: {value};")
term = list(palettes[args.mode]["term"])
term[0] = palettes[args.mode]["surface"]
term[7] = palettes[args.mode]["on_surface"]
for index, value in enumerate(term):
    lines.append(f"$term{index}: {value.upper()};")
Path(args.scss).write_text("\n".join(lines) + "\n")
Path(args.cache).write_text(roles["default"]["primary"].upper())


KDE_SCHEMES_DIR = Path.home() / ".local/share/color-schemes"


def kde_group(bg, bg_alt, fg, fg_inactive, accent, link, visited, negative, neutral, positive, fg_active=None):
    return {
        "BackgroundAlternate": bg_alt,
        "BackgroundNormal": bg,
        "DecorationFocus": accent,
        "DecorationHover": accent,
        "ForegroundActive": fg_active or accent,
        "ForegroundInactive": fg_inactive,
        "ForegroundLink": link,
        "ForegroundNegative": negative,
        "ForegroundNeutral": neutral,
        "ForegroundPositive": positive,
        "ForegroundNormal": fg,
        "ForegroundVisited": visited,
    }


def write_kde_scheme(role, term, name):
    r = role
    ansi = dict(positive=term[10], neutral=term[11], link=term[12], visited=term[13])
    common = dict(link=ansi["link"], visited=ansi["visited"], negative=r["error"], neutral=ansi["neutral"], positive=ansi["positive"])
    groups = {
        "ColorEffects:Disabled": {"Color": r["surface_container"], "ColorAmount": "0.5", "ColorEffect": "3", "ContrastAmount": "0", "ContrastEffect": "0", "IntensityAmount": "0", "IntensityEffect": "0"},
        "ColorEffects:Inactive": {"ChangeSelectionColor": "true", "Color": r["surface_dim"], "ColorAmount": "0.025", "ColorEffect": "0", "ContrastAmount": "0.1", "ContrastEffect": "0", "Enable": "true", "IntensityAmount": "0", "IntensityEffect": "0"},
        "Colors:Button": kde_group(r["surface_container"], r["surface_container_high"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "Colors:Complementary": kde_group(r["surface_container_low"], r["surface_dim"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "Colors:Header": kde_group(r["surface_container_low"], r["surface"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "Colors:Selection": kde_group(r["primary"], r["primary_container"], r["on_primary"], r["on_primary"], r["primary"],
            link=r["on_primary"], visited=r["on_primary"], negative=r["on_primary"], neutral=r["on_primary"], positive=r["on_primary"], fg_active=r["on_primary"]),
        "Colors:Tooltip": kde_group(r["surface_container_high"], r["surface_container"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "Colors:View": kde_group(r["surface_container_lowest"], r["surface"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "Colors:Window": kde_group(r["surface"], r["surface_container_low"], r["on_surface"], r["on_surface_variant"], r["primary"], **common),
        "General": {"ColorScheme": name, "Name": name, "shadeSortColumn": "true"},
        "KDE": {"contrast": "4"},
        "WM": {"activeBackground": r["surface_container_low"], "activeBlend": r["on_surface"], "activeForeground": r["on_surface"],
               "inactiveBackground": r["surface"], "inactiveBlend": r["on_surface_variant"], "inactiveForeground": r["on_surface_variant"]},
    }
    lines = []
    for group, values in groups.items():
        lines.append(f"[{group}]")
        lines.extend(f"{key}={value}" for key, value in values.items())
        lines.append("")
    KDE_SCHEMES_DIR.mkdir(parents=True, exist_ok=True)
    (KDE_SCHEMES_DIR / f"{name}.colors").write_text("\n".join(lines))


for kde_name in ("IllogicalNamed", "IllogicalNamed2"):
    write_kde_scheme(roles["default"], term, kde_name)
