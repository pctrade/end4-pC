#!/usr/bin/env python3

"""Read native Codex, Claude Code, and Antigravity-adjacent usage sources.

The QML services call this helper for providers that do not expose a stable
stdio API. It deliberately emits one small JSON object and never logs the
credentials or terminal output used to obtain it.
"""

from __future__ import annotations

import json
import os
import pty
import re
import select
import signal
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Optional


def emit(
    provider: str,
    remaining_percent: Optional[float] = None,
    reset_at: Optional[float] = None,
    plan_type: str = "",
    error: str = "",
    windows: Optional[Iterable[dict[str, Any]]] = None,
) -> None:
    normalized_windows: list[dict[str, Any]] = []
    if windows is not None:
        for window in windows:
            if not isinstance(window, dict):
                continue
            window_remaining = number(window.get("remainingPercent"))
            if window_remaining is None:
                continue
            window_reset = timestamp(window.get("resetAt")) or 0
            normalized_windows.append({
                "id": str(window.get("id") or "usage"),
                "label": str(window.get("label") or "Usage"),
                "remainingPercent": max(0, min(100, round(window_remaining))),
                "resetAt": window_reset,
            })

    if normalized_windows:
        value = min(window["remainingPercent"] for window in normalized_windows)
        reset_at = reset_at or min(
            (window["resetAt"] for window in normalized_windows if window["resetAt"] > 0),
            default=0,
        )
    else:
        value = -1 if remaining_percent is None else max(0, min(100, round(remaining_percent)))

    print(
        json.dumps(
            {
                "provider": provider,
                "remainingPercent": value,
                "resetAt": reset_at or 0,
                "planType": plan_type,
                "error": error,
                "windows": normalized_windows,
            },
            separators=(",", ":"),
        ),
        flush=True,
    )


def number(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def timestamp(value: Any) -> Optional[float]:
    numeric = number(value)
    if numeric is not None:
        # Antigravity commonly returns epoch seconds; some web payloads use ms.
        return numeric / 1000 if numeric > 10_000_000_000 else numeric

    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.timestamp()
    except ValueError:
        return None


def fetch_json(url: str, headers: dict[str, str], timeout: float = 8) -> Optional[dict[str, Any]]:
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
        return payload if isinstance(payload, dict) else None
    except (OSError, ValueError, urllib.error.HTTPError):
        return None


def native_claude_credentials() -> tuple[Optional[str], str]:
    config_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude"))).expanduser()
    candidates = [config_dir / ".credentials.json"]
    fallback = Path.home() / ".claude" / ".credentials.json"
    if fallback not in candidates:
        candidates.append(fallback)

    for path in candidates:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        oauth = payload.get("claudeAiOauth") if isinstance(payload, dict) else None
        if not isinstance(oauth, dict):
            continue
        token = oauth.get("accessToken")
        if isinstance(token, str) and token.strip():
            plan = oauth.get("subscriptionType") or oauth.get("rateLimitTier") or ""
            return token.strip(), str(plan)

    # This is the native Claude Code handoff intended for scripted integrations.
    token = os.environ.get("CLAUDE_CODE_OAUTH_TOKEN", "").strip()
    return (token or None), ""


def fetch_claude() -> None:
    token, plan = native_claude_credentials()
    if not token:
        emit("claude", error="Native Claude OAuth credentials unavailable")
        return

    payload = fetch_json(
        "https://api.anthropic.com/api/oauth/usage",
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "quickshell-usage-widget",
        },
    )
    if not payload:
        emit("claude", error="Native Claude usage unavailable")
        return

    def make_window(key: str, label: str, window: Any) -> Optional[dict[str, Any]]:
        if not isinstance(window, dict):
            return None
        used = number(window.get("utilization"))
        if used is None:
            return None
        return {
            "id": key,
            "label": label,
            "remainingPercent": 100 - used,
            "resetAt": timestamp(window.get("resets_at")) or 0,
        }

    native_windows: list[dict[str, Any]] = []
    five_hour = make_window("five_hour", "5h", payload.get("five_hour"))
    if five_hour:
        native_windows.append(five_hour)

    # Prefer the aggregate weekly window. The scoped model windows are only a
    # compatibility fallback for older/native responses without seven_day.
    weekly_candidates: Iterable[tuple[str, Any]] = (
        ("seven_day", payload.get("seven_day")),
        ("seven_day_oauth_apps", payload.get("seven_day_oauth_apps")),
        ("seven_day_sonnet", payload.get("seven_day_sonnet")),
        ("seven_day_opus", payload.get("seven_day_opus")),
    )
    for key, window in weekly_candidates:
        weekly = make_window("weekly" if key == "seven_day" else key, "Weekly", window)
        if weekly:
            native_windows.append(weekly)
            break

    if not native_windows:
        emit("claude", plan_type=plan, error="Native Claude usage response had no limit")
        return

    # Anthropic reports utilization as a percentage used; this widget shows
    # the percentage remaining, matching the Codex widget.
    emit("claude", plan_type=plan, windows=native_windows)


