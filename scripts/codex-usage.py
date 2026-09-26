#!/usr/bin/env python3

"""Read Codex account usage without starting or attaching to an app-server."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Optional

from usage_process import provider_is_running


def emit(
    remaining_percent: Optional[float] = None,
    plan_type: str = "",
    error: str = "",
    windows: Optional[list[dict[str, Any]]] = None,
) -> None:
    normalized = windows or []
    value = (
        min(window["remainingPercent"] for window in normalized)
        if normalized
        else (-1 if remaining_percent is None else max(0, min(100, round(remaining_percent))))
    )
    print(json.dumps({
        "provider": "codex",
        "remainingPercent": value,
        "resetAt": min(
            (window["resetAt"] for window in normalized if window.get("resetAt", 0) > 0),
            default=0,
        ),
        "planType": plan_type,
        "error": error,
        "windows": normalized,
    }, separators=(",", ":")), flush=True)


def number(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def usage_window_label(minutes: int) -> str:
    if minutes >= 7 * 24 * 60:
        return "Weekly"
    if minutes == 5 * 60:
        return "5h"
    if minutes % (24 * 60) == 0:
        return f"{minutes // (24 * 60)}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"


def usage_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    rate_limit = payload.get("rate_limit")
    if not isinstance(rate_limit, dict):
        return []

    windows: list[dict[str, Any]] = []
    for key in ("primary_window", "secondary_window"):
        window = rate_limit.get(key)
        if not isinstance(window, dict):
            continue
        used = number(window.get("used_percent"))
        duration_seconds = number(window.get("limit_window_seconds"))
        if used is None or duration_seconds is None or duration_seconds <= 0:
            continue
        duration_minutes = max(1, round(duration_seconds / 60))
        reset_at = number(window.get("reset_at")) or 0
        remaining = max(0, min(100, 100 - used))
        windows.append({
            "id": "weekly" if duration_minutes >= 7 * 24 * 60 else key,
            "label": usage_window_label(duration_minutes),
            "remainingPercent": round(remaining),
            "resetAt": reset_at,
            "windowDurationMins": duration_minutes,
        })
    return windows


def fetch_usage() -> None:
    if not provider_is_running("codex"):
        emit(error="Codex is not running")
        return

    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
    try:
        auth = json.loads((codex_home / "auth.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        emit(error="Codex ChatGPT credentials unavailable")
        return

    tokens = auth.get("tokens") if isinstance(auth, dict) else None
    access_token = tokens.get("access_token") if isinstance(tokens, dict) else None
    account_id = tokens.get("account_id") if isinstance(tokens, dict) else None
    if not isinstance(access_token, str) or not access_token.strip():
        emit(error="Codex ChatGPT credentials unavailable")
        return

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
        "OAI-Product-Sku": "codex",
        "User-Agent": "quickshell-usage-widget",
    }
    if isinstance(account_id, str) and account_id.strip():
        headers["ChatGPT-Account-Id"] = account_id

    endpoint = os.environ.get(
        "CODEX_USAGE_URL",
        "https://chatgpt.com/backend-api/wham/usage",
    ).strip()
    request = urllib.request.Request(endpoint, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            emit(error="Codex ChatGPT credentials rejected")
        else:
            emit(error=f"Codex usage endpoint returned HTTP {error.code}")
        return
    except (OSError, ValueError):
        emit(error="Codex usage unavailable")
        return

    if not isinstance(payload, dict):
        emit(error="Codex usage response was invalid")
        return
    windows = usage_windows(payload)
    if not windows:
        emit(error="Codex response had no rate limit")
        return
    emit(
        plan_type=str(payload.get("plan_type") or ""),
        windows=windows,
    )


if __name__ == "__main__":
    fetch_usage()
