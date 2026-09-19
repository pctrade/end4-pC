#!/usr/bin/env python3

"""Read native Claude Code, Antigravity, z.ai/ZCode, Kimi Code, and Cursor usage.

The QML services call this helper for providers that do not expose a stable
stdio API. It deliberately emits one small JSON object, never starts a
provider process or Cursor server, and never logs credentials or terminal output.
"""

from __future__ import annotations

import json
import os
import platform
import re
import socket
import sqlite3
import ssl
import sys
import time
import base64
import urllib.error
from urllib.parse import urlparse, urlunparse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Optional

from usage_process import antigravity_process_kind, provider_is_running, provider_processes


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


def request_json(
    url: str,
    headers: dict[str, str],
    timeout: float = 8,
    method: str = "GET",
    body: Optional[bytes] = None,
) -> tuple[int, Optional[dict[str, Any]]]:
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
        return response.status, payload if isinstance(payload, dict) else None
    except urllib.error.HTTPError as error:
        try:
            payload = json.loads(error.read().decode("utf-8", "replace"))
        except (OSError, ValueError):
            payload = None
        return error.code, payload if isinstance(payload, dict) else None
    except (OSError, ValueError):
        return 0, None


def fetch_json(url: str, headers: dict[str, str], timeout: float = 8) -> Optional[dict[str, Any]]:
    _, payload = request_json(url, headers, timeout)
    return payload


