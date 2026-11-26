#!/usr/bin/env python3
"""Background generator for the icon theme manager.

Contract:
  - one instance at a time (flock on worker.lock),
  - debounce and take the latest request,
  - build in a staging directory and publish atomically,
  - never activate a theme unless the selection token is still current,
  - the manager performs the authoritative activation check under its own lock.

This file is intentionally dependency-free (stdlib only).
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import random
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from icon_theme_adapters import adapter_by_name, adapter_for  # noqa: E402
from icon_theme_adapters.base import (  # noqa: E402
    GENERATED_RE,
    AdapterError,
    find_theme,
    normalize_hex,
    read_json,
)

STAGING_PREFIX = ".gen-staging-"
INVALID_PREFIX = ".gen-invalid-"
MARKER = ".generated-by"
MANIFEST = ".icon-theme-meta.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def atomic_write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.tmp.{os.getpid()}.{random.randrange(1 << 30):x}")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def status_update(state_dir: Path, **fields) -> None:
    path = state_dir / "status.json"
    lock = state_dir / "status.lock"
    try:
        with (lock.open("a+") as handle):
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                current = read_json(path) or {"format": 1}
                current.update(fields)
                current["updatedAt"] = now_iso()
                atomic_write_json(path, current)
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    except OSError:
        return


def valid_manifest(theme_dir: Path, request: dict) -> bool:
    manifest = read_json(theme_dir / MANIFEST)
    if not manifest or manifest.get("generated") is not True or manifest.get("format") != 1:
        return False
    checks = (
        ("adapter", request.get("adapter")),
        ("adapterVersion", request.get("adapterVersion")),
        ("base", request.get("base")),
        ("basePath", request.get("basePath")),
        ("mode", request.get("mode")),
        ("accent", request.get("accent")),
    )
    return all(manifest.get(key) == value for key, value in checks)


def read_request(path: Path) -> dict | None:
    request = read_json(path)
    if not request or request.get("format") != 1:
        return None
    return request


def debounce_request(path: Path, initial: dict, debounce_ms: int) -> dict:
    """Wait for the burst to settle; return the latest request."""
    if debounce_ms <= 0:
        return initial
    request = initial
    for _ in range(10):
        time.sleep(debounce_ms / 1000.0)
        latest = read_request(path)
        if latest is None:
            latest = request
        if latest.get("id") == request.get("id"):
            return request
        request = latest
    return request


def validate_request(request: dict) -> str | None:
    required = (
        "id",
        "selectionId",
        "theme",
        "adapter",
        "base",
        "basePath",
        "mode",
        "accent",
        "out",
    )
    for key in required:
        if not request.get(key):
            return f"missing request field: {key}"
    if not GENERATED_RE.match(str(request["out"])):
        return f"invalid generated name: {request['out']}"
    if normalize_hex(str(request["accent"])) is None:
        return f"invalid accent: {request['accent']}"
    return None


def log(state_dir: Path, message: str) -> None:
    try:
        state_dir.mkdir(parents=True, exist_ok=True)
        with (state_dir / "worker.log").open("a", encoding="utf-8") as handle:
            handle.write(f"{now_iso()} {message}\n")
    except OSError:
        pass


def publish(staging: Path, final: Path, request: dict, manifest: dict) -> tuple[Path, dict, bool]:
    if final.is_symlink() or final.is_file():
        final.unlink()
        os.replace(staging, final)
        return final, manifest, True

    if final.is_dir():
        if valid_manifest(final, request):
            shutil.rmtree(staging, ignore_errors=True)
            return final, read_json(final / MANIFEST) or manifest, False
        trash = final.with_name(f"{INVALID_PREFIX}{os.getpid()}-{random.randrange(1 << 30):x}")
        os.replace(final, trash)
        try:
            os.replace(staging, final)
        finally:
            shutil.rmtree(trash, ignore_errors=True)
        return final, manifest, True

    os.replace(staging, final)
    return final, manifest, True


def build_theme(request: dict, icons_dir: Path) -> tuple[Path, dict, bool, object]:
    """Return (theme_dir, manifest, built, adapter)."""
    out = str(request["out"])
    accent = normalize_hex(str(request["accent"])) or "#5294e2"
    final = icons_dir / out

    if final.is_dir() and not final.is_symlink() and valid_manifest(final, request):
        return final, read_json(final / MANIFEST) or {}, False, None

    src = Path(str(request["basePath"]))
    src_check = find_theme(str(request["base"]))
    if src_check is None or src_check.resolve() != src.resolve():
        raise AdapterError(f"base theme changed or missing: {request['base']}")

    adapter = adapter_by_name(str(request["adapter"])) or adapter_for(str(request["theme"]), src)

    staging = icons_dir / f"{STAGING_PREFIX}{os.getpid()}-{random.randrange(1 << 30):x}"
    staging.mkdir(parents=True, exist_ok=False)
    (staging / MARKER).write_text("icon-theme-manager\n", encoding="utf-8")

    try:
        stats = adapter.recolor(src, staging, accent)
        manifest = {
            "format": 1,
            "generated": True,
            "adapter": adapter.info.name,
            "adapterVersion": adapter.info.version,
            "base": src.name,
            "basePath": str(src),
            "mode": str(request["mode"]),
            "accent": accent,
            "createdAt": now_iso(),
            "stats": stats.as_dict(),
        }
        atomic_write_json(staging / MANIFEST, manifest)
        final, manifest, built = publish(staging, final, request, manifest)
        return final, manifest, built, adapter
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def post_publish(adapter, theme_name: str, accent: str, icons_dir: Path, state_dir: Path) -> None:
    if adapter is None:
        return
    try:
        adapter.post_publish(theme_name, accent, icons_dir)
    except Exception as error:  # best effort, never abort publishing
        log(state_dir, f"post_publish failed: {error}")


def live_icon_theme() -> str:
    """Best-effort read of the icon theme currently applied to the desktop."""
    commands = (
        ["kreadconfig6", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme"],
        ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
    )
    for command in commands:
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        name = result.stdout.strip().strip("'")
        if name:
            return name
    return ""


def prune(icons_dir: Path, keep: int, active: str, pending: str, state_dir: Path) -> None:
    """Keep at most ``keep`` generated themes, counting active/pending.

    Active and pending themes are never deleted, even when ``keep`` is 0.
    The theme currently applied to the desktop is also protected: a cached
    activation can race a worker that is pruning an older generation.
    """
    if keep < 0:
        return
    root = icons_dir.resolve()
    protected = {name for name in (active, pending, live_icon_theme()) if name}
    candidates: list[tuple[str, str, Path]] = []
    for entry in icons_dir.iterdir():
        if entry.is_symlink() or not entry.is_dir():
            continue
        if not GENERATED_RE.match(entry.name):
            continue
        manifest = read_json(entry / MANIFEST)
        if not manifest or manifest.get("generated") is not True:
            continue
        candidates.append((str(manifest.get("createdAt") or ""), entry.name, entry))

    candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
    kept = 0
    for _, name, entry in candidates:
        if name in protected:
            kept += 1
            continue
        if kept < keep:
            kept += 1
            continue
        try:
            # Re-check immediately before deleting: the manager may have
            # activated a cached theme while this worker was building.
            current = read_json(state_dir / "status.json") or {}
            current_active = str(current.get("active") or "")
            if name in (current_active, live_icon_theme()):
                kept += 1
                continue
            resolved = entry.resolve()
            if resolved.parent != root:
                continue
            if entry.is_symlink() or not GENERATED_RE.match(entry.name):
                continue
            if entry.name in protected:
                continue
            shutil.rmtree(resolved, ignore_errors=True)
        except OSError:
            continue


def cleanup_staging(icons_dir: Path) -> None:
    cutoff = time.time() - 3600
    try:
        for entry in icons_dir.iterdir():
            staging = entry.name.startswith(STAGING_PREFIX)
            invalid = entry.name.startswith(INVALID_PREFIX)
            if not staging and not invalid:
                continue
            if staging and not (entry / MARKER).is_file():
                continue
            try:
                if entry.stat().st_mtime > cutoff:
                    continue
                shutil.rmtree(entry, ignore_errors=True)
            except OSError:
                continue
    except OSError:
        return


def activate(manager: Path, request: dict, state_dir: Path) -> int:
    try:
        result = subprocess.run(
            [
                "bash",
                str(manager),
                "--activate",
                str(request["out"]),
                "--request-id",
                str(request["id"]),
                "--selection-id",
                str(request["selectionId"]),
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        log(state_dir, f"activation failed to start: {error}")
        return 4
    if result.returncode != 0:
        log(state_dir, f"activation rejected ({result.returncode}): {result.stderr.strip()}")
    return result.returncode


def run_one(
    request_file: Path,
    state_dir: Path,
    icons_dir: Path,
    debounce_ms: int,
    manager: Path,
) -> tuple[int, str | None, dict | None]:
    request = read_request(request_file)
    if request is None:
        return 0, None, None

    request = debounce_request(request_file, request, debounce_ms)
    request_id = str(request.get("id") or "")

    if request.get("cancelled"):
        status_update(state_dir, state="idle", pending=None)
        return 2, request_id, request

    problem = validate_request(request)
    if problem:
        log(state_dir, problem)
        status_update(state_dir, state="error", lastError=problem, pending=None)
        return 4, request_id, request

    selection = read_json(state_dir / "selection.json") or {}
    if selection.get("selectionId") != request.get("selectionId"):
        return 2, request_id, request

    keep = int(request.get("keepGenerated") or 6)
    current = read_json(state_dir / "status.json") or {}
    current_active = str(current.get("active") or "")
    status_update(
        state_dir,
        state="generating",
        selectionId=request.get("selectionId"),
        base=request.get("base"),
        mode=request.get("mode"),
        accent=request.get("accent"),
        capability=request.get("capability"),
        pending={"id": request.get("id"), "out": request.get("out")},
        lastError=None,
    )

    try:
        final, manifest, built, adapter = build_theme(request, icons_dir)
    except (AdapterError, OSError, ValueError) as error:
        log(state_dir, f"generation failed: {error}")
        status_update(state_dir, state="error", lastError=str(error), pending=None)
        return 4, request_id, request

    out = str(request["out"])
    status_update(
        state_dir,
        state="publishing",
        generated=out,
        capability=request.get("capability"),
        lastError=None,
    )

    if built:
        post_publish(adapter, out, str(request["accent"]), icons_dir, state_dir)

    prune(icons_dir, keep, current_active, out, state_dir)

    status_update(
        state_dir,
        state="idle",
        generated=out,
        pending=None,
        lastError=None,
    )

    latest = read_json(state_dir / "selection.json") or {}
    if latest.get("selectionId") != request.get("selectionId"):
        log(state_dir, "selection changed during build; not activating")
        return 2, request_id, request

    rc = activate(manager, request, state_dir)
    if rc == 0:
        status_update(state_dir, state="idle", active=out, pending=None, lastError=None)
    else:
        status_update(state_dir, lastError="activation rejected", pending=None)
    return rc, request_id, request


def acquire_worker_lock(state_dir: Path, timeout: float = 300.0):
    lock_path = state_dir / "worker.lock"
    deadline = time.monotonic() + timeout
    while True:
        handle = lock_path.open("a+")
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return handle
        except OSError:
            handle.close()
            if time.monotonic() >= deadline:
                return None
            time.sleep(0.2)


def main() -> int:
    parser = argparse.ArgumentParser(description="Icon theme generation worker")
    parser.add_argument("--request-file", default="")
    parser.add_argument("--icons-dir", default="")
    parser.add_argument("--state-dir", default="")
    parser.add_argument("--debounce", type=int, default=1200)
    parser.add_argument("--manager", default=str(BASE_DIR / "icon-theme-manager.sh"))
    parser.add_argument("--once", action="store_true", help="accepted for tests")
    args = parser.parse_args()

    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    state_dir = Path(args.state_dir) if args.state_dir else state_home / "quickshell/user/generated/icons"
    icons_dir = Path(args.icons_dir) if args.icons_dir else data_home / "icons"
    request_file = Path(args.request_file) if args.request_file else state_dir / "request.json"

    state_dir.mkdir(parents=True, exist_ok=True)
    icons_dir.mkdir(parents=True, exist_ok=True)

    handle = acquire_worker_lock(state_dir)
    if handle is None:
        return 3

    try:
        processed: set[str] = set()
        last_rc = 0
        completed_request: dict | None = None
        last_done = read_json(state_dir / "last-processed.json") or {}

        while True:
            request = read_request(request_file)
            if request is None or str(request.get("id")) in processed:
                break
            # A queued worker may wake up after another worker already handled
            # this exact request.
            if last_done.get("id") and last_done.get("id") == request.get("id"):
                break

            last_rc, request_id, completed_request = run_one(
                request_file, state_dir, icons_dir, args.debounce, Path(args.manager)
            )
            if request_id:
                processed.add(request_id)

            # A newer request may have arrived while we were building. Process it
            # here instead of relying on another worker.
            latest = read_request(request_file)
            selection = read_json(state_dir / "selection.json") or {}
            if latest is None or str(latest.get("id")) in processed:
                break
            if latest.get("cancelled"):
                break
            if latest.get("selectionId") != selection.get("selectionId"):
                break
            if last_rc not in (0, 2):
                break
        return last_rc
    except Exception as error:  # never leave status stuck at "generating"
        log(state_dir, f"worker failed: {error}")
        status_update(state_dir, state="error", lastError=str(error), pending=None)
        return 4
    finally:
        if completed_request is not None:
            try:
                atomic_write_json(
                    state_dir / "last-processed.json",
                    {
                        "format": 1,
                        "id": completed_request.get("id"),
                        "selectionId": completed_request.get("selectionId"),
                        "completedAt": now_iso(),
                    },
                )
            except OSError:
                pass
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        finally:
            handle.close()


if __name__ == "__main__":
    raise SystemExit(main())
