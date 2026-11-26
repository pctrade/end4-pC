#!/usr/bin/env python3
"""Shared contract and helpers for icon-theme adapters."""

from __future__ import annotations

import json
import os
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Literal

GENERATED_RE = re.compile(r"^[A-Za-z0-9._-]+-Dynamic-(?:Light-|Dark-)?[0-9a-f]{6}$")
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
# Theme directory names may contain spaces, but must not contain path
# separators or be a dot-entry.
NAME_RE = re.compile(r"^(?!\.{1,2}$)[^/\x00]+$")


class IconThemeError(Exception):
    """Base error for the icon theme manager."""


class AdapterError(IconThemeError):
    """Raised when an adapter cannot build a theme."""


@dataclass(frozen=True)
class AdapterInfo:
    name: str
    version: int
    capability: Literal["full", "partial", "none"]


@dataclass
class RecolorStats:
    files: int = 0
    symlinks: int = 0
    written: int = 0
    skipped: int = 0

    def as_dict(self) -> dict:
        return {
            "files": self.files,
            "symlinks": self.symlinks,
            "written": self.written,
            "skipped": self.skipped,
        }


def data_dirs() -> list[Path]:
    """Standard icon theme roots, in lookup order."""
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    extra = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs: list[Path] = [home / ".icons", data_home / "icons"]
    for item in extra.split(":"):
        if item:
            dirs.append(Path(item) / "icons")
    return dirs


def find_theme(name: str) -> Path | None:
    if not name or not NAME_RE.match(name):
        return None
    for root in data_dirs():
        candidate = root / name
        if (candidate / "index.theme").is_file():
            return candidate
    return None


def theme_exists(name: str) -> bool:
    return find_theme(name) is not None


def installed_themes() -> list[str]:
    names: set[str] = set()
    for root in data_dirs():
        if not root.is_dir():
            continue
        try:
            for entry in root.iterdir():
                if entry.is_dir() and (entry / "index.theme").is_file():
                    names.add(entry.name)
        except OSError:
            continue
    return sorted(names)


