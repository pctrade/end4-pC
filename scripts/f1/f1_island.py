#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["websockets>=13"]
# ///
"""F1 live timing (or an archived session replay) as JSON lines on stdout."""

import argparse
import asyncio
import ctypes
import os
import signal
import datetime as dt
import json
import sys
import time
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}
STATIC = "https://livetiming.formula1.com/static/"
NEGOTIATE = "https://livetiming.formula1.com/signalrcore/negotiate?negotiateVersion=1"
WS_URL = "wss://livetiming.formula1.com/signalrcore"
OPENF1_SESSIONS = "https://api.openf1.org/v1/sessions"
RS = "\x1e"
TOPICS = [
    "SessionInfo", "SessionStatus", "TrackStatus", "LapCount",
    "DriverList", "TimingData", "RaceControlMessages", "ExtrapolatedClock",
    "TimingAppData", "WeatherData", "TeamRadio",
]
PRE_WINDOW = dt.timedelta(minutes=30)
POST_WINDOW = dt.timedelta(minutes=45)
FINISHED = ("Finalised", "Ends")

def log(*parts):
    print("[f1]", *parts, file=sys.stderr, flush=True)

def utcnow():
    return dt.datetime.now(dt.timezone.utc)

def http_get(url, timeout=20):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as resp:
        return resp.read().decode("utf-8-sig")

def merge(base, update):
    if isinstance(update, dict):
        if isinstance(base, list):
            for key, value in update.items():
                if not key.isdigit():
                    continue
                i = int(key)
                while len(base) <= i:
                    base.append(None)
                base[i] = merge(base[i], value)
            return base
        if not isinstance(base, dict):
            base = {}
        for key, value in update.items():
            if key == "_kf":
                continue
            if key == "_deleted":
                for gone in value or []:
                    base.pop(str(gone), None)
                continue
            base[key] = merge(base.get(key), value)
        return base
    if isinstance(update, list):
        return [merge(None, item) for item in update]
    return update

