#!/usr/bin/env python3
"""Downloads whatever a copied link points at, into a folder the user can find again.

One entry point for every clipboard download action, so the shell only has to read a small line protocol:

    TITLE <text>     what is being downloaded, once it is known
    ISLAND <0-100>   overall progress
    FILE <path>      a finished file (or the folder, when the link was an album or a playlist)
    ERROR <code>     login | unsupported | notfound | network | failed

How a link is handled, in order:
  - Spotify track/album/playlist and Deezer track: the service itself hands out no audio, so the titles are
    read from its public page and each track is matched on YouTube Music.
  - A direct file (image, PDF, archive, anything that is not a web page): plain HTTP download.
  - Everything else: yt-dlp, which knows well over a thousand sites.
  - Posts that turn out to hold only pictures: the public tweet endpoint for X, then gallery-dl when installed.
"""

import argparse
import html
import json
import math
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
PLAYLIST_LIMIT = 100
AUDIO_EXTENSIONS = (".mp3", ".m4a", ".ogg", ".opus", ".wav", ".flac", ".aac")
VIDEO_EXTENSIONS = (".mp4", ".webm", ".mkv", ".mov", ".m4v")
PLAYLIST_URL = re.compile(
    r"youtube\.com/playlist\?|soundcloud\.com/[^/]+/sets/|bandcamp\.com/album/|mixcloud\.com/[^/]+/playlists/", re.I)
TWEET_URL = re.compile(r"https?://(?:www\.|mobile\.)?(?:twitter|x)\.com/[^/]+/status/(\d+)", re.I)
SPOTIFY_URL = re.compile(r"https?://open\.spotify\.com/(?:intl-[a-z-]+/)?(track|album|playlist)/([A-Za-z0-9]+)", re.I)
DEEZER_URL = re.compile(r"https?://(?:www\.)?deezer\.com/(?:[a-z]{2}/)?track/\d+", re.I)
DRIVE_URL = re.compile(r"https?://drive\.google\.com/file/d/([\w-]+)", re.I)
# Front ends people share instead of the real post
TWEET_MIRRORS = re.compile(r"^(https?://)(?:www\.)?(?:fxtwitter|vxtwitter|fixupx|fixvx|twittpr)\.com/", re.I)
WEB_PAGE_EXTENSIONS = (".html", ".htm", ".php", ".asp", ".aspx", ".jsp")


def emit(tag, value):
    print(f"{tag} {value}", flush=True)


def safe_name(text, limit=80):
    cleaned = re.sub(r'[\\/:*?"<>|\x00-\x1f]+', " ", text or "")
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" .")
    return cleaned.encode("utf-8")[:limit].decode("utf-8", "ignore").strip() or "download"


def unique_path(folder, name):
    stem, ext = os.path.splitext(name)
    candidate = os.path.join(folder, name)
    counter = 2
    while os.path.exists(candidate):
        candidate = os.path.join(folder, f"{stem} ({counter}){ext}")
        counter += 1
    return candidate


def fetch(url, timeout=20):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    return urllib.request.urlopen(request, timeout=timeout)


def error_code(text):
    lowered = (text or "").lower()
    if re.search(r"log ?in|sign in|cookies|authenticat|private|members[- ]only|age[- ]restricted|not authorized", lowered):
        return "login"
    if re.search(r"unsupported url|no video could be found|no media|there is no video|no suitable extractor", lowered):
        return "unsupported"
    if re.search(r"404|not found|unavailable|does not exist|removed|deleted", lowered):
        return "notfound"
    if re.search(r"timed out|temporary failure|name resolution|connection (reset|refused)|network is unreachable|unable to connect", lowered):
        return "network"
    return "failed"


