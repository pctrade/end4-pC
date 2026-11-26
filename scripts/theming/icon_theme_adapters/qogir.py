#!/usr/bin/env python3
"""Qogir adapter.

Qogir ships prebuilt light/dark and color variants. Until its SVGs are inspected
on a machine where it is installed, the safe behaviour is variant selection
only — no generated recoloring.
"""

from __future__ import annotations

from pathlib import Path

from .base import AdapterInfo, BaseAdapter


class QogirAdapter(BaseAdapter):
    info = AdapterInfo("qogir", 1, "none")

    def detect(self, theme: str, theme_dir: Path) -> bool:
        if theme.lower().startswith("qogir"):
            return True
        index = theme_dir / "index.theme"
        try:
            return "qogir" in index.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            return False

    def supports_dynamic(self, theme_dir: Path) -> bool:
        return False
