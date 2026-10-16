#!/usr/bin/env python3
import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path

json_path, asset_dir, local_dir, origin, display = sys.argv[1:6]
home = Path.home()
dest = {
    "wallpaper": home / "Pictures" / "Wallpapers",
    "avatar": home / "Pictures" / "avatar",
    "asset": home / "Pictures" / "preset-assets",
}
wallpaper_keys = {"wallpaperPath", "centeredWallpaperImage", "lockWall"}
image_name = re.compile(r"\.(png|jpe?g|webp)$", re.IGNORECASE)
missing = []
local_index = None


def find_local(name):
    global local_index
    if local_index is None:
        local_index = {}
        root = home / "Pictures"
        for folder, dirs, files in os.walk(root, followlinks=True):
            depth = len(Path(folder).relative_to(root).parts)
            if depth >= 3:
                dirs[:] = []
            for file in files:
                local_index.setdefault(file, Path(folder) / file)
    return local_index.get(name)
prefix = asset_dir.rstrip("/") + "/"


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def place(src, role):
    folder = dest[role]
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / src.name
    if not target.exists():
        shutil.copy2(src, target)
        return target
    src_hash = digest(src)
    if digest(target) == src_hash:
        return target
    alt = folder / f"{src.stem}-{src_hash[:8]}{src.suffix}"
    if not alt.exists():
        shutil.copy2(src, alt)
    return alt


def convert(value, trail):
    if value.startswith(prefix):
        src = Path(value)
        if not src.is_file() or src.stat().st_size == 0:
            found = find_local(src.name)
            if found and found.stat().st_size > 0:
                return str(found)
            missing.append(src.name)
            return value
        key = trail[-1] if trail else ""
        if "collage" in trail or key in wallpaper_keys:
            role = "wallpaper"
        elif key == "avatarPicture":
            role = "avatar"
        else:
            role = "asset"
        return str(place(src, role))
    if value.rstrip("/") == prefix.rstrip("/") and trail and trail[-1] == "avatarPath":
        dest["avatar"].mkdir(parents=True, exist_ok=True)
        return str(dest["avatar"])
    if "/" not in value and image_name.search(value):
        found = find_local(value)
        if found:
            return str(found)
        missing.append(value)
    return value


def walk(node, trail):
    if isinstance(node, dict):
        return {k: walk(v, trail + [k]) for k, v in node.items()}
    if isinstance(node, list):
        return [walk(v, trail) for v in node]
    if isinstance(node, str):
        if trail and trail[-1] == "tree" and "collage" in trail:
            try:
                inner = json.loads(node)
            except ValueError:
                return node
            return json.dumps(walk(inner, trail), separators=(",", ":"))
        return convert(node, trail)
    return node


with open(json_path, encoding="utf-8") as f:
    data = json.load(f)

data = walk(data, [])
meta = data.get("_presetMeta") if isinstance(data.get("_presetMeta"), dict) else {}
meta.pop("source", None)
meta["origin"] = origin
data["_presetMeta"] = meta

safe = re.sub(r"[^\w.-]+", "_", display).strip("._") or "preset"
folder = Path(local_dir)
folder.mkdir(parents=True, exist_ok=True)
name = safe
n = 2
while (folder / f"{name}.json").exists():
    name = f"{safe}_{n}"
    n += 1
out = folder / f"{name}.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(out)
if missing:
    print("missing: " + ", ".join(sorted(set(missing))))
