#!/usr/bin/env python3
"""Watches the downloads folder and reports what is actually being downloaded.

Traffic is a bad proxy for "a download": a video playing pulls more megabytes than an installer. A browser
writing a partial file is not. This prints one JSON line per second describing the partial files in progress
and, when one finishes, the file it turned into.

The total size comes from the browser itself: Chromium keeps every download in its History database
(downloads.total_bytes), and Firefox keeps it in places.sqlite annotations. Both databases are locked while
the browser runs, so they are copied before being read.
"""

import json
import os
import shutil
import sqlite3
import sys
import tempfile
import time

PARTIAL_SUFFIXES = (".crdownload", ".part", ".partial", ".download", ".opdownload", ".!ut")
ARCHIVE_SUFFIXES = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".tar.zst", ".tar.bz2", ".7z", ".rar")
POLL_IDLE_SECONDS = 4.0      # nothing is being downloaded: just watch the folder
POLL_ACTIVE_SECONDS = 1.0    # something is arriving: follow it closely
TOTALS_REFRESH_SECONDS = 4.0

CHROMIUM_HISTORIES = [
    "~/.config/google-chrome/Default/History",
    "~/.config/google-chrome-beta/Default/History",
    "~/.config/chromium/Default/History",
    "~/.config/BraveSoftware/Brave-Browser/Default/History",
    "~/.config/microsoft-edge/Default/History",
]
FIREFOX_PROFILE_GLOBS = ["~/.mozilla/firefox", "~/.zen"]

def strip_partial(name):
    lowered = name.lower()
    for suffix in PARTIAL_SUFFIXES:
        if lowered.endswith(suffix):
            return name[: -len(suffix)]
    return name

def copy_db(path):
    """A browser holds its database open; read a snapshot instead of fighting for the lock."""
    try:
        handle, tmp = tempfile.mkstemp(prefix="island-db-", suffix=".sqlite")
        os.close(handle)
        shutil.copy2(path, tmp)
        for extra in ("-wal", "-shm"):
            if os.path.exists(path + extra):
                shutil.copy2(path + extra, tmp + extra)
        return tmp
    except OSError:
        return None

def chromium_totals():
    """{target_path: (total_bytes, received_bytes, state)} for downloads the browser knows about."""
    totals = {}
    for candidate in CHROMIUM_HISTORIES:
        path = os.path.expanduser(candidate)
        if not os.path.exists(path):
            continue
        tmp = copy_db(path)
        if not tmp:
            continue
        try:
            connection = sqlite3.connect(tmp)
            rows = connection.execute(
                "SELECT target_path, total_bytes, received_bytes, state FROM downloads"
                " ORDER BY start_time DESC LIMIT 200"
            ).fetchall()
            connection.close()
            for target, total, received, state in rows:
                if target and target not in totals:
                    totals[target] = (total or 0, received or 0, state)
        except sqlite3.Error:
            pass
        finally:
            for extra in ("", "-wal", "-shm"):
                try:
                    os.unlink(tmp + extra)
                except OSError:
                    pass
    return totals

def firefox_totals():
    """Firefox stores the expected size in a page annotation on the download's source URL."""
    totals = {}
    for root in FIREFOX_PROFILE_GLOBS:
        base = os.path.expanduser(root)
        if not os.path.isdir(base):
            continue
        for entry in os.listdir(base):
            places = os.path.join(base, entry, "places.sqlite")
            if not os.path.exists(places):
                continue
            tmp = copy_db(places)
            if not tmp:
                continue
            try:
                connection = sqlite3.connect(tmp)
                rows = connection.execute(
                    "SELECT content FROM moz_annos a JOIN moz_anno_attributes t ON a.anno_attribute_id = t.id"
                    " WHERE t.name = 'downloads/metaData' ORDER BY a.id DESC LIMIT 200"
                ).fetchall()
                connection.close()
                for (content,) in rows:
                    try:
                        meta = json.loads(content)
                    except (TypeError, ValueError):
                        continue
                    target = meta.get("targetPath") or meta.get("target")
                    total = meta.get("fileSize") or meta.get("totalBytes") or 0
                    if target and total and target not in totals:
                        totals[target] = (total, 0, None)
            except sqlite3.Error:
                pass
            finally:
                for extra in ("", "-wal", "-shm"):
                    try:
                        os.unlink(tmp + extra)
                    except OSError:
                        pass
    return totals

def scan(folders):
    partials = {}
    for folder in folders:
        try:
            entries = os.listdir(folder)
        except OSError:
            continue
        for name in entries:
            if not name.lower().endswith(PARTIAL_SUFFIXES):
                continue
            path = os.path.join(folder, name)
            try:
                stat = os.stat(path)
            except OSError:
                continue
            partials[path] = stat
    return partials

def is_archive(name):
    lowered = name.lower()
    return any(lowered.endswith(suffix) for suffix in ARCHIVE_SUFFIXES)

def checksum_file(final_path):
    """A .sha256 next to the download means it can be verified."""
    for suffix in (".sha256", ".sha256sum", ".SHA256"):
        candidate = final_path + suffix
        if os.path.exists(candidate):
            return candidate
    return None

def main():
    until_idle = "--until-idle" in sys.argv
    folders = [os.path.expanduser(p) for p in (a for a in sys.argv[1:] if a != "--until-idle")] or [os.path.expanduser("~/Downloads")]
    previous = {}
    previous_time = time.time()
    totals = {}
    totals_at = 0.0
    previous_fresh = True  # one report before leaving, so a finished download is announced

    while True:
        now = time.time()
        current = scan(folders)

        if current and now - totals_at > TOTALS_REFRESH_SECONDS:
            totals = {}
            totals.update(chromium_totals())
            totals.update(firefox_totals())
            totals_at = now

        items = []
        elapsed = max(0.001, now - previous_time)
        for path, stat in current.items():
            final_path = strip_partial(path)
            was = previous.get(path)
            rate = (stat.st_size - was.st_size) / elapsed if was else 0.0
            total, _received, _state = totals.get(final_path, (0, 0, None))
            items.append({
                "path": path,
                "finalPath": final_path,
                "name": os.path.basename(final_path),
                "bytes": stat.st_size,
                "total": total,
                "rate": max(0.0, rate),
                "stale": now - stat.st_mtime > 20,
            })

        finished = []
        for path in previous:
            if path in current:
                continue
            final_path = strip_partial(path)
            if not os.path.exists(final_path):
                continue  # cancelled, or renamed somewhere else
            try:
                size = os.path.getsize(final_path)
            except OSError:
                size = 0
            finished.append({
                "path": final_path,
                "name": os.path.basename(final_path),
                "bytes": size,
                "archive": is_archive(final_path),
                "checksum": checksum_file(final_path) or "",
            })

        items.sort(key=lambda item: -item["bytes"])
        print(json.dumps({"downloads": items, "finished": finished}), flush=True)

        if until_idle and not any(now - st.st_mtime <= 60 for st in current.values()) and not previous_fresh:
            return
        previous_fresh = any(now - st.st_mtime <= 60 for st in current.values())
        previous = current
        previous_time = now
        time.sleep(POLL_ACTIVE_SECONDS if current or until_idle else POLL_IDLE_SECONDS)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