class State:
    def __init__(self):
        self.data = {}
        self.dirty = True

    def apply(self, topic, payload):
        if topic.endswith(".z"):
            return
        self.data[topic] = merge(self.data.get(topic), payload)
        self.dirty = True

    @property
    def status(self):
        return (self.data.get("SessionStatus") or {}).get("Status") or (self.data.get("SessionInfo") or {}).get("SessionStatus", "")

    def drivers(self):
        driver_list = self.data.get("DriverList") or {}
        lines = (self.data.get("TimingData") or {}).get("Lines") or {}
        app_lines = (self.data.get("TimingAppData") or {}).get("Lines") or {}
        out = []
        for num, info in driver_list.items():
            if not isinstance(info, dict) or not info.get("Tla"):
                continue
            timing = lines.get(num) or {}
            try:
                position = int(timing.get("Position") or info.get("Line") or 99)
            except (TypeError, ValueError):
                position = 99
            interval = timing.get("IntervalToPositionAhead")
            best = timing.get("BestLapTime")
            raw_stints = (app_lines.get(num) or {}).get("Stints") or []
            stints = raw_stints if isinstance(raw_stints, list) else list(raw_stints.values())
            stints = [s for s in stints if isinstance(s, dict)]
            tyre = next((s for s in reversed(stints) if s.get("Compound") not in (None, "", "UNKNOWN")), {})
            out.append({
                "num": num,
                "tla": info.get("Tla", ""),
                "name": info.get("LastName") or info.get("BroadcastName", ""),
                "team": info.get("TeamName", ""),
                "color": "#" + (info.get("TeamColour") or "888888"),
                "position": position,
                "gap": timing.get("GapToLeader", "") if isinstance(timing.get("GapToLeader"), str) else "",
                "interval": interval.get("Value", "") if isinstance(interval, dict) else "",
                "best": best.get("Value", "") if isinstance(best, dict) else "",
                "inPit": bool(timing.get("InPit")),
                "retired": bool(timing.get("Retired") or timing.get("Stopped")),
                "pits": timing.get("NumberOfPitStops", 0) or 0,
                "tyre": tyre.get("Compound", ""),
                "tyreNew": str(tyre.get("New", "")).lower() == "true",
                "tyreLaps": tyre.get("TotalLaps", 0) or 0,
                "stint": len(stints),
                "tyreStint": (stints.index(tyre) + 1) if tyre else 0,
            })
        out.sort(key=lambda d: d["position"])
        return out

    def view(self, mode, connected, next_session):
        d = self.data
        info = d.get("SessionInfo") or {}
        meeting = info.get("Meeting") or {}
        track = d.get("TrackStatus") or {}
        laps = d.get("LapCount") or {}
        clock = d.get("ExtrapolatedClock") or {}
        raw = (d.get("RaceControlMessages") or {}).get("Messages")
        messages = raw if isinstance(raw, list) else list((raw or {}).values())
        messages = [m for m in messages if isinstance(m, dict)]
        latest = messages[-1] if messages else None
        raw_radio = (d.get("TeamRadio") or {}).get("Captures")
        captures = raw_radio if isinstance(raw_radio, list) else list((raw_radio or {}).values())
        captures = sorted((c for c in captures if isinstance(c, dict) and c.get("Path")), key=lambda c: c.get("Utc", ""))
        radio = None
        if captures and info.get("Path"):
            capture = captures[-1]
            num = str(capture.get("RacingNumber", ""))
            radio = {
                "id": len(captures),
                "num": num,
                "tla": ((d.get("DriverList") or {}).get(num) or {}).get("Tla", ""),
                "url": STATIC + info["Path"] + capture["Path"],
                "utc": capture.get("Utc", ""),
            }
        return {
            "type": "state",
            "mode": mode,
            "connected": connected,
            "session": {
                "key": info.get("Key"),
                "meeting": meeting.get("Name", ""),
                "country": (meeting.get("Country") or {}).get("Code", ""),
                "circuit": (meeting.get("Circuit") or {}).get("ShortName", ""),
                "name": info.get("Name", ""),
                "type": info.get("Type", ""),
                "status": self.status,
            },
            "track": {"status": str(track.get("Status", "1")), "message": track.get("Message", "")},
            "lap": {"current": laps.get("CurrentLap", 0) or 0, "total": laps.get("TotalLaps", 0) or 0},
            "remaining": clock.get("Remaining", ""),
            "weather": {
                "air": (d.get("WeatherData") or {}).get("AirTemp", ""),
                "track": (d.get("WeatherData") or {}).get("TrackTemp", ""),
                "humidity": (d.get("WeatherData") or {}).get("Humidity", ""),
                "rain": str((d.get("WeatherData") or {}).get("Rainfall", "0")) not in ("0", "", "0.0"),
            },
            "drivers": self.drivers(),
            "raceControl": {
                "id": len(messages),
                "message": latest.get("Message", ""),
                "flag": latest.get("Flag", ""),
                "category": latest.get("Category", ""),
                "racingNumber": str(latest.get("RacingNumber", "")),
                "lap": latest.get("Lap", 0),
                "utc": latest.get("Utc", ""),
            } if latest else None,
            "radio": radio,
            "next": next_session,
        }

class Emitter:
    def __init__(self, min_interval=0.35):
        self.min_interval = min_interval
        self.last_time = 0.0
        self.last_line = None

    def emit(self, obj, force=False):
        if not force and time.monotonic() - self.last_time < self.min_interval:
            return False
        line = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
        if line != self.last_line:
            try:
                print(line, flush=True)
            except BrokenPipeError:
                sys.exit(0)
            self.last_line = line
        self.last_time = time.monotonic()
        return True

    def maybe(self, state, mode, connected, next_session, force=False):
        if (state.dirty or force) and self.emit(state.view(mode, connected, next_session), force):
            state.dirty = False