def ytdlp(url, mode, dest, start=0.0, span=1.0, playlist=False, name=None, single_search=False):
    """Runs yt-dlp and returns (files, error text). Progress is reported inside [start, start + span]."""
    if playlist:
        template = "%(playlist_title,playlist_id|playlist).60B/%(title).80B.%(ext)s"
    else:
        template = f"{name.replace('%', '%%')}.%(ext)s" if name else "%(title).80B.%(ext)s"
    command = [
        "yt-dlp", "--newline", "--progress", "--no-mtime", "--no-warnings", "-P", dest, "-o", template,
        "--progress-template",
        "download:ISLAND %(progress._percent_str)s %(info.playlist_index|1)s %(info.n_entries|1)s",
        "--print", "after_move:FILE %(filepath)s", "--print", "before_dl:TITLE %(playlist_title,title)s",
    ]
    if playlist:
        command += ["--yes-playlist", "--playlist-end", str(PLAYLIST_LIMIT), "--ignore-errors"]
    elif single_search:
        command += ["--playlist-items", "1"]
    else:
        command += ["--no-playlist"]
    if mode == "audio":
        command += ["-x", "--audio-format", "mp3", "--audio-quality", "2", "--embed-metadata", "--embed-thumbnail"]
    else:
        # h264 + aac inside mp4 plays everywhere the file is likely to be sent next
        command += ["-S", "res:1080,vcodec:h264,acodec:aac", "--merge-output-format", "mp4"]
    command.append(url)

    files = []
    titled = False
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace")
    for line in process.stdout:
        line = line.strip()
        progress = re.match(r"ISLAND\s+([\d.]+)%\s+(\d+|NA)\s+(\d+|NA)", line)
        if progress:
            index = int(progress.group(2)) if progress.group(2).isdigit() else 1
            total = int(progress.group(3)) if progress.group(3).isdigit() else 1
            total = max(1, min(total, PLAYLIST_LIMIT))
            done = (min(index, total) - 1 + float(progress.group(1)) / 100) / total
            emit("ISLAND", round(100 * (start + span * done), 1))
        elif line.startswith("FILE "):
            files.append(line[5:])
        elif line.startswith("TITLE ") and not titled and not name:
            titled = True
            emit("TITLE", line[6:])
    errors = process.stderr.read()
    process.wait()
    return files, ("" if files else errors.strip().splitlines()[-1] if errors.strip() else "failed")


def spotify_entity(kind, entity_id):
    page = fetch(f"https://open.spotify.com/embed/{kind}/{entity_id}").read().decode("utf-8", "replace")
    match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    return json.loads(match.group(1))["props"]["pageProps"]["state"]["data"]["entity"]


def spotify(kind, entity_id, dest):
    entity = spotify_entity(kind, entity_id)
    name = entity.get("name") or entity.get("title") or ""
    if kind == "track":
        return matched_tracks([(name, ", ".join(a.get("name", "") for a in entity.get("artists", [])))], name, dest, dest)
    tracks = [(t.get("title", ""), (t.get("subtitle") or "").replace("\xa0", " ")) for t in entity.get("trackList", [])]
    return matched_tracks(tracks[:PLAYLIST_LIMIT], name, os.path.join(dest, safe_name(name or kind, 60)), dest)


def deezer(url, dest):
    page = fetch(url).read().decode("utf-8", "replace")
    def meta(key):
        found = re.search(rf'<meta property="og:{key}" content="([^"]*)"', page)
        return html.unescape(found.group(1)) if found else ""
    # og:description reads "Artist - song - 2016"
    return matched_tracks([(meta("title"), meta("description").split(" - ")[0])], meta("title"), dest, dest)


def matched_tracks(tracks, title, folder, dest):
    """Fetches (title, artists) pairs from YouTube Music. A folder other than dest is reported as one item."""
    tracks = [t for t in tracks if t[0]]
    if not tracks:
        return [], "no media"
    emit("TITLE", title or tracks[0][0])

    files = []
    last_error = ""
    for position, (title, artists) in enumerate(tracks):
        label = safe_name(f"{artists} - {title}" if artists else title)
        query = urllib.parse.quote(f"{artists} {title}".strip())
        start, span = position / len(tracks), 1 / len(tracks)
        got, problem = ytdlp(f"https://music.youtube.com/search?q={query}#songs", "audio", folder, start, span,
                             name=label, single_search=True)
        if not got:
            got, problem = ytdlp(f"ytsearch1:{artists} {title} audio", "audio", folder, start, span, name=label)
        files += got
        last_error = problem or last_error
    if not files:
        return [], last_error
    return ([folder] if folder != dest else files), ""


def direct(url, dest, response=None):
    response = response or fetch(url)
    name = ""
    disposition = response.headers.get("Content-Disposition", "")
    match = re.search(r"filename\*=(?:UTF-8'')?([^;]+)", disposition, re.I) or re.search(r'filename="?([^";]+)"?', disposition, re.I)
    if match:
        name = urllib.parse.unquote(match.group(1).strip())
    if not name:
        name = urllib.parse.unquote(urllib.parse.urlparse(response.geturl()).path.rsplit("/", 1)[-1])
    name = safe_name(name, 120)
    if "." not in name:
        subtype = response.headers.get_content_subtype()
        name += "." + {"jpeg": "jpg", "svg+xml": "svg", "plain": "txt", "x-zip-compressed": "zip", "mpeg": "mp3",
                       "octet-stream": "bin"}.get(subtype, subtype)
    emit("TITLE", name)
    os.makedirs(dest, exist_ok=True)
    target = unique_path(dest, name)
    total = int(response.headers.get("Content-Length") or 0)
    received = 0
    partial = target + ".part"
    with open(partial, "wb") as handle:
        while True:
            chunk = response.read(256 * 1024)
            if not chunk:
                break
            handle.write(chunk)
            received += len(chunk)
            if total:
                emit("ISLAND", round(100 * received / total, 1))
    os.replace(partial, target)
    return [target], ""