def normalize_hex(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip()
    if not value.startswith("#"):
        value = "#" + value
    if not HEX_RE.match(value):
        return None
    return value.lower()


def is_path_inside(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (ValueError, OSError, RuntimeError):
        return False


def read_json(path: Path) -> dict | None:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def generated_manifest_name(theme: str, mode: str, accent: str, has_variants: bool) -> str:
    """Deterministic name for a generated theme."""
    accent = accent.lstrip("#").lower()
    safe_theme = re.sub(r"[^A-Za-z0-9._-]+", "-", theme).strip("-.")
    if not safe_theme:
        safe_theme = "IconTheme"
    if has_variants:
        return f"{safe_theme}-Dynamic-{mode.capitalize()}-{accent}"
    return f"{safe_theme}-Dynamic-{accent}"


class BaseAdapter:
    """Default adapter: only understands light/dark variants.

    The base implementation materializes the theme: every regular file is
    copied (or transformed), and symlinks are either:
      * re-created as relative links to the corresponding *generated* file, or
      * followed and materialized when they point to a sibling theme.

    Tela-dark/Tela-light, for example, get most of their app/status assets via
    symlinks to ``../Tela``. Dropping those links would leave the generated
    theme missing most icons, so the sibling assets must be included.
    """

    info = AdapterInfo("generic", 1, "none")
    _source_root: Path | None = None
    _dst_root: Path | None = None

    def detect(self, theme: str, theme_dir: Path) -> bool:
        return False

    def resolve_variant(self, theme: str, mode: str, override: str = "") -> str | None:
        if override and theme_exists(override):
            return override
        suffix = "light" if mode == "light" else "dark"
        candidates = (
            f"{theme}-{suffix}",
            f"{theme}-{suffix.capitalize()}",
            f"{theme}-{'Light' if suffix == 'light' else 'Dark'}",
        )
        for candidate in candidates:
            if candidate != theme and theme_exists(candidate):
                return candidate
        if theme_exists(theme):
            return theme
        return None

    def supports_dynamic(self, theme_dir: Path) -> bool:
        return False

    def post_publish_handles_colors(self) -> bool:
        """True when a post-publish tool performs recoloring on its own."""
        return False

    def transform_svg(self, data: bytes, relative: Path, accent: str) -> bytes | None:
        """Return rewritten SVG bytes, or None when nothing needs changing."""
        return None

    def allowed_roots(self, src: Path) -> list[Path]:
        """Theme directories whose files may be followed/materialized.

        The source theme and its light/dark family are allowed. A symlink to an
        unrelated theme, or to an arbitrary path, is ignored.
        """
        origin = src.resolve()
        family = re.sub(r"-(?:dark|light)$", "", origin.name, flags=re.IGNORECASE)
        names = {
            origin.name,
            family,
            f"{family}-dark",
            f"{family}-light",
            f"{family}-Dark",
            f"{family}-Light",
        }
        roots = [origin]
        for name in names:
            found = find_theme(name)
            if found is not None:
                resolved = found.resolve()
                if resolved not in roots:
                    roots.append(resolved)
        return roots

    def recolor(self, src: Path, dst: Path, accent: str) -> RecolorStats:
        if not self.supports_dynamic(src):
            raise AdapterError(f"{self.info.name}: dynamic recoloring is not supported")
        normalized = normalize_hex(accent)
        if normalized is None:
            raise AdapterError(f"{self.info.name}: invalid accent color")

        origin = src.resolve()
        dst.mkdir(parents=True, exist_ok=True)
        self._source_root = origin
        self._dst_root = dst.resolve()
        allowed = self.allowed_roots(src)
        stats = RecolorStats()
        self._walk_dir(
            origin,
            self._dst_root,
            origin,
            self._dst_root,
            allowed,
            normalized,
            stats,
            {origin},
            0,
        )
        if stats.files and stats.written == 0 and not self.post_publish_handles_colors():
            raise AdapterError(f"{self.info.name}: no matching accent colors found")
        return stats

    def post_publish(self, theme_name: str, accent: str, icons_dir: Path) -> None:
        """Optional hook run after a theme is published (best effort)."""

    # ------------------------------------------------------------------ helpers
    def iter_files(self, root: Path) -> Iterable[Path]:
        for path in root.rglob("*"):
            if path.is_file() or path.is_symlink():
                yield path

    def link_file(self, src_file: Path, dst_file: Path, src_root: Path) -> bool:
        """Create a relative symlink that never escapes ``src_root``."""
        try:
            real = src_file.resolve()
        except OSError:
            return False
        if not is_path_inside(real, src_root):
            return False
        try:
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            if dst_file.exists() or dst_file.is_symlink():
                dst_file.unlink()
            relative = os.path.relpath(real, dst_file.parent)
            os.symlink(relative, dst_file)
            return True
        except OSError:
            return False

    def write_file(self, dst_file: Path, data: bytes) -> None:
        dst_file.parent.mkdir(parents=True, exist_ok=True)
        if dst_file.exists() or dst_file.is_symlink():
            dst_file.unlink()
        with dst_file.open("wb") as handle:
            handle.write(data)

    def copy_file(self, src_file: Path, dst_file: Path) -> None:
        dst_file.parent.mkdir(parents=True, exist_ok=True)
        if dst_file.exists() or dst_file.is_symlink():
            dst_file.unlink()
        with src_file.open("rb") as source, dst_file.open("wb") as target:
            while True:
                chunk = source.read(1024 * 256)
                if not chunk:
                    break
                target.write(chunk)

    def write_manifest(self, dst: Path, base: Path, mode: str, accent: str, stats: RecolorStats) -> None:
        manifest = {
            "format": 1,
            "generated": True,
            "adapter": self.info.name,
            "adapterVersion": self.info.version,
            "base": base.name,
            "basePath": str(base),
            "mode": mode,
            "accent": accent,
            "createdAt": None,  # filled by the worker
            "stats": stats.as_dict(),
        }
        (dst / ".icon-theme-meta.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    # --------------------------------------------------------------- materializer
    def _walk_dir(
        self,
        current: Path,
        out_current: Path,
        context_root: Path,
        context_out: Path,
        allowed: list[Path],
        accent: str,
        stats: RecolorStats,
        stack: set[Path],
        depth: int,
    ) -> None:
        if depth > 64:
            stats.skipped += 1
            return
        try:
            entries = sorted(current.iterdir(), key=lambda item: item.name)
        except OSError:
            stats.skipped += 1
            return

        for entry in entries:
            out_entry = out_current / entry.name
            try:
                if entry.is_symlink():
                    stats.symlinks += 1
                    real = entry.resolve()
                    if not real.exists():
                        stats.skipped += 1
                        continue
                    if not any(
                        real == root or is_path_inside(real, root) for root in allowed
                    ):
                        stats.skipped += 1
                        continue

                    if real.is_dir():
                        if real in stack:
                            stats.skipped += 1
                            continue
                        target: Path | None = None
                        if real == context_root or is_path_inside(real, context_root):
                            target = context_out / real.relative_to(context_root)
                        elif self._source_root is not None and (
                            real == self._source_root or is_path_inside(real, self._source_root)
                        ):
                            target = self._dst_root / real.relative_to(self._source_root)
                        if target is not None:
                            target.mkdir(parents=True, exist_ok=True)
                            if not self._make_relative_symlink(target, out_entry):
                                stats.skipped += 1
                        else:
                            # A directory from a sibling theme (for example
                            # Tela-dark/16/apps -> Tela/16/apps). Materialize it
                            # under the link's path so nothing escapes the
                            # generated theme.
                            out_entry.mkdir(parents=True, exist_ok=True)
                            self._walk_dir(
                                real,
                                out_entry,
                                real,
                                out_entry,
                                allowed,
                                accent,
                                stats,
                                stack | {real},
                                depth + 1,
                            )
                    elif real.is_file():
                        target = None
                        if real == context_root or is_path_inside(real, context_root):
                            target = context_out / real.relative_to(context_root)
                        elif self._source_root is not None and (
                            real == self._source_root or is_path_inside(real, self._source_root)
                        ):
                            target = self._dst_root / real.relative_to(self._source_root)
                        if target is not None:
                            target.parent.mkdir(parents=True, exist_ok=True)
                            if not self._make_relative_symlink(target, out_entry):
                                stats.skipped += 1
                        else:
                            # File from a sibling theme: copy/recolor it at the
                            # symlink's location instead of linking outside.
                            self._process_file(
                                real,
                                out_entry,
                                out_entry.relative_to(self._dst_root),
                                accent,
                                stats,
                            )
                    else:
                        stats.skipped += 1
                elif entry.is_dir():
                    out_entry.mkdir(parents=True, exist_ok=True)
                    resolved = entry.resolve()
                    if resolved in stack:
                        stats.skipped += 1
                        continue
                    self._walk_dir(
                        entry,
                        out_entry,
                        context_root,
                        context_out,
                        allowed,
                        accent,
                        stats,
                        stack | {resolved},
                        depth + 1,
                    )
                elif entry.is_file():
                    self._process_file(
                        entry,
                        out_entry,
                        out_entry.relative_to(self._dst_root),
                        accent,
                        stats,
                    )
                else:
                    stats.skipped += 1
            except (OSError, RuntimeError):
                stats.skipped += 1

    def _process_file(
        self,
        source: Path,
        out_path: Path,
        relative: Path,
        accent: str,
        stats: RecolorStats,
    ) -> None:
        stats.files += 1
        try:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            if out_path.is_symlink() or out_path.exists():
                if out_path.is_dir() and not out_path.is_symlink():
                    return
                out_path.unlink()
            if source.suffix.lower() == ".svg":
                data = source.read_bytes()
                rewritten = self.transform_svg(data, relative, accent)
                if rewritten is None:
                    out_path.write_bytes(data)
                else:
                    out_path.write_bytes(rewritten)
                    stats.written += 1
            else:
                shutil.copy2(source, out_path)
        except OSError:
            stats.skipped += 1

    def _make_relative_symlink(self, target: Path, link: Path) -> bool:
        try:
            link.parent.mkdir(parents=True, exist_ok=True)
            if link.is_symlink() or link.exists():
                if link.is_dir() and not link.is_symlink():
                    shutil.rmtree(link)
                else:
                    link.unlink()
            relative = os.path.relpath(target, link.parent)
            os.symlink(relative, link)
            return True
        except OSError:
            return False
