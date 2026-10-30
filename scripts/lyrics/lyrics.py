#!/usr/bin/env python3
import sys
import re
import time
import urllib.error
import urllib.request
import urllib.parse
import json

def _parse_lrc(lrc_text: str) -> list:
    lines = []
    for raw in lrc_text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            tag_end = raw.index("]")
            time_str = raw[1:tag_end]
            text = raw[tag_end + 1:].strip()
            mins, secs = time_str.split(":")
            timestamp = int(mins) * 60 + float(secs)
            lines.append({"time": timestamp, "text": text})
        except Exception:
            continue
    return sorted(lines, key=lambda x: x["time"])

def _is_match(d: dict, title: str, artist: str) -> bool:
    if not d.get("syncedLyrics"):
        return False
    r_title  = (d.get("trackName")  or "").lower()
    r_artist = (d.get("artistName") or "").lower()
    t = title.lower()
    a = artist.lower()
    title_match = (t in r_title or r_title in t or
                   any(word in r_title for word in t.split() if len(word) > 3))
    artist_match = (a in r_artist or r_artist in a or
                    any(word in r_artist for word in a.split() if len(word) > 3))
    return title_match and artist_match

def _usable_lines(d: dict, title: str, artist: str) -> list:
    if not _is_match(d, title, artist):
        return []
    lines = _parse_lrc(d["syncedLyrics"])
    # lrclib also holds junk entries ("[00:00.00]probe"), even as the exact
    # match: a song has more than a line or two, so try the next result
    return lines if sum(1 for line in lines if line["text"]) >= 3 else []

class LookupError_(Exception):
    """lrclib could not answer (overloaded, timeout, offline): worth retrying later."""

def _get_json(url: str):
    # lrclib often answers 503 "ServerOverloaded" for a moment
    for delay in (0, 1.5, 3):
        time.sleep(delay)
        try:
            with urllib.request.urlopen(url, timeout=10) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code < 500 and e.code != 429:
                return None
        except (urllib.error.URLError, TimeoutError, OSError):
            pass
        except ValueError:
            return None
    raise LookupError_(url)

def _variants(title: str, artist: str) -> list:
    """The title and artist as given, then cleaned of what lrclib does not store."""
    if not artist and " - " in title:
        # Browsers often only give "Artist - Title (Official Video) - YouTube"
        artist, title = title.split(" - ", 1)
    title = re.sub(r"\s+-\s+(YouTube|YouTube Music|SoundCloud)$", "", title, flags=re.I)
    clean_title = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", title)           # (feat. x), [Official Video]
    clean_title = re.sub(r"\s+-\s+.*(remaster|version|edit|mix|live|mono|stereo).*$", "", clean_title, flags=re.I).strip()
    main_artist = re.split(r"\s*(?:,|&|\bfeat\.?|\bft\.?|\bx\b)\s*", artist, flags=re.I)[0].strip()
    variants = []
    for v in ((title, artist), (clean_title, artist), (clean_title, main_artist)):
        if v[0] and v[1] and v not in variants:
            variants.append(v)
    return variants

def fetch_lrclib(title: str, artist: str, duration: float) -> list:
    failed = False
    for t, a in _variants(title, artist):
        q = urllib.parse.quote
        urls = [
            f"https://lrclib.net/api/get?track_name={q(t)}&artist_name={q(a)}&duration={int(duration)}",
            f"https://lrclib.net/api/search?track_name={q(t)}&artist_name={q(a)}",
            f"https://lrclib.net/api/search?q={q(t + ' ' + a)}",
        ]
        for url in urls:
            try:
                data = _get_json(url)
            except LookupError_:
                failed = True
                continue
            for d in (data if isinstance(data, list) else [data] if data else []):
                lines = _usable_lines(d, t, a)
                if lines:
                    return lines
    if failed:
        raise LookupError_("lrclib unreachable")
    return []

def main():
    if len(sys.argv) < 4:
        print("no_info", flush=True)
        sys.exit(0)
    title    = sys.argv[1]
    artist   = sys.argv[2]
    duration = float(sys.argv[3])
    if not title:
        print("no_info", flush=True)
        sys.exit(0)
    try:
        lines = fetch_lrclib(title, artist, duration)
    except LookupError_:
        print("error", flush=True)
        sys.exit(0)
    if not lines:
        print("not_found", flush=True)
        sys.exit(0)
    parts = []
    for line in lines:
        parts.append(str(line["time"]))
        parts.append(line["text"].replace("§", ""))
    parts.append("ok")
    print("§".join(parts), flush=True)

if __name__ == "__main__":
    main()