def listening_ports(pid: int) -> list[int]:
    try:
        result = subprocess.run(
            ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return []
    return sorted({int(port) for port in re.findall(r":(\d+) \(LISTEN\)", result.stdout)})


def drain_pty(master: int, seconds: float = 0.15) -> bytes:
    output = bytearray()
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            ready, _, _ = select.select([master], [], [], 0.05)
        except (OSError, ValueError):
            break
        if not ready:
            continue
        try:
            chunk = os.read(master, 8192)
        except OSError:
            break
        if not chunk:
            break
        output.extend(chunk)
    return bytes(output)


def is_auth_prompt(output: bytes) -> bool:
    text = output.decode("utf-8", "replace")
    return bool(re.search(r"select\s+login\s+method|enter\s+login", text, re.IGNORECASE))


def antigravity_binary() -> Optional[str]:
    configured = os.environ.get("ANTIGRAVITY_CLI_PATH", "").strip()
    if configured:
        return configured
    for candidate in ("agy", str(Path.home() / ".local/bin/agy"), "/usr/local/bin/agy"):
        if os.path.isabs(candidate):
            if os.access(candidate, os.X_OK):
                return candidate
        else:
            found = next((path for path in os.environ.get("PATH", "").split(os.pathsep)
                          if os.access(os.path.join(path, candidate), os.X_OK)), None)
            if found:
                return os.path.join(found, candidate)
    return None


def local_request(port: int, scheme: str, path: str, body: bytes) -> Optional[dict[str, Any]]:
    request = urllib.request.Request(
        f"{scheme}://127.0.0.1:{port}{path}",
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Connect-Protocol-Version": "1",
        },
    )
    context = ssl._create_unverified_context() if scheme == "https" else None
    try:
        with urllib.request.urlopen(request, context=context, timeout=2.5) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
        return payload if isinstance(payload, dict) else None
    except (OSError, ValueError, urllib.error.HTTPError):
        return None


def quota_summary_value(payload: dict[str, Any]) -> Optional[tuple[float, Optional[float]]]:
    root = payload.get("response") or payload.get("summary") or payload
    if not isinstance(root, dict):
        return None
    values: list[float] = []
    resets: list[float] = []
    for group in root.get("groups", []) or []:
        if not isinstance(group, dict):
            continue
        for bucket in group.get("buckets", []) or []:
            if not isinstance(bucket, dict) or bucket.get("disabled") is True:
                continue
            remaining = bucket.get("remaining")
            fraction = bucket.get("remainingFraction")
            if isinstance(remaining, dict):
                fraction = remaining.get("remainingFraction", fraction)
            fraction = number(fraction)
            if fraction is None:
                continue
            values.append(max(0, min(1, fraction)))
            reset = timestamp(bucket.get("resetTime"))
            if reset:
                resets.append(reset)
    if not values:
        return None
    return min(values) * 100, (min(resets) if resets else None)


def quota_summary_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    root = payload.get("response") or payload.get("summary") or payload
    if not isinstance(root, dict):
        return []

    buckets_by_window: dict[str, dict[str, Any]] = {
        "five_hour": {"id": "five_hour", "label": "5h", "values": [], "resets": []},
        "weekly": {"id": "weekly", "label": "Weekly", "values": [], "resets": []},
    }

    for group in root.get("groups", []) or []:
        if not isinstance(group, dict):
            continue
        for bucket in group.get("buckets", []) or []:
            if not isinstance(bucket, dict) or bucket.get("disabled") is True:
                continue

            raw_names = [bucket.get("bucketId"), bucket.get("displayName")]
            names = {
                re.sub(r"[_ ]+", "-", str(name).strip().lower())
                for name in raw_names
                if name
            }
            cadence = None
            if any(
                re.search(r"(?:^|[- ])(?:5h|5-hour|five-hour|session)(?:$|[- ])", name)
                for name in names
            ):
                cadence = "five_hour"
            elif any("weekly" in name for name in names):
                cadence = "weekly"
            if cadence is None:
                continue

            fraction = bucket.get("remainingFraction")
            remaining = bucket.get("remaining")
            if isinstance(remaining, dict):
                fraction = remaining.get("remainingFraction", fraction)
            fraction = number(fraction)
            if fraction is None:
                continue

            bucket_data = buckets_by_window[cadence]
            bucket_data["values"].append(max(0, min(1, fraction)) * 100)
            reset = timestamp(bucket.get("resetTime"))
            if reset:
                bucket_data["resets"].append(reset)

    windows = []
    for key in ("five_hour", "weekly"):
        bucket_data = buckets_by_window[key]
        if not bucket_data["values"]:
            continue
        windows.append({
            "id": bucket_data["id"],
            "label": bucket_data["label"],
            "remainingPercent": min(bucket_data["values"]),
            "resetAt": min(bucket_data["resets"]) if bucket_data["resets"] else 0,
        })
    return windows


