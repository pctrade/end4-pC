#!/usr/bin/env python3
"""Adapter registry."""

from __future__ import annotations

from pathlib import Path

from .base import BaseAdapter
from .generic import GenericAdapter
from .papirus import PapirusAdapter
from .qogir import QogirAdapter
from .tela import TelaAdapter

ADAPTERS: list[BaseAdapter] = [
    TelaAdapter(),
    PapirusAdapter(),
    QogirAdapter(),
    GenericAdapter(),
]


def adapter_for(theme: str, theme_dir: Path) -> BaseAdapter:
    for adapter in ADAPTERS:
        if adapter.detect(theme, theme_dir):
            return adapter
    return ADAPTERS[-1]


def adapter_by_name(name: str) -> BaseAdapter | None:
    for adapter in ADAPTERS:
        if adapter.info.name == name:
            return adapter
    return None


__all__ = [
    "ADAPTERS",
    "adapter_for",
    "adapter_by_name",
    "GenericAdapter",
    "PapirusAdapter",
    "QogirAdapter",
    "TelaAdapter",
]