def fetch_schedule():
    since = (utcnow() - dt.timedelta(days=1)).strftime("%Y-%m-%d")
    query = urllib.parse.quote("date_end>", safe="") + "=" + since
    sessions = json.loads(http_get(f"{OPENF1_SESSIONS}?{query}"))
    out = []
    for s in sessions:
        if s.get("is_cancelled"):
            continue
        try:
            start = dt.datetime.fromisoformat(s["date_start"])
            end = dt.datetime.fromisoformat(s["date_end"])
        except (KeyError, ValueError):
            continue
        out.append({
            "name": s.get("session_name", ""),
            "type": s.get("session_type", ""),
            "meeting": s.get("location") or s.get("country_name", ""),
            "country": s.get("country_code", ""),
            "circuit": s.get("circuit_short_name", ""),
            "start": start.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "end": end.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "_start": start,
            "_end": end,
        })
    out.sort(key=lambda s: s["_start"])
    return out

def public(session):
    return {k: v for k, v in session.items() if not k.startswith("_")} if session else None

def negotiate():
    req = urllib.request.Request(NEGOTIATE, method="POST", headers=UA)
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = json.loads(resp.read())
        cookie = resp.headers.get("Set-Cookie", "")
    return body.get("connectionToken") or body["connectionId"], cookie.split(";")[0] if cookie else ""

async def stream_live(emitter, next_session, window_end):
    import websockets

    token, cookie = await asyncio.to_thread(negotiate)
    headers = dict(UA)
    if cookie:
        headers["Cookie"] = cookie
    url = f"{WS_URL}?id={urllib.parse.quote(token)}"
    state = State()
    async with websockets.connect(url, additional_headers=headers, max_size=None, ping_interval=None, open_timeout=20) as ws:
        await ws.send(json.dumps({"protocol": "json", "version": 1}) + RS)
        await ws.send(json.dumps({"type": 1, "invocationId": "1", "target": "Subscribe", "arguments": [TOPICS]}) + RS)
        log("connected")
        last_ping = time.monotonic()
        last_message = time.monotonic()
        while True:
            try:
                raw = await asyncio.wait_for(ws.recv(), 0.5)
            except asyncio.TimeoutError:
                raw = None
            now = time.monotonic()
            if orphaned():
                return
            if now - last_ping > 15:
                await ws.send('{"type":6}' + RS)
                last_ping = now
            if raw:
                last_message = now
                for part in raw.split(RS):
                    if not part:
                        continue
                    msg = json.loads(part)
                    kind = msg.get("type")
                    if kind == 3 and isinstance(msg.get("result"), dict):
                        for topic, payload in msg["result"].items():
                            state.apply(topic, payload)
                    elif kind == 1 and str(msg.get("target", "")).lower() == "feed":
                        args = msg.get("arguments") or []
                        if len(args) >= 2 and isinstance(args[0], str):
                            state.apply(args[0], args[1])
                    elif kind == 7:
                        raise ConnectionError(msg.get("error") or "server closed the connection")
            elif now - last_message > 90:
                raise ConnectionError("no data for 90s")
            emitter.maybe(state, "live", True, next_session)
            if window_end and utcnow() > window_end and state.status in FINISHED:
                emitter.maybe(state, "live", False, next_session, force=True)
                return

