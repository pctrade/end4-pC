#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import sys
import time

CLIPHIST = "cliphist"


def decode(entry_id):
    result = subprocess.run([CLIPHIST, "decode", entry_id], capture_output=True, timeout=10)
    return result.stdout if result.returncode == 0 else None


def main():
    groups = json.loads(sys.argv[1])
    doomed = []
    for group in groups:
        seen = set()
        for entry_id in group:
            if not str(entry_id).isdigit():
                continue
            data = decode(str(entry_id))
            if data is None:
                continue
            digest = hashlib.sha256(data.strip()).hexdigest()
            if digest in seen:
                doomed.append(str(entry_id))
            else:
                seen.add(digest)
    if doomed:
        subprocess.run([CLIPHIST, "delete"], input=("\n".join(doomed) + "\n").encode(), timeout=20)
        log_path = os.path.expanduser("~/.cache/quickshell/clipboard-dedupe.log")
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} groups={groups} deleted={doomed}\n")
    print(len(doomed))


if __name__ == "__main__":
    main()