def tweet_photos(tweet_id, dest):
    # The embed endpoint needs no login; its token is the id run through this fixed formula
    value = int(tweet_id) / 1e15 * math.pi
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    whole, fraction, token = int(value), value - int(value), ""
    while whole:
        token = digits[whole % 36] + token
        whole //= 36
    for _ in range(12):
        fraction *= 36
        token += digits[int(fraction)]
        fraction -= int(fraction)
    token = token.replace("0", "")
    data = json.load(fetch(f"https://cdn.syndication.twimg.com/tweet-result?id={tweet_id}&token={token}&lang=en"))
    photos = [m["media_url_https"] for m in data.get("mediaDetails", []) if m.get("type") == "photo" and m.get("media_url_https")]
    if not photos:
        return [], "no media"
    author = data.get("user", {}).get("screen_name", "x")
    emit("TITLE", f"@{author}")
    os.makedirs(dest, exist_ok=True)
    files = []
    for position, photo in enumerate(photos):
        extension = os.path.splitext(urllib.parse.urlparse(photo).path)[1] or ".jpg"
        suffix = f"-{position + 1}" if len(photos) > 1 else ""
        target = unique_path(dest, f"{safe_name(author)}-{tweet_id}{suffix}{extension}")
        with fetch(f"{photo}?name=orig") as response, open(target, "wb") as handle:
            shutil.copyfileobj(response, handle)
        files.append(target)
        emit("ISLAND", round(100 * (position + 1) / len(photos), 1))
    return files, ""


def gallery(url, dest):
    tool = shutil.which("gallery-dl") or os.path.expanduser("~/.local/bin/gallery-dl")
    if not os.path.exists(tool):
        return [], ""
    result = subprocess.run([tool, "-D", dest, "--range", f"1-{PLAYLIST_LIMIT}", url], capture_output=True, text=True, errors="replace")
    files = [line.lstrip("# ").strip() for line in result.stdout.splitlines() if line.strip()]
    files = [f for f in files if os.path.isfile(f)]
    return files, ("" if files else (result.stderr.strip().splitlines() or ["failed"])[-1])


def download(url, mode, dest):
    url = TWEET_MIRRORS.sub(r"\1x.com/", url)
    spotify_match = SPOTIFY_URL.match(url)
    if spotify_match:
        return spotify(spotify_match.group(1).lower(), spotify_match.group(2), dest)
    if DEEZER_URL.match(url):
        return deezer(url, dest)

    path = urllib.parse.urlparse(url).path.lower()
    names_a_file = bool(re.search(r"\.[a-z0-9]{2,5}$", path)) and not path.endswith(AUDIO_EXTENSIONS + VIDEO_EXTENSIONS + WEB_PAGE_EXTENSIONS)
    if mode == "file" or names_a_file:
        # Looks like a file: only take it as one when the server agrees it is not a web page
        try:
            response = fetch(url)
            if mode == "file" or response.headers.get_content_type() not in ("text/html", "application/xhtml+xml"):
                return direct(url, dest, response)
            response.close()
        except urllib.error.HTTPError as problem:
            if mode == "file":
                return [], str(problem)

    files, problem = ytdlp(url, mode, dest, playlist=bool(PLAYLIST_URL.search(url)))
    if files:
        if PLAYLIST_URL.search(url):
            folders = {os.path.dirname(f) for f in files}
            return (sorted(folders) if len(folders) == 1 else files), ""
        return files, ""
    if mode == "audio":
        return [], problem

    tweet = TWEET_URL.match(url)
    if tweet:
        try:
            photos, photo_problem = tweet_photos(tweet.group(1), dest)
            if photos:
                return photos, ""
        except (urllib.error.URLError, ValueError, KeyError):
            pass
    drive = DRIVE_URL.match(url)
    if drive:
        # Not a video: small shared files still come straight from the download endpoint
        response = fetch(f"https://drive.google.com/uc?export=download&id={drive.group(1)}")
        if response.headers.get_content_type() != "text/html":
            return direct(url, dest, response)
        response.close()
    pictures, picture_problem = gallery(url, dest)
    if pictures:
        return pictures, ""
    return [], problem or picture_problem


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["video", "audio", "file"], default="video")
    parser.add_argument("--dest", required=True)
    parser.add_argument("url")
    arguments = parser.parse_args()
    os.makedirs(arguments.dest, exist_ok=True)
    try:
        files, problem = download(arguments.url, arguments.mode, arguments.dest)
    except urllib.error.HTTPError as failure:
        files, problem = [], str(failure)
    except (urllib.error.URLError, TimeoutError, OSError) as failure:
        files, problem = [], f"network is unreachable: {failure}"
    except (ValueError, KeyError, AttributeError) as failure:
        files, problem = [], f"failed: {failure}"
    for path in files:
        emit("FILE", path)
    if not files:
        emit("ERROR", error_code(problem))
        print(problem, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