async def run_live(force, until_idle=False):
    emitter = Emitter()
    schedule, fetched_at = [], 0.0
    idle = State()
    while True:
        if orphaned():
            return
        if time.time() - fetched_at > 3600:
            try:
                schedule = await asyncio.to_thread(fetch_schedule)
                fetched_at = time.time()
            except Exception as exc:
                log("schedule fetch failed:", exc)
                fetched_at = time.time() - 3000
        now = utcnow()
        upcoming = [s for s in schedule if s["_end"] + POST_WINDOW > now]
        nxt = next((s for s in upcoming if s["_start"] > now), None)
        active = next((s for s in upcoming if s["_start"] - PRE_WINDOW <= now <= s["_end"] + POST_WINDOW), None)
        if active or force:
            try:
                await stream_live(emitter, public(nxt), active["_end"] + POST_WINDOW if active else None)
            except Exception as exc:
                log("live stream error:", exc)
                emitter.emit(idle.view("live", False, public(nxt)), force=True)
                await asyncio.sleep(15)
            if force and not active:
                force = False
        else:
            emitter.emit(idle.view("idle", False, public(nxt)), force=True)
            if until_idle:
                return
            await asyncio.sleep(30)

def resolve_replay_path(arg):
    if arg and arg != "latest":
        return arg.strip("/") + "/"
    year = utcnow().year
    index = json.loads(http_get(f"{STATIC}{year}/Index.json"))
    races = sorted(
        (s["StartDate"], s["Path"])
        for m in index["Meetings"] for s in m["Sessions"]
        if s.get("Type") == "Race" and s.get("Path")
    )
    return races[-1][1]

def parse_offset(text):
    h, m, s = text.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)

def load_stream(path, topic):
    try:
        text = http_get(f"{STATIC}{path}{topic}.jsonStream", timeout=90)
    except Exception as exc:
        log(f"could not load {topic}:", exc)
        return []
    events = []
    for line in text.splitlines():
        if len(line) < 13:
            continue
        try:
            events.append((parse_offset(line[:12]), topic, json.loads(line[12:])))
        except ValueError:
            continue
    return events

async def run_replay(path_arg, speed, start):
    path = await asyncio.to_thread(resolve_replay_path, path_arg)
    log("replaying", path, "at", speed, "x")
    state = State()
    try:
        state.apply("SessionInfo", json.loads(await asyncio.to_thread(http_get, f"{STATIC}{path}SessionInfo.json")))
    except Exception as exc:
        log("SessionInfo:", exc)
    streams = await asyncio.gather(*(asyncio.to_thread(load_stream, path, t) for t in TOPICS if t != "SessionInfo"))
    events = sorted((e for stream in streams for e in stream), key=lambda e: e[0])
    if start is None:
        started = next((e[0] for e in events if e[1] == "SessionStatus" and e[2].get("Status") == "Started"), 0)
        start = max(0.0, started - 45)
    else:
        start = parse_offset(start)
    emitter = Emitter()
    i = 0
    while i < len(events) and events[i][0] <= start:
        state.apply(events[i][1], events[i][2])
        i += 1
    emitter.maybe(state, "replay", True, None, force=True)
    clock = start
    for offset, topic, payload in events[i:]:
        delay = (offset - clock) / speed
        if delay > 0.03:
            emitter.maybe(state, "replay", True, None)
            await asyncio.sleep(delay)
            clock = offset
        state.apply(topic, payload)
    emitter.maybe(state, "replay", True, None, force=True)
    await asyncio.sleep(120)
    emitter.maybe(state, "replay", False, None, force=True)

def die_with_parent():
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except OSError:
        pass

def orphaned():
    return os.getppid() == 1

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd")
    live = sub.add_parser("live")
    live.add_argument("--force", action="store_true", help="connect now even with no session scheduled")
    live.add_argument("--until-idle", action="store_true", help="exit as soon as no session is on (after reporting the next one)")
    replay = sub.add_parser("replay")
    replay.add_argument("path", nargs="?", default="latest", help="static archive path or 'latest' race")
    replay.add_argument("--speed", type=float, default=1.0)
    replay.add_argument("--start", default=None, help="HH:MM:SS offset into the session feed")
    args = parser.parse_args()
    die_with_parent()
    try:
        if args.cmd == "replay":
            asyncio.run(run_replay(args.path, max(args.speed, 0.1), args.start))
        else:
            asyncio.run(run_live(getattr(args, "force", False), getattr(args, "until_idle", False)))
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
