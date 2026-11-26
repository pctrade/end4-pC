"""Shared fixtures for the icon theme manager tests."""

from __future__ import annotations

import json
from pathlib import Path


def svg(rule: str = "#5294e2", extra: str = "") -> bytes:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg">'
        f'<style id="current-color-scheme">.ColorScheme-Highlight {{ color:{rule}; }}</style>'
        f"{extra}</svg>\n"
    ).encode()


def make_theme(
    icons_dir: Path,
    name: str,
    files: dict[str, bytes],
    symlinks: dict[str, str] | None = None,
    index_name: str | None = None,
) -> Path:
    root = icons_dir / name
    root.mkdir(parents=True, exist_ok=True)
    (root / "index.theme").write_text(
        f"[Icon Theme]\nName={index_name or name}\nDirectories=16\n\n[16]\nSize=16\n",
        encoding="utf-8",
    )
    for relative, data in files.items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for relative, link_target in (symlinks or {}).items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() or target.is_symlink():
            target.unlink()
        target.symlink_to(link_target)
    return root


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def request_payload(
    *,
    request_id: str,
    selection_id: str,
    theme: str,
    base: str,
    base_path: Path,
    out: str,
    mode: str = "dark",
    accent: str = "#e53935",
    adapter: str = "tela",
    version: int = 2,
    capability: str = "full",
    keep: int = 6,
) -> dict:
    return {
        "format": 1,
        "id": request_id,
        "selectionId": selection_id,
        "cancelled": False,
        "theme": theme,
        "adapter": adapter,
        "adapterVersion": version,
        "base": base,
        "basePath": str(base_path),
        "mode": mode,
        "accent": accent,
        "out": out,
        "capability": capability,
        "keepGenerated": keep,
    }


def selection_payload(*, selection_id: str, theme: str = "Tela", mode: str = "dark", accent: str = "#e53935") -> dict:
    return {
        "format": 1,
        "selectionId": selection_id,
        "source": "test",
        "theme": theme,
        "mode": mode,
        "accent": accent,
        "dynamicColor": True,
        "followScheme": True,
    }


def manifest_payload(
    *,
    base: str,
    base_path: Path,
    out: str,
    mode: str = "dark",
    accent: str = "#e53935",
    adapter: str = "tela",
    version: int = 2,
    created_at: str = "2024-01-01T00:00:00Z",
) -> dict:
    return {
        "format": 1,
        "generated": True,
        "adapter": adapter,
        "adapterVersion": version,
        "base": base,
        "basePath": str(base_path),
        "mode": mode,
        "accent": accent,
        "createdAt": created_at,
        "stats": {"files": 1, "symlinks": 0, "written": 1, "skipped": 0},
    }
