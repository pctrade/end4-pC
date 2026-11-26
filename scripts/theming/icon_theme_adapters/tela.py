#!/usr/bin/env python3
"""Tela adapter.

Tela SVGs express the accent through KDE's color-scheme classes:

    <style id="current-color-scheme">.ColorScheme-Highlight { color:#5294e2; }</style>

The color-scheme rule is rewritten everywhere. Dark variants also rewrite the
literal ``#5294e2`` fallback. Brand colors (Firefox orange, Google blue, …) are
left untouched. Tela-light uses ``#4285f4`` for the rule, which is also Google's
brand blue, so the literal fallback is deliberately disabled for light themes.
"""

from __future__ import annotations

import re
from pathlib import Path

from .base import AdapterInfo, BaseAdapter

HIGHLIGHT_RE = re.compile(
    rb"(\.ColorScheme-Highlight\s*\{\s*color\s*:\s*)#[0-9a-fA-F]{3,8}"
)
HIGHLIGHT_MARKER = b"ColorScheme-Highlight"
LITERAL_ACCENT = re.compile(rb"#5294e2", re.IGNORECASE)


class TelaAdapter(BaseAdapter):
    info = AdapterInfo("tela", 2, "full")

    def detect(self, theme: str, theme_dir: Path) -> bool:
        if theme.lower().startswith("tela"):
            return True
        index = theme_dir / "index.theme"
        try:
            text = index.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            return False
        return "tela" in text

    def supports_dynamic(self, theme_dir: Path) -> bool:
        for path in theme_dir.rglob("*.svg"):
            try:
                with path.open("rb") as handle:
                    if HIGHLIGHT_MARKER in handle.read():
                        return True
            except OSError:
                continue
        return False

    def transform_svg(self, data: bytes, relative: Path, accent: str) -> bytes | None:
        accent_bytes = accent.encode("ascii")
        # Tela-light's rule color is also Google's brand blue, so only the
        # color-scheme rule is rewritten for light variants.
        replace_literal = True
        if self._source_root is not None:
            replace_literal = not self._source_root.name.lower().endswith("-light")

        touches_rule = HIGHLIGHT_MARKER in data
        touches_literal = replace_literal and LITERAL_ACCENT.search(data) is not None
        if not touches_rule and not touches_literal:
            return None

        rewritten = HIGHLIGHT_RE.sub(lambda m: m.group(1) + accent_bytes, data)
        if replace_literal:
            rewritten = LITERAL_ACCENT.sub(accent_bytes, rewritten)
        if rewritten == data:
            return None
        return rewritten
