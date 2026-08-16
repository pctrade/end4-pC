#!/usr/bin/env python3

"""Read native Claude Code, Antigravity, z.ai/ZCode, and Kimi Code usage sources.

The QML services call this helper for providers that do not expose a stable
stdio API. It deliberately emits one small JSON object and never logs the
credentials or terminal output used to obtain it.
"""

from __future__ import annotations

import json
import os
import platform
import pty
import re
import select
import signal
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
from urllib.parse import urlparse, urlunparse
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


def request_json(
    url: str,
    headers: dict[str, str],
    timeout: float = 8,
) -> tuple[int, Optional[dict[str, Any]]]:
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
        return response.status, payload if isinstance(payload, dict) else None
    except urllib.error.HTTPError as error:
        return error.code, None
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
    elif provider == "zai":
        fetch_zai()
    elif provider == "kimi":
        fetch_kimi()
    else:
        emit(provider or "unknown", error="Unknown usage provider")


if __name__ == "__main__":
    main()
