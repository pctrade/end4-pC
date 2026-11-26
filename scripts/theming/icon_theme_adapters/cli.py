#!/usr/bin/env python3
"""Small CLI used by icon-theme-manager.sh to resolve themes via adapters."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as a script: python3 .../icon_theme_adapters/cli.py
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from icon_theme_adapters import adapter_for  # type: ignore
    from icon_theme_adapters.base import (  # type: ignore
        BaseAdapter,
        find_theme,
        generated_manifest_name,
        normalize_hex,
        theme_exists,
    )
else:  # pragma: no cover - imported as a package
    from . import adapter_for
    from .base import BaseAdapter, find_theme, generated_manifest_name, normalize_hex, theme_exists


def _has_variants(theme: str, base: str) -> bool:
    if base != theme:
        return True
    for suffix in ("light", "Light", "dark", "Dark"):
        if theme_exists(f"{theme}-{suffix}"):
            return True
    return False


def _resolve_adapter(theme: str, theme_dir: Path) -> BaseAdapter:
    return adapter_for(theme, theme_dir)


def _locate(theme: str) -> tuple[Path | None, str]:
    """Find the configured theme, or one of its light/dark variants.

    A user may have installed only ``Tela-dark``/``Tela-light`` while the
    configured base name is ``Tela``. Variant resolution still works in that
    case, so locate the adapter from whatever variant exists.
    """
    direct = find_theme(theme)
    if direct is not None:
        return direct, theme
    for suffix in ("dark", "Dark", "light", "Light"):
        candidate = f"{theme}-{suffix}"
        found = find_theme(candidate)
        if found is not None:
            return found, candidate
    return None, theme


def resolve(args: argparse.Namespace) -> dict:
    theme = args.theme
    mode = args.mode if args.mode in ("light", "dark", "static") else "dark"
    accent = normalize_hex(args.accent)
    theme_dir, detected = _locate(theme)
    if theme_dir is None:
        return {"ok": False, "error": f"theme not found: {theme}", "theme": theme}

    adapter = _resolve_adapter(detected, theme_dir)

    if mode == "static":
        base = detected
        base_dir = theme_dir
        has_variants = False
    else:
        override = args.light_override if mode == "light" else args.dark_override
        if override and not theme_exists(override):
            override = ""
        base = adapter.resolve_variant(theme, mode, override or "")
        if not base:
            return {"ok": False, "error": f"no variant for {theme} ({mode})", "theme": theme}
        base_dir = find_theme(base)
        if base_dir is None:
            return {"ok": False, "error": f"variant not found: {base}", "theme": theme}
        has_variants = _has_variants(theme, base)

    capability = adapter.info.capability
    dynamic = (
        bool(args.dynamic)
        and capability != "none"
        and accent is not None
        and adapter.supports_dynamic(base_dir)
    )
    # Always include the mode for scheme-following themes so Light and Dark can
    # coexist for the same accent. Static mode uses the shorter form.
    out = (
        generated_manifest_name(theme, mode, accent or "#000000", mode != "static")
        if dynamic
        else base
    )

    return {
        "ok": True,
        "theme": theme,
        "mode": mode,
        "accent": accent or "",
        "adapter": adapter.info.name,
        "adapterVersion": adapter.info.version,
        "capability": capability,
        "dynamic": dynamic,
        "hasVariants": has_variants,
        "base": base,
        "basePath": str(base_dir),
        "out": out,
    }


def capability(args: argparse.Namespace) -> dict:
    theme = args.theme
    mode = args.mode if args.mode in ("light", "dark", "static") else "dark"
    theme_dir, detected = _locate(theme)
    if theme_dir is None:
        return {"ok": False, "error": f"theme not found: {theme}", "capability": "none"}
    adapter = _resolve_adapter(detected, theme_dir)
    if mode == "static":
        base_dir = theme_dir
    else:
        override = args.light_override if mode == "light" else args.dark_override
        if override and not theme_exists(override):
            override = ""
        base = adapter.resolve_variant(theme, mode, override or "")
        base_dir = find_theme(base) if base else None
    return {
        "ok": True,
        "theme": theme,
        "adapter": adapter.info.name,
        "adapterVersion": adapter.info.version,
        "capability": adapter.info.capability,
        "dynamic": bool(base_dir and adapter.supports_dynamic(base_dir)),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Icon theme adapter CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    def add_common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--theme", required=True)
        p.add_argument("--mode", default="dark")
        p.add_argument("--light-override", default="")
        p.add_argument("--dark-override", default="")

    p_resolve = sub.add_parser("resolve")
    add_common(p_resolve)
    p_resolve.add_argument("--accent", default="")
    p_resolve.add_argument("--dynamic", action="store_true")

    p_cap = sub.add_parser("capability")
    add_common(p_cap)

    args = parser.parse_args()
    if args.command == "resolve":
        result = resolve(args)
    elif args.command == "capability":
        result = capability(args)
    else:  # pragma: no cover
        parser.error("unknown command")
        return 2

    json.dump(result, sys.stdout)
    sys.stdout.write("\n")
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
