#!/usr/bin/env python3
"""Perform one provider-process presence check without using the network."""

from __future__ import annotations

import json
import sys

from usage_process import provider_statuses


DEFAULT_PROVIDERS = ("codex", "claude", "kimi", "zai", "antigravity", "cursor")


def main() -> None:
    providers = tuple(dict.fromkeys(sys.argv[1:] or DEFAULT_PROVIDERS))
    print(json.dumps(provider_statuses(providers), separators=(",", ":")), flush=True)


if __name__ == "__main__":
    main()
