#!/usr/bin/env python3
import configparser
import json
import os
import sys

WANTED_SIZE = 64
EXTENSIONS = ("svg", "png", "xpm")


def data_dirs():
    home = os.path.expanduser("~")
    data_home = os.environ.get("XDG_DATA_HOME", os.path.join(home, ".local/share"))
    extra = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    return [os.path.join(home, ".icons"), os.path.join(data_home, "icons")] + [os.path.join(d, "icons") for d in extra if d]


def find_theme_roots(theme):
    return [os.path.join(d, theme) for d in data_dirs() if os.path.isfile(os.path.join(d, theme, "index.theme"))]


def load_theme(theme):
    roots = find_theme_roots(theme)
    entries = []
    inherits = []
    for root in roots:
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            parser.read(os.path.join(root, "index.theme"), encoding="utf-8")
        except configparser.Error:
            continue
        if not parser.has_section("Icon Theme"):
            continue
        section = parser["Icon Theme"]
        inherits += [t.strip() for t in section.get("Inherits", "").split(",") if t.strip()]
        directories = [d for d in section.get("Directories", "").split(",") if d] + [d for d in section.get("ScaledDirectories", "").split(",") if d]
        for directory in directories:
            if not parser.has_section(directory):
                continue
            info = parser[directory]
            size = int(info.get("Size", "0") or 0)
            kind = info.get("Type", "Threshold")
            entries.append({
                "root": root,
                "dir": directory,
                "size": size,
                "type": kind,
                "min": int(info.get("MinSize", size) or size),
                "max": int(info.get("MaxSize", size) or size),
                "threshold": int(info.get("Threshold", "2") or 2),
                "scale": int(info.get("Scale", "1") or 1),
            })
    return entries, inherits


def distance(entry):
    size = entry["size"]
    if entry["type"] == "Scalable":
        if entry["min"] <= WANTED_SIZE <= entry["max"]:
            return 0
        return min(abs(entry["min"] - WANTED_SIZE), abs(entry["max"] - WANTED_SIZE))
    if entry["type"] == "Fixed":
        return abs(size - WANTED_SIZE)
    low, high = size - entry["threshold"], size + entry["threshold"]
    if low <= WANTED_SIZE <= high:
        return 0
    return min(abs(low - WANTED_SIZE), abs(high - WANTED_SIZE))


def lookup_in_theme(entries, name):
    best = None
    for entry in entries:
        for ext in EXTENSIONS:
            path = os.path.join(entry["root"], entry["dir"], f"{name}.{ext}")
            if not os.path.isfile(path):
                continue
            score = (entry["scale"] != 1, distance(entry), EXTENSIONS.index(ext))
            if best is None or score < best[0]:
                best = (score, path)
    return best[1] if best else None


def theme_chain(theme):
    chain = []
    pending = [theme]
    while pending:
        current = pending.pop(0)
        if current in chain:
            continue
        chain.append(current)
        pending = load_theme(current)[1] + pending
    if "hicolor" not in chain:
        chain.append("hicolor")
    return chain


def name_candidates(name):
    yield name
    parts = name.split("-")
    while len(parts) > 1:
        parts = parts[:-1]
        yield "-".join(parts)


def resolve(theme, names):
    chain = [(t, load_theme(t)[0]) for t in theme_chain(theme)]
    result = {}
    for name in names:
        found = ""
        if os.path.isabs(name) and os.path.isfile(name):
            found = name
        else:
            for candidate in name_candidates(name):
                for _, entries in chain:
                    path = lookup_in_theme(entries, candidate)
                    if path:
                        found = path
                        break
                if found:
                    break
            if not found:
                for ext in EXTENSIONS:
                    path = f"/usr/share/pixmaps/{name}.{ext}"
                    if os.path.isfile(path):
                        found = path
                        break
        result[name] = found
    return result


def main():
    theme = sys.argv[1]
    names = sys.argv[2:] or [line.strip() for line in sys.stdin if line.strip()]
    json.dump(resolve(theme, names), sys.stdout)


if __name__ == "__main__":
    main()
