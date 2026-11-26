#!/usr/bin/env python3
"""Papirus adapter.

Papirus supports folder colors through the upstream ``papirus-folders`` tool.
When that tool is available it is run after publishing; otherwise a conservative
SVG fallback rewrites the color-scheme highlight rule everywhere and the literal
accent inside ``places/`` (folders) only. Symbolic and brand assets are left
untouched, so the advertised capability is ``partial``.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

from .base import AdapterInfo, BaseAdapter, normalize_hex

HIGHLIGHT_RE = re.compile(
    rb"(\.ColorScheme-Highlight\s*\{\s*color\s*:\s*)#[0-9a-fA-F]{3,8}"
)
HIGHLIGHT_MARKER = b"ColorScheme-Highlight"
LITERAL_ACCENT = re.compile(rb"#5294e2", re.IGNORECASE)

# Names understood by papirus-folders -> representative colors, used only to
# pick the nearest supported folder color.
PAPIRUS_COLORS = {
    "blue": "#5294e2",
    "green": "#4caf50",
    "red": "#f44336",
    "yellow": "#fbc02d",
    "orange": "#ff9800",
    "purple": "#9c27b0",
    "pink": "#e91e63",
    "teal": "#009688",
    "cyan": "#00bcd4",
    "grey": "#9e9e9e",
    "black": "#4d4d4d",
    "white": "#f2f2f2",
    "brown": "#795548",
    "indigo": "#3f51b5",
    "nordic": "#5e81ac",
    "dracula": "#bd93f9",
    "catppuccin": "#cba6f7",
}


def _rgb(hex_color: str) -> tuple[int, int, int]:
    value = hex_color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def nearest_color(accent: str) -> str:
    accent = (normalize_hex(accent) or "#5294e2").lower()
    target = _rgb(accent)
    best_name = "blue"
    best_distance = float("inf")
    for name, value in PAPIRUS_COLORS.items():
        other = _rgb(value)
        distance = sum((a - b) ** 2 for a, b in zip(target, other))
        if distance < best_distance:
            best_name, best_distance = name, distance
    return best_name


class PapirusAdapter(BaseAdapter):
    info = AdapterInfo("papirus", 2, "partial")

    def detect(self, theme: str, theme_dir: Path) -> bool:
        if theme.lower().startswith("papirus"):
            return True
        index = theme_dir / "index.theme"
        try:
            return "papirus" in index.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            return False

    def supports_dynamic(self, theme_dir: Path) -> bool:
        if shutil.which("papirus-folders"):
            return True
        for path in theme_dir.rglob("*.svg"):
            try:
                with path.open("rb") as handle:
                    data = handle.read()
                if HIGHLIGHT_MARKER in data or LITERAL_ACCENT.search(data):
                    return True
            except OSError:
                continue
        return False

    def post_publish_handles_colors(self) -> bool:
        return bool(shutil.which("papirus-folders"))

    def transform_svg(self, data: bytes, relative: Path, accent: str) -> bytes | None:
        accent_bytes = accent.encode("ascii")
        light_variant = False
        if self._source_root is not None:
            light_variant = self._source_root.name.lower().endswith("-light")

        in_places = "places" in relative.parts
        touches_rule = HIGHLIGHT_MARKER in data
        touches_literal = (
            in_places and not light_variant and LITERAL_ACCENT.search(data) is not None
        )
        if not touches_rule and not touches_literal:
            return None

        rewritten = HIGHLIGHT_RE.sub(lambda m: m.group(1) + accent_bytes, data)
        if touches_literal:
            rewritten = LITERAL_ACCENT.sub(accent_bytes, rewritten)
        if rewritten == data:
            return None
        return rewritten

    def post_publish(self, theme_name: str, accent: str, icons_dir: Path) -> None:
        tool = shutil.which("papirus-folders")
        if not tool:
            return
        color = nearest_color(accent)
        try:
            subprocess.run(
                [tool, "-t", theme_name, "-C", color],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=180,
            )
        except (OSError, subprocess.TimeoutExpired):
            return
