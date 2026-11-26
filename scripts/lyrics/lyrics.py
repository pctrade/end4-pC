#!/usr/bin/env python3
import sys
import urllib.request
import urllib.parse
import json
import re
import xml.etree.ElementTree as ET

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

def fetch_lrclib(title: str, artist: str, duration: float) -> list:
    urls = [
        f"https://lrclib.net/api/get?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}&duration={int(duration)}",
        f"https://lrclib.net/api/search?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}",
        f"https://lrclib.net/api/search?q={urllib.parse.quote(title + ' ' + artist)}",
    ]
    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                data = json.loads(r.read().decode())
            if isinstance(data, list):
                data = next((d for d in data if _is_match(d, title, artist)), None)
            if data and _is_match(data, title, artist):
                lines = _parse_lrc(data["syncedLyrics"])
                if lines:
                    return lines
        except Exception:
            continue
    return []

def _ttml_seconds(value: str) -> float:
    total = 0.0
    for part in value.replace("s", "").split(":"):
        total = total * 60 + float(part)
    return total

def _parse_ttml(ttml: str) -> list:
    root = ET.fromstring(ttml)
    lines = []
    for p in root.iter():
        if not p.tag.endswith("}p") and p.tag != "p":
            continue
        begin = p.get("begin")
        if begin is None:
            continue
        text = re.sub(r"\s+", " ", "".join(p.itertext())).strip()
        try:
            lines.append({"time": _ttml_seconds(begin), "text": text})
        except ValueError:
            continue
    return sorted(lines, key=lambda x: x["time"])

BOIDU_BASES = ["https://api.betterlyrics.org", "https://lyrics-api.boidu.dev"]

def fetch_boidu(title: str, artist: str, duration: float) -> list:
    query = f"/getLyrics?s={urllib.parse.quote(title)}&a={urllib.parse.quote(artist)}"
    if duration > 0:
        query += f"&d={int(duration)}"
    for base in BOIDU_BASES:
        try:
            req = urllib.request.Request(base + query, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = json.loads(r.read().decode())
            lines = _parse_ttml(data.get("ttml") or "")
            if len(lines) >= 3:
                return lines
        except Exception:
            continue
    return []

def main():
    if len(sys.argv) < 4:
        print("no_info", flush=True)
        sys.exit(0)
    title    = sys.argv[1]
    artist   = sys.argv[2]
    duration = float(sys.argv[3])
    if not title or not artist:
        print("no_info", flush=True)
        sys.exit(0)
    lines = fetch_lrclib(title, artist, duration) or fetch_boidu(title, artist, duration)
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