def user_status_value(payload: dict[str, Any]) -> Optional[tuple[float, Optional[float], str]]:
    user = payload.get("userStatus")
    if not isinstance(user, dict):
        return None
    cascade = user.get("cascadeModelConfigData")
    configs = cascade.get("clientModelConfigs") if isinstance(cascade, dict) else None
    if not isinstance(configs, list):
        return None

    values: list[float] = []
    resets: list[float] = []
    hidden_words = ("autocomplete", "image", "embedding", "lite", "internal")
    for config in configs:
        if not isinstance(config, dict):
            continue
        label = str(config.get("label") or "").lower()
        if any(word in label for word in hidden_words):
            continue
        quota = config.get("quotaInfo")
        if not isinstance(quota, dict):
            continue
        fraction = number(quota.get("remainingFraction"))
        if fraction is None:
            continue
        values.append(max(0, min(1, fraction)))
        reset = timestamp(quota.get("resetTime"))
        if reset:
            resets.append(reset)

    if not values:
        return None
    tier = user.get("userTier")
    plan = tier.get("name") if isinstance(tier, dict) else None
    if not plan:
        plan_status = user.get("planStatus")
        plan_info = plan_status.get("planInfo") if isinstance(plan_status, dict) else None
        plan = plan_info.get("preferredName") if isinstance(plan_info, dict) else ""
    return min(values) * 100, (min(resets) if resets else None), str(plan or "")


def fetch_antigravity() -> None:
    binary = antigravity_binary()
    if not binary:
        emit("antigravity", error="Antigravity CLI unavailable")
        return

    master = slave = None
    process = None
    try:
        master, slave = pty.openpty()
        process = subprocess.Popen(
            [binary],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
            close_fds=True,
        )
        os.close(slave)
        slave = None
        body = json.dumps({
            "ideName": "antigravity",
            "extensionName": "antigravity",
            "locale": "en",
            "ideVersion": "unknown",
        }).encode()
        summary_path = "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        status_path = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
        deadline = time.monotonic() + 30
        last_probe = 0.0
        recent_output = bytearray()

        while time.monotonic() < deadline and process.poll() is None:
            recent_output.extend(drain_pty(master, 0.2))
            if is_auth_prompt(bytes(recent_output[-4096:])):
                emit("antigravity", error="Antigravity login required")
                return

            now = time.monotonic()
            if now - last_probe < 1.5:
                continue
            last_probe = now
            ports = listening_ports(process.pid)
            for port in ports:
                for scheme in ("https", "http"):
                    summary = local_request(port, scheme, summary_path, body)
                    parsed_windows = quota_summary_windows(summary) if summary else []
                    if parsed_windows:
                        emit("antigravity", windows=parsed_windows)
                        return

                    parsed_summary = quota_summary_value(summary) if summary else None
                    if parsed_summary:
                        emit("antigravity", parsed_summary[0], parsed_summary[1])
                        return
                    status = local_request(port, scheme, status_path, body)
                    parsed_status = user_status_value(status) if status else None
                    if parsed_status:
                        emit("antigravity", parsed_status[0], parsed_status[1], parsed_status[2])
                        return
    except (OSError, subprocess.SubprocessError):
        pass
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=3)
            except (OSError, subprocess.SubprocessError):
                try:
                    process.kill()
                except OSError:
                    pass
        for fd in (master, slave):
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass

    emit("antigravity", error="Antigravity usage unavailable")


def main() -> None:
    provider = sys.argv[1] if len(sys.argv) > 1 else ""
    if provider == "claude":
        fetch_claude()
    elif provider == "antigravity":
        fetch_antigravity()
    else:
        emit(provider or "unknown", error="Unknown usage provider")


if __name__ == "__main__":
    main()
