#!/usr/bin/env python3
"""Read the most recently reported Codex account limits from local sessions."""
import json
import os
from pathlib import Path


def read_usage(home):
    latest = None
    # Limits are account-wide. Compare report timestamps across sessions; file
    # modification times also change for events that contain no usage report.
    paths = sorted((home / "sessions").glob("**/*.jsonl"),
                   key=lambda path: path.stat().st_mtime, reverse=True)
    for path in paths:
        try:
            with path.open(errors="replace") as stream:
                for line in stream:
                    try:
                        event = json.loads(line)
                        payload = event.get("payload", {})
                        limits = payload.get("rate_limits")
                        if (event.get("type") != "event_msg"
                                or payload.get("type") != "token_count"
                                or not isinstance(limits, dict)
                                or limits.get("limit_id") not in (None, "codex")
                                or not isinstance(limits.get("primary"), dict)):
                            continue
                        timestamp = event.get("timestamp", "")
                        if latest is None or timestamp > latest[0]:
                            latest = (timestamp, limits)
                    except (ValueError, TypeError, AttributeError):
                        continue
        except OSError:
            continue
    if latest is None:
        return {"available": False}
    limits = latest[1]
    primary = limits["primary"]
    secondary = limits.get("secondary") or {}
    return {"available": True, "percentage": primary.get("used_percent", 0) / 100,
            "resetsAt": primary.get("resets_at", 0),
            "weeklyPercentage": secondary.get("used_percent", 0) / 100,
            "weeklyResetsAt": secondary.get("resets_at", 0)}


if __name__ == "__main__":
    home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    print(json.dumps(read_usage(home)))