def read_json_file(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return payload if isinstance(payload, dict) else {}


def clean_string(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    value = value.strip()
    return value or None


def first_string(*values: Any) -> Optional[str]:
    for value in values:
        cleaned = clean_string(value)
        if cleaned:
            return cleaned
    return None


def https_endpoint(raw: str, path: str) -> Optional[str]:
    value = raw.strip()
    if not value:
        return None
    if "://" not in value:
        value = f"https://{value}"
    parsed = urlparse(value)
    if parsed.scheme.lower() != "https" or not parsed.netloc or parsed.username or parsed.password:
        return None
    endpoint_path = parsed.path.rstrip("/")
    if not endpoint_path or endpoint_path == "/":
        endpoint_path = path
    return urlunparse(parsed._replace(path=endpoint_path))


def https_origin(raw: str) -> Optional[str]:
    value = raw.strip()
    if not value:
        return None
    if "://" not in value:
        value = f"https://{value}"
    parsed = urlparse(value)
    if parsed.scheme.lower() != "https" or not parsed.netloc or parsed.username or parsed.password:
        return None
    return urlunparse(parsed._replace(path="", params="", query="", fragment=""))


def zcode_home() -> Path:
    return Path(os.environ.get("ZCODE_HOME", str(Path.home() / ".zcode"))).expanduser()


def z_ai_candidate_credentials() -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()

    def add(token: Any, base: Any) -> None:
        cleaned_token = clean_string(token)
        cleaned_base = clean_string(base)
        if not cleaned_token or cleaned_token.startswith("enc:v1:"):
            return
        origin = https_origin(cleaned_base or "https://api.z.ai")
        if not origin:
            return
        key = (cleaned_token, origin)
        if key in seen:
            return
        seen.add(key)
        candidates.append(key)

    configured_host = clean_string(os.environ.get("Z_AI_API_HOST"))
    add(os.environ.get("Z_AI_API_KEY"), configured_host or "https://api.z.ai")
    add(os.environ.get("ZAI_API_KEY"), configured_host or "https://api.z.ai")
    for key in ("BIGMODEL_API_KEY", "ZHIPU_API_KEY", "ZHIPUAI_API_KEY", "GLM_API_KEY"):
        add(os.environ.get(key), configured_host or "https://open.bigmodel.cn")

    config = read_json_file(zcode_home() / "v2" / "config.json")
    providers = config.get("provider")
    if isinstance(providers, dict):
        provider_items = sorted(
            providers.items(),
            key=lambda item: (
                0 if "coding-plan" in str(item[0]).lower() else
                1 if "start-plan" in str(item[0]).lower() else 2,
                str(item[0]),
            ),
        )
        for provider_id, provider in provider_items:
            if not isinstance(provider, dict):
                continue
            normalized_id = str(provider_id).lower()
            if "zai" not in normalized_id and "bigmodel" not in normalized_id:
                continue
            options = provider.get("options")
            if not isinstance(options, dict):
                continue
            default_host = "https://open.bigmodel.cn" if "bigmodel" in normalized_id else "https://api.z.ai"
            add(options.get("apiKey"), options.get("baseURL") or default_host)

    credentials = read_json_file(zcode_home() / "v2" / "credentials.json")
    # ZCode may encrypt this OAuth value at rest. The encrypted form is not an
    # API credential that this small read-only helper can safely reuse.
    add(credentials.get("oauth:zai:access_token"), configured_host or "https://api.z.ai")
    return candidates


def z_ai_quota_url(base: str) -> Optional[str]:
    quota_path = "/api/monitor/usage/quota/limit"
    override = clean_string(os.environ.get("Z_AI_QUOTA_URL"))
    if override:
        return https_endpoint(override, quota_path)

    host_override = clean_string(os.environ.get("Z_AI_API_HOST"))
    return https_endpoint(https_origin(host_override or base) or "", quota_path)


def zai_duration_minutes(unit: Any, amount: Any) -> Optional[int]:
    unit_number = number(unit)
    unit_text = str(unit).strip().lower() if unit is not None else ""
    multipliers = {
        "minute": 1,
        "minutes": 1,
        "min": 1,
        "hour": 60,
        "hours": 60,
        "hr": 60,
        "day": 24 * 60,
        "days": 24 * 60,
        "week": 7 * 24 * 60,
        "weeks": 7 * 24 * 60,
        "month": 30 * 24 * 60,
        "months": 30 * 24 * 60,
    }
    if unit_number is not None:
        numeric_units = {
            1: 24 * 60,
            3: 60,
            5: 30 * 24 * 60,
            6: 7 * 24 * 60,
        }
        multiplier = numeric_units.get(int(unit_number))
    else:
        multiplier = multipliers.get(unit_text)
    amount_number = number(amount)
    if multiplier is None or amount_number is None or amount_number <= 0:
        return None
    return max(1, round(multiplier * amount_number))


def usage_window_label(minutes: Optional[int], fallback: str = "Usage") -> str:
    if minutes == 5 * 60:
        return "5h"
    if minutes is not None and minutes >= 7 * 24 * 60:
        return "Weekly"
    if minutes is None or minutes <= 0:
        return fallback
    if minutes % (7 * 24 * 60) == 0:
        return f"{minutes // (7 * 24 * 60)}w"
    if minutes % (24 * 60) == 0:
        return f"{minutes // (24 * 60)}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"


def zai_remaining_percent(limit: dict[str, Any]) -> Optional[float]:
    total_number = number(limit.get("usage"))
    if total_number is None:
        total_number = number(limit.get("limit"))
    if total_number is None:
        total_number = number(limit.get("total"))
    current = number(limit.get("currentValue"))
    remaining = number(limit.get("remaining"))
    if total_number is not None and total_number > 0:
        if remaining is not None:
            return max(0, min(100, remaining / total_number * 100))
        if current is not None:
            return max(0, min(100, 100 - current / total_number * 100))

    # `percentage` is the used percentage in the z.ai response.
    used_percent = number(limit.get("percentage"))
    if used_percent is not None:
        return max(0, min(100, 100 - used_percent))
    return None


def zai_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    data = payload.get("data")
    if not isinstance(data, dict):
        return []
    limits = data.get("limits")
    if not isinstance(limits, list):
        return []

    token_by_duration: dict[int, dict[str, Any]] = {}
    token_without_duration: list[dict[str, Any]] = []
    time_limits: list[dict[str, Any]] = []
    for index, limit in enumerate(limits):
        if not isinstance(limit, dict):
            continue
        limit_type = str(limit.get("type") or "").upper()
        if limit_type not in ("TOKENS_LIMIT", "CREDIT_LIMIT", "TIME_LIMIT"):
            continue
        remaining = zai_remaining_percent(limit)
        if remaining is None:
            continue
        minutes = zai_duration_minutes(limit.get("unit"), limit.get("number"))
        item = {
            "id": f"zai_{limit_type.lower()}_{index}",
            "label": "MCP" if limit_type == "TIME_LIMIT" else usage_window_label(minutes, "Usage"),
            "remainingPercent": remaining,
            "resetAt": timestamp(limit.get("nextResetTime")),
            "minutes": minutes,
        }
        if limit_type == "TIME_LIMIT":
            time_limits.append(item)
        elif minutes is None:
            token_without_duration.append(item)
        else:
            previous = token_by_duration.get(minutes)
            if previous is None or item["remainingPercent"] < previous["remainingPercent"]:
                token_by_duration[minutes] = item

    windows = [token_by_duration[key] for key in sorted(token_by_duration)]
    if len(windows) > 2:
        windows = [windows[0], windows[-1]]
    if not windows and token_without_duration:
        windows = token_without_duration[:1]
    if not windows and time_limits:
        # TIME_LIMIT is the separate MCP/search lane. Keep the label explicit
        # rather than presenting it as a coding-plan weekly window.
        windows = [time_limits[0]]

    for window in windows:
        window.pop("minutes", None)
    return windows


def fetch_zai() -> None:
    if not provider_is_running("zai"):
        emit("zai", error="z.ai Code is not running")
        return

    candidates = z_ai_candidate_credentials()
    if not candidates:
        emit("zai", error="z.ai API credentials unavailable")
        return

    last_status = 0
    for token, base in candidates:
        url = z_ai_quota_url(base)
        if not url:
            continue
        status, payload = request_json(
            url,
            {
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
                "User-Agent": "quickshell-usage-widget",
            },
        )
        last_status = status
        if not payload:
            continue
        windows = zai_windows(payload)
        if not windows:
            continue
        data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
        plan = first_string(
            data.get("planName"),
            data.get("plan"),
            data.get("plan_type"),
            data.get("packageName"),
            data.get("level"),
        ) or ""
        emit("zai", plan_type=plan, windows=windows)
        return

    if last_status in (401, 403):
        emit("zai", error="z.ai credentials rejected")
    elif last_status == 0:
        emit("zai", error="z.ai usage unavailable")
    else:
        emit("zai", error="No active z.ai Coding Plan")


def kimi_home() -> Path:
    return Path(os.environ.get("KIMI_CODE_HOME", str(Path.home() / ".kimi-code"))).expanduser()


def kimi_native_credentials() -> tuple[Optional[str], str]:
    credentials = read_json_file(kimi_home() / "credentials" / "kimi-code.json")
    token = clean_string(credentials.get("access_token"))
    if not token:
        return None, "missing"
    expires_at = timestamp(credentials.get("expires_at"))
    if expires_at is None or expires_at <= time.time() + 60:
        return None, "expired"
    return token, "native"


def safe_header(value: Any, fallback: str = "unknown") -> str:
    text = str(value or "")
    ascii_text = "".join(character for character in text if 0x20 <= ord(character) <= 0x7E).strip()
    return ascii_text or fallback


def kimi_identity_headers() -> dict[str, str]:
    headers = {
        "User-Agent": "quickshell-usage-widget",
        "X-Msh-Platform": "kimi_code_cli",
        "X-Msh-Version": safe_header(os.environ.get("KIMI_CODE_VERSION")),
        "X-Msh-Device-Name": safe_header(socket.gethostname()),
        "X-Msh-Device-Model": safe_header(f"{platform.system()} {platform.machine()}"),
        "X-Msh-Os-Version": safe_header(platform.release()),
    }
    try:
        device_id = (kimi_home() / "device_id").read_text(encoding="utf-8").strip()
    except OSError:
        device_id = ""
    if device_id:
        headers["X-Msh-Device-Id"] = safe_header(device_id)
    return headers


def kimi_code_endpoint() -> Optional[str]:
    raw = clean_string(os.environ.get("KIMI_CODE_BASE_URL")) or "https://api.kimi.com"
    value = raw if "://" in raw else f"https://{raw}"
    parsed = urlparse(value)
    if parsed.scheme.lower() != "https" or not parsed.netloc or parsed.username or parsed.password:
        return None
    base_path = parsed.path.rstrip("/")
    if base_path.endswith("/coding/v1"):
        endpoint_path = f"{base_path}/usages"
    elif base_path.endswith("/coding"):
        endpoint_path = f"{base_path}/v1/usages"
    else:
        endpoint_path = f"{base_path}/coding/v1/usages" if base_path else "/coding/v1/usages"
    return urlunparse(parsed._replace(path=endpoint_path))


def kimi_duration_minutes(window: Any) -> Optional[int]:
    if not isinstance(window, dict):
        return None
    duration = number(window.get("duration"))
    unit = str(window.get("timeUnit") or window.get("unit") or "").lower()
    if duration is None or duration <= 0:
        return None
    if "minute" in unit or unit in ("m", "min"):
        multiplier = 1
    elif "hour" in unit or unit in ("h", "hr"):
        multiplier = 60
    elif "day" in unit or unit == "d":
        multiplier = 24 * 60
    elif "week" in unit or unit == "w":
        multiplier = 7 * 24 * 60
    else:
        return None
    return max(1, round(duration * multiplier))


def kimi_detail_window(detail: Any, window_id: str, label: str) -> Optional[dict[str, Any]]:
    if not isinstance(detail, dict):
        return None
    limit = number(detail.get("limit"))
    if limit is None or limit <= 0:
        return None
    remaining = number(detail.get("remaining"))
    used = number(detail.get("used"))
    if remaining is not None:
        remaining_percent = remaining / limit * 100
    elif used is not None:
        remaining_percent = 100 - used / limit * 100
    else:
        return None
    return {
        "id": window_id,
        "label": label,
        "remainingPercent": max(0, min(100, remaining_percent)),
        "resetAt": timestamp(first_string(
            detail.get("resetTime"),
            detail.get("resetAt"),
            detail.get("reset_time"),
            detail.get("reset_at"),
        )),
    }


def kimi_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    weekly_detail = payload.get("usage")
    rate_limits = payload.get("limits")
    if not isinstance(weekly_detail, dict):
        usages = payload.get("usages")
        coding_usage = next(
            (
                usage for usage in usages
                if isinstance(usage, dict) and usage.get("scope") == "FEATURE_CODING"
            ),
            None,
        ) if isinstance(usages, list) else None
        if isinstance(coding_usage, dict):
            weekly_detail = coding_usage.get("detail")
            rate_limits = coding_usage.get("limits")

    weekly = kimi_detail_window(weekly_detail, "weekly", "Weekly")
    candidates: list[tuple[int, int, dict[str, Any]]] = []
    if isinstance(rate_limits, list):
        for index, rate_limit in enumerate(rate_limits):
            if not isinstance(rate_limit, dict):
                continue
            minutes = kimi_duration_minutes(rate_limit.get("window"))
            detail = rate_limit.get("detail")
            if minutes is None:
                continue
            label = usage_window_label(minutes, "Rate limit")
            rate_window = kimi_detail_window(detail, "five_hour" if minutes == 5 * 60 else f"rate_{index}", label)
            if rate_window:
                candidates.append((minutes, index, rate_window))

    windows: list[dict[str, Any]] = []
    if candidates:
        candidates.sort(key=lambda item: (item[0], item[1]))
        windows.append(candidates[0][2])
    if weekly:
        windows.append(weekly)
    return windows


def fetch_kimi() -> None:
    if not provider_is_running("kimi"):
        emit("kimi", error="Kimi Code is not running")
        return

    api_key = clean_string(os.environ.get("KIMI_CODE_API_KEY"))
    token = api_key
    source = "api-key" if api_key else ""
    if not token:
        if clean_string(os.environ.get("KIMI_CODE_BASE_URL")):
            emit("kimi", error="Kimi Code API key required for a custom endpoint")
            return
        token, source = kimi_native_credentials()
    if not token:
        message = "Kimi Code credentials expired" if source == "expired" else "Kimi Code credentials unavailable"
        emit("kimi", error=message)
        return

    endpoint = kimi_code_endpoint()
    if not endpoint:
        emit("kimi", error="Kimi Code endpoint must use HTTPS")
        return
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if source == "native":
        headers.update(kimi_identity_headers())

    status, payload = request_json(endpoint, headers)
    if status in (401, 403):
        emit("kimi", error="Kimi Code credentials rejected")
        return
    if not payload:
        emit("kimi", error="Kimi Code usage unavailable")
        return
    windows = kimi_windows(payload)
    if not windows:
        emit("kimi", error="Kimi Code response had no usage limits")
        return
    usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
    plan = first_string(payload.get("plan"), payload.get("planName"), usage.get("planName")) or ""
    emit("kimi", plan_type=plan, windows=windows)


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
    if not provider_is_running("claude"):
        emit("claude", error="Claude Code is not running")
        return

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
    """Return TCP listening ports held by ``pid`` without external tools."""
    try:
        descriptors = list((Path("/proc") / str(pid) / "fd").iterdir())
    except OSError:
        return []

    socket_inodes: set[str] = set()
    for descriptor in descriptors:
        try:
            target = os.readlink(descriptor)
        except OSError:
            continue
        match = re.fullmatch(r"socket:\[(\d+)\]", target)
        if match:
            socket_inodes.add(match.group(1))

    ports: set[int] = set()
    for table in (Path("/proc/net/tcp"), Path("/proc/net/tcp6")):
        try:
            lines = table.read_text(encoding="utf-8").splitlines()[1:]
        except OSError:
            continue

        for line in lines:
            fields = line.split()
            if len(fields) < 10 or fields[3] != "0A" or fields[9] not in socket_inodes:
                continue
            try:
                port = int(fields[1].rsplit(":", 1)[1], 16)
            except (IndexError, ValueError):
                continue
            ports.add(port)
    return sorted(ports)


def local_request(
    port: int,
    scheme: str,
    path: str,
    body: bytes,
    extra_headers: Optional[dict[str, str]] = None,
) -> Optional[dict[str, Any]]:
    headers = {
        "Content-Type": "application/json",
        "Connect-Protocol-Version": "1",
    }
    if extra_headers:
        headers.update(extra_headers)
    request = urllib.request.Request(
        f"{scheme}://127.0.0.1:{port}{path}",
        data=body,
        method="POST",
        headers=headers,
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


def antigravity_model_configs(payload: dict[str, Any]) -> list[dict[str, Any]]:
    roots: list[dict[str, Any]] = [payload]
    for key in ("response", "userStatus", "cascadeModelConfigData"):
        value = payload.get(key)
        if isinstance(value, dict):
            roots.append(value)
            nested = value.get("cascadeModelConfigData")
            if isinstance(nested, dict):
                roots.append(nested)

    for root in roots:
        configs = root.get("clientModelConfigs")
        if isinstance(configs, list):
            return [config for config in configs if isinstance(config, dict)]
    return []


def model_configs_value(payload: dict[str, Any]) -> Optional[tuple[float, Optional[float], str]]:
    configs = antigravity_model_configs(payload)
    if not configs:
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
    user = payload.get("userStatus")
    if not isinstance(user, dict):
        user = payload
    tier = user.get("userTier")
    plan = tier.get("name") if isinstance(tier, dict) else None
    if not plan:
        plan_status = user.get("planStatus")
        plan_info = plan_status.get("planInfo") if isinstance(plan_status, dict) else None
        plan = plan_info.get("preferredName") if isinstance(plan_info, dict) else ""
    return min(values) * 100, (min(resets) if resets else None), str(plan or "")


def option_value(arguments: list[str], *names: str) -> Optional[str]:
    for index, argument in enumerate(arguments):
        for name in names:
            if argument == name and index + 1 < len(arguments):
                return arguments[index + 1]
            prefix = f"{name}="
            if argument.startswith(prefix):
                return argument[len(prefix) :]
    return None


def option_port(arguments: list[str], *names: str) -> Optional[int]:
    value = option_value(arguments, *names)
    parsed = number(value)
    if parsed is None or not 1 <= parsed <= 65535:
        return None
    return int(parsed)


def fetch_antigravity() -> None:
    candidates = provider_processes("antigravity")
    if not candidates:
        emit("antigravity", error="Antigravity is not running")
        return

    body = json.dumps({
        "ideName": "antigravity",
        "extensionName": "antigravity",
        "locale": "en",
        "ideVersion": "unknown",
    }).encode()
    summary_path = "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
    status_path = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
    configs_path = "/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs"
    saw_local_process = False

    for candidate in candidates:
        pid = candidate.pid
        arguments = candidate.arguments
        kind = antigravity_process_kind(arguments, candidate.executable)
        if kind is None:
            continue
        csrf_token = option_value(arguments, "--csrf_token", "--csrf-token") or ""
        server_port = option_port(
            arguments,
            "--https_server_port",
            "--https-server-port",
            "--server_port",
            "--server-port",
        )
        extension_port = option_port(
            arguments,
            "--extension_server_port",
            "--extension-server-port",
        )
        extension_csrf = option_value(
            arguments,
            "--extension_server_csrf_token",
            "--extension-server-csrf-token",
        ) or csrf_token
        if kind != "cli" and not csrf_token and not extension_csrf:
            continue

        ports = []
        if server_port:
            ports.append((server_port, "https", csrf_token))
        ports.extend((port, "https", csrf_token) for port in listening_ports(pid))
        if extension_port:
            ports.append((extension_port, "http", extension_csrf))
        if not ports:
            continue
        saw_local_process = True

        seen_ports: set[tuple[int, str]] = set()
        for port, scheme, token in ports:
            key = (port, scheme)
            if key in seen_ports:
                continue
            seen_ports.add(key)
            headers = {"X-Codeium-Csrf-Token": token} if token else None

            if kind != "cli":
                # Desktop language servers require a CSRF-bearing connect
                # probe before their quota methods accept requests.
                unleash_path = "/exa.language_server_pb.LanguageServerService/GetUnleashData"
                if local_request(port, scheme, unleash_path, body, headers) is None:
                    continue

            summary = local_request(port, scheme, summary_path, body, headers)
            parsed_windows = quota_summary_windows(summary) if summary else []
            if parsed_windows:
                emit("antigravity", windows=parsed_windows)
                return

            parsed_summary = quota_summary_value(summary) if summary else None
            if parsed_summary:
                emit("antigravity", parsed_summary[0], parsed_summary[1])
                return

            status = local_request(port, scheme, status_path, body, headers)
            parsed_status = model_configs_value(status) if status else None
            if parsed_status:
                emit("antigravity", parsed_status[0], parsed_status[1], parsed_status[2])
                return

            configs = local_request(port, scheme, configs_path, body, headers)
            parsed_configs = model_configs_value(configs) if configs else None
            if parsed_configs:
                emit("antigravity", parsed_configs[0], parsed_configs[1], parsed_configs[2])
                return

    if saw_local_process:
        emit("antigravity", error="Antigravity usage endpoint unavailable")
    else:
        emit("antigravity", error="Antigravity local server unavailable")


CURSOR_API_BASE = "https://api2.cursor.sh"
CURSOR_OAUTH_CLIENT_ID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"


def cursor_state_db() -> Path:
    override = clean_string(os.environ.get("CURSOR_STATE_DB"))
    if override:
        return Path(override).expanduser()
    xdg = clean_string(os.environ.get("XDG_CONFIG_HOME"))
    config_home = Path(xdg).expanduser() if xdg else Path.home() / ".config"
    return config_home / "Cursor" / "User" / "globalStorage" / "state.vscdb"


def cursor_db_values(keys: Iterable[str]) -> dict[str, str]:
    path = cursor_state_db()
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    try:
        connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=1.5)
    except sqlite3.Error:
        return {}
    try:
        for key in keys:
            try:
                row = connection.execute(
                    "SELECT value FROM ItemTable WHERE key = ?",
                    (key,),
                ).fetchone()
            except sqlite3.Error:
                continue
            if not row or row[0] is None:
                continue
            raw = row[0]
            if isinstance(raw, bytes):
                text = raw.decode("utf-8", "replace")
            else:
                text = str(raw)
            text = text.strip()
            if text:
                values[key] = text
    finally:
        connection.close()
    return values


def cursor_jwt_expiring(token: str, skew_seconds: int = 60) -> bool:
    parts = token.split(".")
    if len(parts) < 2:
        return True
    payload = parts[1]
    padding = "=" * (-len(payload) % 4)
    try:
        decoded = base64.urlsafe_b64decode(payload + padding)
        data = json.loads(decoded.decode("utf-8", "replace"))
    except (OSError, ValueError):
        return True
    if not isinstance(data, dict):
        return True
    exp = number(data.get("exp"))
    if exp is None:
        return True
    return exp <= time.time() + skew_seconds


def cursor_refresh_access_token(refresh_token: str) -> Optional[str]:
    status, payload = request_json(
        f"{CURSOR_API_BASE}/oauth/token",
        {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "quickshell-usage-widget",
        },
        method="POST",
        body=json.dumps({
            "grant_type": "refresh_token",
            "client_id": CURSOR_OAUTH_CLIENT_ID,
            "refresh_token": refresh_token,
        }).encode(),
    )
    if status in (401, 403) or not payload:
        return None
    if payload.get("shouldLogout") is True:
        return None
    return clean_string(payload.get("access_token"))


def cursor_access_token() -> tuple[Optional[str], str]:
    auth = cursor_db_values((
        "cursorAuth/accessToken",
        "cursorAuth/refreshToken",
        "cursorAuth/stripeMembershipType",
    ))
    access = clean_string(auth.get("cursorAuth/accessToken"))
    refresh = clean_string(auth.get("cursorAuth/refreshToken"))
    plan = clean_string(auth.get("cursorAuth/stripeMembershipType")) or ""
    if access and not cursor_jwt_expiring(access):
        return access, plan
    if refresh:
        refreshed = cursor_refresh_access_token(refresh)
        if refreshed:
            return refreshed, plan
    if access:
        return access, plan
    return None, plan


def cursor_remaining_from_used(used: Any) -> Optional[float]:
    value = number(used)
    if value is None:
        return None
    # Cursor reports either 0-100 percentage used or 0-1 fractions.
    if 0 <= value <= 1:
        value *= 100
    return max(0, min(100, 100 - value))


def cursor_plan_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    plan_usage = payload.get("planUsage")
    if not isinstance(plan_usage, dict):
        plan_usage = {}
    reset_at = timestamp(
        first_string(
            payload.get("billingCycleEnd"),
            plan_usage.get("billingCycleEnd"),
            payload.get("billing_cycle_end"),
        )
    ) or 0

    windows: list[dict[str, Any]] = []
    auto = cursor_remaining_from_used(plan_usage.get("autoPercentUsed"))
    api = cursor_remaining_from_used(plan_usage.get("apiPercentUsed"))
    total = cursor_remaining_from_used(plan_usage.get("totalPercentUsed"))

    if auto is not None:
        windows.append({
            "id": "auto",
            "label": "Auto",
            "remainingPercent": auto,
            "resetAt": reset_at,
        })
    if api is not None:
        windows.append({
            "id": "api",
            "label": "API",
            "remainingPercent": api,
            "resetAt": reset_at,
        })
    if not windows and total is not None:
        windows.append({
            "id": "plan",
            "label": "Usage",
            "remainingPercent": total,
            "resetAt": reset_at,
        })

    if not windows:
        # Spend-based fallback when percentages are absent.
        limit = number(plan_usage.get("limit"))
        used_spend = number(plan_usage.get("totalSpend"))
        if used_spend is None:
            included = number(plan_usage.get("includedSpend")) or 0
            bonus = number(plan_usage.get("bonusSpend")) or 0
            used_spend = included + bonus
        if limit is not None and limit > 0 and used_spend is not None:
            remaining = max(0, min(100, 100 - used_spend / limit * 100))
            windows.append({
                "id": "plan",
                "label": "Usage",
                "remainingPercent": remaining,
                "resetAt": reset_at,
            })
    return windows


def cursor_auth_usage_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    # Enterprise-style request buckets from GET /auth/usage.
    start_of_month = timestamp(payload.get("startOfMonth")) or 0
    reset_at = 0
    if start_of_month > 0:
        # Approximate month-end reset from the cycle start.
        reset_at = start_of_month + 30 * 24 * 60 * 60

    preferred = ("gpt-4", "gpt-4o", "default", "composer")
    models = payload.get("gpt-4") if isinstance(payload.get("gpt-4"), dict) else None
    candidates: list[tuple[str, dict[str, Any]]] = []
    if isinstance(payload, dict):
        for key, value in payload.items():
            if isinstance(value, dict) and (
                "numRequests" in value or "maxRequestUsage" in value or "numRequestsTotal" in value
            ):
                candidates.append((str(key), value))

    chosen: Optional[dict[str, Any]] = None
    chosen_id = "usage"
    for key in preferred:
        match = next((item for item in candidates if item[0] == key), None)
        if match:
            chosen_id, chosen = match
            break
    if chosen is None and candidates:
        chosen_id, chosen = candidates[0]
    if chosen is None and models:
        chosen = models
        chosen_id = "gpt-4"
    if not isinstance(chosen, dict):
        return []

    used = number(chosen.get("numRequests"))
    if used is None:
        used = number(chosen.get("numRequestsTotal"))
    limit = number(chosen.get("maxRequestUsage"))
    if used is None or limit is None or limit <= 0:
        return []
    remaining = max(0, min(100, 100 - used / limit * 100))
    return [{
        "id": chosen_id,
        "label": "Usage",
        "remainingPercent": remaining,
        "resetAt": reset_at,
    }]


def fetch_cursor() -> None:
    if not provider_is_running("cursor"):
        emit("cursor", error="Cursor is not running")
        return

    token, plan = cursor_access_token()
    if not token:
        emit("cursor", error="Cursor credentials unavailable")
        return

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Connect-Protocol-Version": "1",
        "User-Agent": "quickshell-usage-widget",
    }
    status, payload = request_json(
        f"{CURSOR_API_BASE}/aiserver.v1.DashboardService/GetCurrentPeriodUsage",
        headers,
        method="POST",
        body=b"{}",
    )
    if status in (401, 403):
        # One retry after forcing a refresh when the on-disk JWT is stale.
        auth = cursor_db_values(("cursorAuth/refreshToken", "cursorAuth/stripeMembershipType"))
        refresh = clean_string(auth.get("cursorAuth/refreshToken"))
        plan = clean_string(auth.get("cursorAuth/stripeMembershipType")) or plan
        refreshed = cursor_refresh_access_token(refresh) if refresh else None
        if not refreshed:
            emit("cursor", plan_type=plan, error="Cursor credentials rejected")
            return
        headers["Authorization"] = f"Bearer {refreshed}"
        status, payload = request_json(
            f"{CURSOR_API_BASE}/aiserver.v1.DashboardService/GetCurrentPeriodUsage",
            headers,
            method="POST",
            body=b"{}",
        )

    windows: list[dict[str, Any]] = []
    if payload:
        windows = cursor_plan_windows(payload)

    if not windows:
        auth_status, auth_payload = request_json(
            f"{CURSOR_API_BASE}/auth/usage",
            {
                "Authorization": headers["Authorization"],
                "Accept": "application/json",
                "User-Agent": "quickshell-usage-widget",
            },
        )
        if auth_status in (401, 403):
            emit("cursor", plan_type=plan, error="Cursor credentials rejected")
            return
        if auth_payload:
            windows = cursor_auth_usage_windows(auth_payload)

    if not windows:
        if status == 0:
            emit("cursor", plan_type=plan, error="Cursor usage unavailable")
        else:
            emit("cursor", plan_type=plan, error="Cursor usage response had no limit")
        return

    emit("cursor", plan_type=plan, windows=windows)


def main() -> None:
    provider = sys.argv[1] if len(sys.argv) > 1 else ""
    if provider == "claude":
        fetch_claude()
    elif provider == "antigravity":
        fetch_antigravity()
    elif provider == "zai":
        fetch_zai()
    elif provider == "kimi":
        fetch_kimi()
    elif provider == "cursor":
        fetch_cursor()
    else:
        emit(provider or "unknown", error="Unknown usage provider")


if __name__ == "__main__":
    main()
