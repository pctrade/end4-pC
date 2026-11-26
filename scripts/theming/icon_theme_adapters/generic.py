#!/usr/bin/env python3
"""Generic fallback adapter: variants only, no recoloring."""

from __future__ import annotations

from pathlib import Path

from .base import AdapterInfo, BaseAdapter


class GenericAdapter(BaseAdapter):
    info = AdapterInfo("generic", 1, "none")

    def detect(self, theme: str, theme_dir: Path) -> bool:
        return True

    def supports_dynamic(self, theme_dir: Path) -> bool:
        return False
