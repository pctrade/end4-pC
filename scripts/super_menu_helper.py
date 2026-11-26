#!/usr/bin/env python3
"""Helper script for Launcher Omni-Search (files, browser history, smart suggestions, optional AI & Spotify)."""

from __future__ import annotations

import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

HOME = str(Path.home())
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "quickshell-omni"
TMP_DIR = Path(tempfile.gettempdir())

HISTORY_FILE = CACHE_DIR / "launcher_history.json"
QUEUE_FILE = CACHE_DIR / "spotify_queue.json"
TOKEN_CACHE = TMP_DIR / f"qs_spotify_token_{os.getuid()}.json"
SEARCH_CACHE = TMP_DIR / f"qs_spotify_search_cache_{os.getuid()}.json"
DAEMON_PID_FILE = TMP_DIR / f"qs_spotify_queue_daemon_{os.getuid()}.pid"

DEFAULT_SPOTIFY_SEARCH_HASH = "b02683192a98dde7966b5e6655a79eeb62713eab703eda9902c932818dd52751"


def notify(title: str, body: str, icon: str = "system-search", app_name: str = "Shell") -> None:
    try:
        subprocess.Popen(
            ["notify-send", "-a", app_name, "-i", icon, title, body],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


# ============================================================================
# 1. LAUNCHER HISTORY & BROWSER HISTORY (SMART SUGGESTIONS)
# ============================================================================

def _write_private_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(path.parent, 0o700)
    except OSError:
        pass
    fd, tmp_path = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}.")
    try:
        os.chmod(tmp_path, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def history_enabled() -> bool:
    return os.environ.get("QS_OMNI_HISTORY", "1") != "0"


def record_history(item_type: str, text: str, data: str = "") -> None:
    if not history_enabled():
        return
    text = text.strip()
    if not text:
        return
    try:
        history = []
        if HISTORY_FILE.exists():
            try:
                history = json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
            except Exception:
                history = []

        updated = False
        for item in history:
            if item.get("type") == item_type and item.get("text") == text:
                item["count"] = item.get("count", 1) + 1
                item["ts"] = time.time()
                if data:
                    item["data"] = data
                updated = True
                break
        if not updated:
            history.append({
                "type": item_type,
                "text": text,
                "data": data,
                "count": 1,
                "ts": time.time(),
            })

        history.sort(key=lambda x: x.get("ts", 0), reverse=True)
        history = history[:200]
        _write_private_json(HISTORY_FILE, history)
    except Exception:
        pass


def get_default_browser_cmd() -> list[str]:
    """Dynamically determine the system's default browser executable."""
    try:
        out = subprocess.check_output(
            ["xdg-settings", "get", "default-web-browser"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if out:
            for d in [os.path.expanduser("~/.local/share/applications"), "/usr/share/applications"]:
                p = os.path.join(d, out)
                if os.path.exists(p):
                    with open(p, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("Exec="):
                                exe = line[5:].strip().split()[0]
                                if shutil.which(exe):
                                    return [exe]
    except Exception:
        pass

    for b in ["zen-browser", "firefox", "google-chrome-stable", "brave", "chromium", "microsoft-edge-stable"]:
        if shutil.which(b):
            return [b]

    return ["xdg-open"]


def search_browser_history(query: str, limit: int = 6) -> list[dict]:
    query = query.strip()
    if not query:
        return []

    patterns = [
        os.path.expanduser("~/.config/zen/*/places.sqlite"),
        os.path.expanduser("~/.mozilla/firefox/*/places.sqlite"),
        os.path.expanduser("~/.config/mozilla/firefox/*/places.sqlite"),
        os.path.expanduser("~/.librewolf/*/places.sqlite"),
        os.path.expanduser("~/.waterfox/*/places.sqlite"),
    ]

    db_paths = [p for pat in patterns for p in glob.glob(pat) if not p.endswith(".bak")]
    results = []
    seen = set()
    like_q = f"%{query}%"

    for db_path in db_paths:
        try:
            uri = f"file:{db_path}?immutable=1"
            conn = sqlite3.connect(uri, uri=True, timeout=2)
            try:
                cur = conn.cursor()
                cur.execute(
                    """
                    SELECT url, title, visit_count
                    FROM moz_places
                    WHERE url LIKE 'http%' AND (url LIKE ? OR title LIKE ?)
                    ORDER BY visit_count DESC LIMIT ?
                    """,
                    (like_q, like_q, limit),
                )
                for url, title, count in cur.fetchall():
                    if url not in seen:
                        seen.add(url)
                        results.append({
                            "type": "browser_url",
                            "url": url,
                            "title": title or url,
                            "count": count,
                        })
            finally:
                conn.close()
            if len(results) >= limit:
                break
        except Exception:
            pass
    return results[:limit]


def get_spotify_history(is_play: bool = True, query: str = "") -> list[dict]:
    target_type = "spotify_play" if is_play else "spotify_queue"
    items = []
    if not HISTORY_FILE.exists():
        return items
    try:
        history = json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
        q = query.strip().lower()
        for h in history:
            if h.get("type") == target_type:
                text = h.get("text", "")
                if not q or q in text.lower():
                    items.append({
                        "text": text,
                        "uri": h.get("data", ""),
                        "count": h.get("count", 1),
                        "ts": h.get("ts", 0),
                    })
    except Exception:
        pass
    items.sort(key=lambda x: (x.get("count", 1), x.get("ts", 0)), reverse=True)
    return items[:10]


def search_suggestions(raw_query: str, include_browser: bool = True, include_spotify: bool = False) -> list[dict]:
    q = raw_query.strip()
    if not q:
        return []
    low_q = q.lower()

    suggestions = []
    seen = set()

    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
            for h in history:
                text = h.get("text", "")
                htype = h.get("type", "")
                hdata = h.get("data", "")
                if not include_spotify and htype in ("spotify_play", "spotify_queue"):
                    continue
                if low_q in text.lower() or (hdata and low_q in hdata.lower()):
                    key = (htype, text)
                    if key not in seen:
                        seen.add(key)
                        suggestions.append({
                            "type": htype,
                            "text": text,
                            "data": hdata,
                            "count": h.get("count", 1),
                            "ts": h.get("ts", 0),
                        })
        except Exception:
            pass

    suggestions.sort(key=lambda x: (x.get("count", 1), x.get("ts", 0)), reverse=True)

    if include_browser:
        for b in search_browser_history(q, limit=6):
            key = ("url", b["url"])
            if key not in seen:
                seen.add(key)
                suggestions.append({
                    "type": "browser_url",
                    "text": b["url"],
                    "data": b["title"],
                    "count": b["count"],
                })

    return suggestions[:8]


def open_browser_url(url: str) -> None:
    record_history("url", url, url)
    cmd = get_default_browser_cmd() + [url]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_browser_search(query: str, engine_base_url: str = "https://www.google.com/search?q=") -> None:
    record_history("search", query)
    url = f"{engine_base_url}{urllib.parse.quote(query)}"
    cmd = get_default_browser_cmd() + [url]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_shell_command(cmd: str) -> None:
    record_history("command", cmd)
    subprocess.Popen(["bash", "-c", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ============================================================================
# 2. OPTIONAL AI DESKTOP SHORTCUTS
# ============================================================================

def open_claude_app(prompt: str = "") -> None:
    prompt = prompt.strip()
    if prompt:
        record_history("claude", prompt, "Claude")
        try:
            subprocess.run(["wl-copy", prompt], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        encoded_prompt = urllib.parse.quote(prompt)
        url = f"claude://claude.ai/new?q={encoded_prompt}"
        if shutil.which("gtk-launch"):
            try:
                subprocess.Popen(["gtk-launch", "com.anthropic.Claude", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                pass
    if shutil.which("gtk-launch"):
        try:
            subprocess.Popen(["gtk-launch", "com.anthropic.Claude"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except Exception:
            pass
    if shutil.which("claude-desktop"):
        subprocess.Popen(["claude-desktop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    web_url = f"https://claude.ai/new?q={urllib.parse.quote(prompt)}" if prompt else "https://claude.ai"
    open_browser_url(web_url)


def open_chatgpt_app(prompt: str = "") -> None:
    prompt = prompt.strip()
    if prompt:
        record_history("gpt", prompt, "ChatGPT")
        try:
            subprocess.run(["wl-copy", prompt], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        notify("ChatGPT", f"Prompt copied to clipboard ({prompt[:40]})", "chatgpt")
    if shutil.which("gtk-launch"):
        try:
            subprocess.Popen(["gtk-launch", "chatgpt"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except Exception:
            pass
    if shutil.which("chatgpt"):
        subprocess.Popen(["chatgpt"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    web_url = f"https://chatgpt.com/?q={urllib.parse.quote(prompt)}" if prompt else "https://chatgpt.com"
    open_browser_url(web_url)


# ============================================================================
# 3. FILE & FOLDER SEARCH ("/")
# ============================================================================

SHORTCUT_DIRS = {
    "home": HOME,
    "tmp": "/tmp",
    "documents": os.path.join(HOME, "Documents"),
    "desktop": os.path.join(HOME, "Desktop"),
    "downloads": os.path.join(HOME, "Downloads"),
    "pictures": os.path.join(HOME, "Pictures"),
    "music": os.path.join(HOME, "Music"),
    "videos": os.path.join(HOME, "Videos"),
    "config": os.path.join(HOME, ".config"),
}


def make_file_entry(path_str: str) -> dict | None:
    try:
        p = Path(path_str)
        if not p.exists():
            return None
        is_dir = p.is_dir()
        abs_path = str(p.resolve() if not p.is_symlink() else p)
        display_name = abs_path if abs_path in ("/", "/home", "/tmp", "/mnt") else p.name or abs_path
        return {
            "path": abs_path,
            "name": display_name,
            "is_dir": is_dir,
            "comment": f"{abs_path} — Open folder" if is_dir else f"{abs_path} — Reveal in file manager",
            "verb": "Open" if is_dir else "Reveal",
        }
    except Exception:
        return None


def search_files(raw_query: str) -> list[dict]:
    q = raw_query.strip()
    if not q.startswith("/"):
        return []

    results: list[dict] = []
    seen: set[str] = set()

    def add_path(p_str: str) -> None:
        norm = os.path.normpath(p_str)
        if norm in seen:
            return
        entry = make_file_entry(norm)
        if entry:
            seen.add(norm)
            results.append(entry)

    stripped = q.lstrip("/").strip()

    if stripped == "":
        for d in [HOME, "/home", "/tmp", os.path.join(HOME, "Documents"), os.path.join(HOME, "Downloads"), os.path.join(HOME, "Desktop")]:
            add_path(d)
        return results

    low = stripped.lower()
    if low in SHORTCUT_DIRS:
        if os.path.exists(q):
            add_path(q)
        add_path(SHORTCUT_DIRS[low])

    expanded = os.path.expanduser("~" + q) if not os.path.exists(q) and os.path.exists(os.path.expanduser("~" + q)) else q
    if os.path.exists(expanded):
        add_path(expanded)
        if os.path.isdir(expanded):
            try:
                children = sorted(
                    os.listdir(expanded),
                    key=lambda name: (not os.path.isdir(os.path.join(expanded, name)), name.lower()),
                )
                for child in children:
                    if child.startswith("."):
                        continue
                    add_path(os.path.join(expanded, child))
                    if len(results) >= 12:
                        break
            except Exception:
                pass

    for candidate_path in (q, os.path.expanduser("~" + q)):
        parent_dir = os.path.dirname(candidate_path)
        partial_name = os.path.basename(candidate_path).lower()
        if parent_dir and os.path.isdir(parent_dir):
            try:
                children = sorted(
                    os.listdir(parent_dir),
                    key=lambda name: (
                        not name.lower().startswith(partial_name),
                        not os.path.isdir(os.path.join(parent_dir, name)),
                        name.lower(),
                    ),
                )
                for child in children:
                    if not partial_name.startswith(".") and child.startswith("."):
                        continue
                    if partial_name in child.lower():
                        add_path(os.path.join(parent_dir, child))
                        if len(results) >= 12:
                            break
            except Exception:
                pass

    if len(results) < 10 and "/" not in stripped and len(stripped) >= 2 and shutil.which("fd"):
        try:
            fd_out = subprocess.check_output(
                [
                    "fd",
                    "--follow",
                    "--max-depth",
                    "4",
                    "--max-results",
                    "12",
                    "--color",
                    "never",
                    "-i",
                    stripped,
                    HOME,
                ],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=1.5,
            )
            lines = [line.strip() for line in fd_out.splitlines() if line.strip()]
            lines.sort(key=lambda p: (not os.path.isdir(p), len(p)))
            for line in lines:
                add_path(line)
                if len(results) >= 12:
                    break
        except Exception:
            pass

    return results[:12]


def open_in_file_manager(target: str) -> None:
    target = target.strip()
    if not os.path.exists(target):
        matches = search_files(target if target.startswith("/") else "/" + target)
        if matches:
            target = matches[0]["path"]
        else:
            notify("File Manager", f"Not found: {target}", "system-file-manager")
            return

    if os.path.isdir(target):
        subprocess.Popen(["xdg-open", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return

    if shutil.which("dolphin"):
        subprocess.Popen(["dolphin", "--select", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif shutil.which("nautilus"):
        subprocess.Popen(["nautilus", "--select", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.Popen(["xdg-open", os.path.dirname(target) or HOME], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ============================================================================
# 4. OPTIONAL SPOTIFY SEARCH, PLAY & QUEUE DAEMON
# ============================================================================

def resolve_spotify_search_hash() -> str:
    """Dynamically extract searchTracks persistedQuery hash from local Spotify install if present."""
    candidates = [
        "/opt/spotify/Apps/xpui/xpui-routes-search.js",
        "/usr/share/spotify/Apps/xpui/xpui-routes-search.js",
    ]
    for path in candidates:
        if os.path.isfile(path):
            try:
                content = Path(path).read_text(encoding="utf-8", errors="ignore")
                m = re.search(r'"searchTracks"\s*,\s*"query"\s*,\s*"([a-f0-9]{64})"', content)
                if m:
                    return m.group(1)
            except Exception:
                pass
    return os.environ.get("QS_SPOTIFY_SEARCH_HASH", DEFAULT_SPOTIFY_SEARCH_HASH)


def get_spotify_token(force_refresh: bool = False) -> str:
    if not force_refresh and TOKEN_CACHE.exists():
        try:
            data = json.loads(TOKEN_CACHE.read_text(encoding="utf-8"))
            if time.time() - data.get("ts", 0) < 1800 and data.get("token"):
                return data["token"]
        except Exception:
            pass

    req = urllib.request.Request(
        "https://open.spotify.com/embed/track/2sLAykCWyB1VA5hXDjU59T",
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"},
    )
    html = urllib.request.urlopen(req, timeout=5).read().decode("utf-8", errors="ignore")
    m = re.search(r'"accessToken":"([^"]+)"', html)
    if not m:
        raise RuntimeError("Could not obtain Spotify embed token")
    token = m.group(1)
    try:
        TOKEN_CACHE.write_text(json.dumps({"token": token, "ts": time.time()}), encoding="utf-8")
    except Exception:
        pass
    return token


def search_spotify_tracks(song_query: str, limit: int = 6) -> list[dict]:
    song_query = song_query.strip()
    if not song_query:
        return []

    cache = {}
    if SEARCH_CACHE.exists():
        try:
            cache = json.loads(SEARCH_CACHE.read_text(encoding="utf-8"))
        except Exception:
            cache = {}

    cache_key = f"{song_query.lower()}:{limit}"
    if cache_key in cache and time.time() - cache[cache_key].get("ts", 0) < 3600:
        return cache[cache_key]["items"]

    search_hash = resolve_spotify_search_hash()
    tracks = []
    for attempt in range(2):
        try:
            token = get_spotify_token(force_refresh=(attempt == 1))
            variables = {
                "searchTerm": song_query,
                "offset": 0,
                "limit": limit,
                "numberOfTopResults": limit,
                "includeAudiobooks": False,
                "includePreReleases": False,
            }
            extensions = {
                "persistedQuery": {
                    "version": 1,
                    "sha256Hash": search_hash,
                }
            }
            url = (
                "https://api-partner.spotify.com/pathfinder/v1/query?operationName=searchTracks&variables="
                + urllib.parse.quote(json.dumps(variables))
                + "&extensions="
                + urllib.parse.quote(json.dumps(extensions))
            )
            req = urllib.request.Request(
                url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
                },
            )
            res = json.loads(urllib.request.urlopen(req, timeout=4).read().decode("utf-8"))
            items = res.get("data", {}).get("searchV2", {}).get("tracksV2", {}).get("items", [])
            for it in items:
                tdata = it.get("item", {}).get("data", {})
                uri = tdata.get("uri", "")
                name = tdata.get("name", "")
                if not uri.startswith("spotify:track:") or not name:
                    continue
                artists = ", ".join(
                    a.get("profile", {}).get("name", "")
                    for a in tdata.get("artists", {}).get("items", [])
                    if a.get("profile", {}).get("name")
                )
                album = tdata.get("albumOfTrack", {}).get("name", "")
                tracks.append({
                    "uri": uri,
                    "name": name,
                    "artists": artists,
                    "album": album,
                    "display": f"{name} — {artists}" if artists else name,
                })
            break
        except Exception:
            if attempt == 1:
                break

    if tracks:
        try:
            if len(cache) > 100:
                cache = {}
            cache[cache_key] = {"ts": time.time(), "items": tracks}
            SEARCH_CACHE.write_text(json.dumps(cache), encoding="utf-8")
        except Exception:
            pass

    return tracks


def ensure_spotify_running() -> bool:
    try:
        subprocess.check_output(["pgrep", "-x", "spotify"])
        return True
    except subprocess.CalledProcessError:
        if not shutil.which("spotify"):
            return False
        subprocess.Popen(["spotify"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(25):
            time.sleep(0.3)
            try:
                subprocess.check_output(
                    [
                        "dbus-send",
                        "--print-reply",
                        "--dest=org.mpris.MediaPlayer2.spotify",
                        "/org/mpris/MediaPlayer2",
                        "org.freedesktop.DBus.Peer.Ping",
                    ],
                    stderr=subprocess.DEVNULL,
                )
                time.sleep(0.5)
                return True
            except Exception:
                pass
        return False


def spotify_open_uri(uri: str) -> None:
    ensure_spotify_running()
    subprocess.run(
        [
            "dbus-send",
            "--print-reply",
            "--dest=org.mpris.MediaPlayer2.spotify",
            "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player.OpenUri",
            f"string:{uri}",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def play_track(uri: str, display_name: str = "") -> None:
    if display_name:
        record_history("spotify_play", display_name, uri)
    spotify_open_uri(uri)
    if display_name:
        notify("Now Playing", display_name, "spotify", "Spotify")


def ensure_queue_daemon() -> None:
    if DAEMON_PID_FILE.exists():
        try:
            pid = int(DAEMON_PID_FILE.read_text(encoding="utf-8").strip())
            os.kill(pid, 0)
            return
        except Exception:
            pass
    subprocess.Popen(
        [sys.executable, __file__, "queue-daemon"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def queue_track(uri: str, display_name: str = "") -> None:
    if display_name:
        record_history("spotify_queue", display_name, uri)
    QUEUE_FILE.parent.mkdir(parents=True, exist_ok=True)
    queue = []
    if QUEUE_FILE.exists():
        try:
            queue = json.loads(QUEUE_FILE.read_text(encoding="utf-8"))
        except Exception:
            queue = []
    queue.append({"uri": uri, "display": display_name, "ts": time.time()})
    QUEUE_FILE.write_text(json.dumps(queue), encoding="utf-8")
    ensure_queue_daemon()
    if display_name:
        notify("Added to Queue", display_name, "spotify", "Spotify")


def run_queue_daemon() -> None:
    DAEMON_PID_FILE.write_text(str(os.getpid()), encoding="utf-8")
    last_track_id = None
    last_length_sec = 0.0
    last_pos_sec = 0.0
    triggered_for_track = None
    idle_ticks = 0

    while True:
        try:
            queue = json.loads(QUEUE_FILE.read_text(encoding="utf-8")) if QUEUE_FILE.exists() else []
            if not queue:
                idle_ticks += 1
                if idle_ticks > 50:
                    break
                time.sleep(0.6)
                continue
            idle_ticks = 0

            out = subprocess.check_output(
                [
                    "playerctl",
                    "-p",
                    "spotify",
                    "metadata",
                    "--format",
                    "{{status}}|{{mpris:trackid}}|{{mpris:length}}|{{position}}",
                ],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
            parts = out.split("|")
            if len(parts) == 4:
                status, track_id, length_us, pos_us = parts
                length_sec = int(length_us) / 1_000_000.0 if length_us.isdigit() else 0.0
                pos_sec = int(pos_us) / 1_000_000.0 if pos_us.isdigit() else 0.0

                should_play_next = (
                    status == "Playing"
                    and length_sec > 5.0
                    and (length_sec - pos_sec) <= 1.4
                    and triggered_for_track != track_id
                ) or (
                    bool(last_track_id)
                    and track_id != last_track_id
                    and last_length_sec > 5.0
                    and (last_length_sec - last_pos_sec) <= 4.0
                    and triggered_for_track != last_track_id
                )

                if should_play_next:
                    queue = json.loads(QUEUE_FILE.read_text(encoding="utf-8")) if QUEUE_FILE.exists() else []
                    next_item = queue.pop(0) if queue else None
                    QUEUE_FILE.write_text(json.dumps(queue), encoding="utf-8")
                    if next_item:
                        triggered_for_track = next_item["uri"].split(":")[-1]
                        spotify_open_uri(next_item["uri"])
                        if next_item.get("display"):
                            notify("Playing Next", next_item["display"], "spotify", "Spotify")
                        time.sleep(2.5)
                        last_track_id = None
                        continue

                last_track_id = track_id
                last_length_sec = length_sec
                last_pos_sec = pos_sec
        except Exception:
            pass
        time.sleep(0.6)

    try:
        DAEMON_PID_FILE.unlink(missing_ok=True)
    except Exception:
        pass


def main() -> None:
    if len(sys.argv) < 2:
        print("[]")
        return

    cmd = sys.argv[1]
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    arg2 = sys.argv[3] if len(sys.argv) > 3 else ""
    arg3 = sys.argv[4] if len(sys.argv) > 4 else ""

    if cmd == "file-search":
        print(json.dumps(search_files(arg), ensure_ascii=False))
    elif cmd == "file-open":
        open_in_file_manager(arg)
    elif cmd == "spotify-search":
        print(json.dumps(search_spotify_tracks(arg), ensure_ascii=False))
    elif cmd == "spotify-play":
        play_track(arg, arg2)
    elif cmd == "spotify-play-query":
        tracks = search_spotify_tracks(arg, limit=1)
        if tracks:
            play_track(tracks[0]["uri"], tracks[0]["display"])
        else:
            notify("Spotify", f"Track not found: {arg}", "spotify", "Spotify")
    elif cmd == "spotify-queue":
        queue_track(arg, arg2)
    elif cmd == "spotify-queue-query":
        tracks = search_spotify_tracks(arg, limit=1)
        if tracks:
            queue_track(tracks[0]["uri"], tracks[0]["display"])
        else:
            notify("Spotify", f"Track not found: {arg}", "spotify", "Spotify")
    elif cmd == "queue-daemon":
        run_queue_daemon()
    elif cmd == "spotify-history":
        is_play = arg in ("play", "p")
        print(json.dumps(get_spotify_history(is_play, arg2), ensure_ascii=False))
    elif cmd == "suggestions":
        include_browser = arg2 != "0"
        include_spotify = arg3 == "1"
        print(json.dumps(search_suggestions(arg, include_browser=include_browser, include_spotify=include_spotify), ensure_ascii=False))
    elif cmd == "record":
        record_history(arg, arg2, arg3)
    elif cmd == "open-url":
        open_browser_url(arg)
    elif cmd == "open-search":
        open_browser_search(arg, arg2 or "https://www.google.com/search?q=")
    elif cmd == "run-shell":
        run_shell_command(arg)
    elif cmd == "open-claude":
        open_claude_app(arg)
    elif cmd == "open-chatgpt":
        open_chatgpt_app(arg)


if __name__ == "__main__":
    main()
