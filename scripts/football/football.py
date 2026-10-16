#!/usr/bin/env python3
import json
import math
import os
import sys
import time
import datetime as dt
from concurrent.futures import ThreadPoolExecutor
from urllib.request import Request, urlopen

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0 Safari/537.36"
SITE = "https://site.api.espn.com/apis/site/v2/sports/soccer"
CORE = "https://sports.core.api.espn.com/v2/sports/soccer/leagues"
CACHE = os.path.expanduser("~/.cache/quickshell/football")

LEAGUES = [
    {"id": "esp.1", "name": "LaLiga", "country": "ES", "goals": 1.30, "domestic": True},
    {"id": "eng.1", "name": "Premier League", "country": "EN", "goals": 1.45, "domestic": True},
    {"id": "ita.1", "name": "Serie A", "country": "IT", "goals": 1.30, "domestic": True},
    {"id": "fra.1", "name": "Ligue 1", "country": "FR", "goals": 1.40, "domestic": True},
    {"id": "por.1", "name": "Primeira Liga", "country": "PT", "goals": 1.30, "domestic": True},
    {"id": "tur.1", "name": "Süper Lig", "country": "TR", "goals": 1.45, "domestic": True},
    {"id": "ned.1", "name": "Eredivisie", "country": "NL", "goals": 1.65, "domestic": True},
    {"id": "ger.1", "name": "Bundesliga", "country": "DE", "goals": 1.60, "domestic": True},
    {"id": "mex.1", "name": "Liga MX", "country": "MX", "goals": 1.40, "domestic": True},
    {"id": "arg.1", "name": "Liga Profesional", "country": "AR", "goals": 1.10, "domestic": True},
    {"id": "bra.1", "name": "Brasileirão", "country": "BR", "goals": 1.25, "domestic": True},
    {"id": "ksa.1", "name": "Saudi Pro League", "country": "SA", "goals": 1.45, "domestic": True},
    {"id": "uefa.champions", "name": "Champions League", "country": "EU", "goals": 1.45, "domestic": False},
    {"id": "uefa.europa", "name": "Europa League", "country": "EU", "goals": 1.40, "domestic": False},
]
BY_ID = {league["id"]: league for league in LEAGUES}
CORNERS_PER_TEAM = 5.0
SHRINK = 5.0
HOME_BOOST = 1.10
AWAY_FACTOR = 0.92
DAYS_AHEAD = 8


def fetch(url, ttl, key):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, key + ".json")
    if os.path.exists(path) and time.time() - os.path.getmtime(path) < ttl:
        try:
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        except Exception:
            pass
    try:
        with urlopen(Request(url, headers={"User-Agent": UA}), timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(data, handle)
        os.replace(tmp, path)
        return data
    except Exception:
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as handle:
                    return json.load(handle)
            except Exception:
                return None
        return None


def poisson_pmf(mean, kmax):
    out = [math.exp(-mean)]
    for k in range(1, kmax + 1):
        out.append(out[-1] * mean / k)
    return out


def goals_probs(lh, la):
    ph = poisson_pmf(lh, 10)
    pa = poisson_pmf(la, 10)
    rho = -0.08
    matrix = [[ph[i] * pa[j] for j in range(11)] for i in range(11)]
    matrix[0][0] *= 1 - lh * la * rho
    matrix[0][1] *= 1 + lh * rho
    matrix[1][0] *= 1 + la * rho
    matrix[1][1] *= 1 - rho
    total = sum(sum(row) for row in matrix)
    home = draw = away = over15 = over25 = 0.0
    for i in range(11):
        for j in range(11):
            p = matrix[i][j] / total
            if i > j:
                home += p
            elif i == j:
                draw += p
            else:
                away += p
            if i + j >= 2:
                over15 += p
            if i + j >= 3:
                over25 += p
    return home, draw, away, over15, over25


def negbin_over(mean, line, dispersion=1.35):
    r = mean / (dispersion - 1)
    p = r / (r + mean)
    cdf = 0.0
    for k in range(int(math.floor(line)) + 1):
        logp = math.lgamma(k + r) - math.lgamma(r) - math.lgamma(k + 1) + r * math.log(p) + k * math.log(1 - p)
        cdf += math.exp(logp)
    return max(0.0, min(1.0, 1 - cdf))


def shrink(per_game, games, prior):
    return (per_game * games + prior * SHRINK) / (games + SHRINK)


def parse_stats(data):
    flat = {}
    for category in (data or {}).get("splits", {}).get("categories", []):
        for stat in category.get("stats", []):
            flat[stat.get("name")] = stat.get("value")
    return flat


def team_stats(league_id, season, team_id):
    url = f"{CORE}/{league_id}/seasons/{season}/types/1/teams/{team_id}/statistics"
    flat = parse_stats(fetch(url, 12 * 3600, f"stats_{league_id}_{season}_{team_id}"))
    games = float(flat.get("appearances") or 0)
    if games <= 0:
        return None
    return {
        "games": games,
        "gf": float(flat.get("totalGoals") or 0) / games,
        "ga": float(flat.get("goalsConceded") or 0) / games,
        "cf": float(flat.get("wonCorners") or 0) / games,
        "ca": float(flat.get("lostCorners") or 0) / games,
    }


def domestic_index():
    index = {}
    for league in LEAGUES:
        if not league["domestic"]:
            continue
        data = fetch(f"{SITE}/{league['id']}/teams?limit=100", 7 * 24 * 3600, f"teams_{league['id']}")
        if not data:
            continue
        try:
            for item in data["sports"][0]["leagues"][0]["teams"]:
                index[str(item["team"]["id"])] = league["id"]
        except Exception:
            continue
    return index


def build_matches(today):
    jobs = []
    for league in LEAGUES:
        for offset in range(DAYS_AHEAD + 1):
            day = today + dt.timedelta(days=offset)
            jobs.append((league, day.strftime("%Y%m%d")))

    def load(job):
        league, stamp = job
        data = fetch(f"{SITE}/{league['id']}/scoreboard?dates={stamp}", 20 * 60, f"board_{league['id']}_{stamp}")
        return league, data

    events = {}
    seasons = {}
    with ThreadPoolExecutor(max_workers=16) as pool:
        for league, data in pool.map(load, jobs):
            if not data:
                continue
            try:
                seasons[league["id"]] = data["leagues"][0]["season"]["year"]
            except Exception:
                pass
            for event in data.get("events", []):
                events[(league["id"], event["id"])] = (league, event)
    return events, seasons


def positions():
    def load(league):
        data = fetch(f"https://site.api.espn.com/apis/v2/sports/soccer/{league['id']}/standings", 3 * 3600, f"standings_{league['id']}")
        ranks = {}
        for child in (data or {}).get("children", []):
            for entry in child.get("standings", {}).get("entries", []):
                flat = {stat.get("name"): stat.get("value") for stat in entry.get("stats", [])}
                rank = int(flat.get("rank") or 0)
                if rank > 0:
                    ranks[str(entry.get("team", {}).get("id", ""))] = rank
        return league["id"], ranks

    with ThreadPoolExecutor(max_workers=8) as pool:
        result = dict(pool.map(load, LEAGUES))
    json.dump(result, sys.stdout)


def team_form(league_id, team_ids, count=6):
    domestic = domestic_index()
    result = {}

    def load(team_id):
        home_league = domestic.get(team_id) or league_id
        data = fetch(f"{SITE}/{home_league}/teams/{team_id}/schedule", 3 * 3600, f"schedule_{home_league}_{team_id}")
        games = []
        for event in (data or {}).get("events", []):
            try:
                competition = event["competitions"][0]
                if competition.get("status", {}).get("type", {}).get("state") != "post":
                    continue
                sides = {c["team"]["id"]: c for c in competition["competitors"]}
                mine = sides.get(team_id)
                other = [c for key, c in sides.items() if key != team_id]
                if not mine or not other:
                    continue

                def score(competitor):
                    value = competitor.get("score")
                    if isinstance(value, dict):
                        value = value.get("value", value.get("displayValue"))
                    return int(float(value or 0))

                mine_score, other_score = score(mine), score(other[0])
                games.append({
                    "date": event["date"],
                    "r": "W" if mine_score > other_score else ("L" if mine_score < other_score else "D"),
                    "vs": other[0]["team"].get("abbreviation", ""),
                    "score": f"{mine_score}-{other_score}",
                })
            except Exception:
                continue
        games.sort(key=lambda g: g["date"])
        return team_id, games[-count:]

    with ThreadPoolExecutor(max_workers=4) as pool:
        for team_id, games in pool.map(load, team_ids):
            result[team_id] = games
    json.dump(result, sys.stdout)


def standings(league_id):
    data = fetch(f"https://site.api.espn.com/apis/v2/sports/soccer/{league_id}/standings", 3 * 3600, f"standings_{league_id}")
    groups = []
    for child in (data or {}).get("children", []):
        rows = []
        for entry in child.get("standings", {}).get("entries", []):
            flat = {stat.get("name"): stat.get("value") for stat in entry.get("stats", [])}
            team = entry.get("team", {})
            logos = team.get("logos") or []
            rows.append({
                "rank": int(flat.get("rank") or 0),
                "id": str(team.get("id", "")),
                "name": team.get("displayName", ""),
                "abbr": team.get("abbreviation", ""),
                "logo": logos[0].get("href", "") if logos else "",
                "p": int(flat.get("gamesPlayed") or 0),
                "w": int(flat.get("wins") or 0),
                "d": int(flat.get("ties") or 0),
                "l": int(flat.get("losses") or 0),
                "gf": int(flat.get("pointsFor") or 0),
                "ga": int(flat.get("pointsAgainst") or 0),
                "gd": int(flat.get("pointDifferential") or 0),
                "pts": int(flat.get("points") or 0),
            })
        rows.sort(key=lambda row: row["rank"] or 999)
        groups.append({"name": child.get("name", ""), "rows": rows})
    json.dump({"league": league_id, "groups": groups}, sys.stdout)


def parse_iso(value):
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def match_corners(league_id, event_id):
    data = fetch(f"{SITE}/{league_id}/summary?event={event_id}", -1, f"summary_{event_id}")
    result = {"home": None, "away": None}
    try:
        for team in data["boxscore"]["teams"]:
            for stat in team.get("statistics", []):
                if stat.get("name") == "wonCorners":
                    result[team["homeAway"]] = int(float(stat.get("displayValue") or 0))
    except Exception:
        pass
    return result


def live_update():
    path = os.path.join(CACHE, "matches.json")
    try:
        with open(path, encoding="utf-8") as handle:
            cached = json.load(handle)
    except Exception:
        json.dump({"updates": []}, sys.stdout)
        return
    now = dt.datetime.now(dt.timezone.utc)
    pending = set()
    for match in cached.get("matches", []):
        kickoff = parse_iso(match["date"])
        if match["state"] == "in" or (match["state"] == "pre" and now - dt.timedelta(hours=4) < kickoff <= now + dt.timedelta(minutes=2)):
            pending.add(match["league"]["id"])
    index = {m["id"]: m for m in cached.get("matches", [])}
    updates = []
    stamps = [now.strftime("%Y%m%d"), (now - dt.timedelta(days=1)).strftime("%Y%m%d")]

    def load(job):
        league_id, stamp = job
        return league_id, fetch(f"{SITE}/{league_id}/scoreboard?dates={stamp}", -1, f"live_{league_id}_{stamp}")

    jobs = [(league_id, stamp) for league_id in sorted(pending) for stamp in stamps]
    with ThreadPoolExecutor(max_workers=8) as pool:
        for league_id, data in pool.map(load, jobs):
            for event in (data or {}).get("events", []):
                known = index.get(event["id"])
                if not known:
                    continue
                competition = event["competitions"][0]
                sides = {c["homeAway"]: c for c in competition["competitors"]}
                status = event.get("status", {}).get("type", {})
                known["state"] = status.get("state", known["state"])
                known["detail"] = status.get("shortDetail", "")
                known["home"]["score"] = sides["home"].get("score")
                known["away"]["score"] = sides["away"].get("score")
                updates.append({"id": event["id"], "league": league_id})

    seen = set()
    results = []
    for update in updates:
        if update["id"] in seen:
            continue
        seen.add(update["id"])
        match = index[update["id"]]
        corners = match_corners(update["league"], update["id"]) if match["state"] == "in" else {"home": None, "away": None}
        results.append({
            "id": match["id"],
            "state": match["state"],
            "detail": match["detail"],
            "home": {"score": match["home"]["score"]},
            "away": {"score": match["away"]["score"]},
            "corners": corners,
        })

    if results:
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(cached, handle)
        os.replace(tmp, path)
    json.dump({"updates": results}, sys.stdout)


def main():
    today = dt.datetime.now().astimezone().date()
    events, seasons = build_matches(today)
    domestic = domestic_index()

    needed = {}
    for (league_id, _), (_, event) in events.items():
        for competitor in event["competitions"][0]["competitors"]:
            team_id = str(competitor["team"]["id"])
            season = seasons.get(league_id)
            if season is None:
                continue
            needed[(league_id, season, team_id)] = True
            home_league = domestic.get(team_id)
            if home_league and home_league != league_id:
                needed[(home_league, seasons.get(home_league, season), team_id)] = True

    stats = {}

    def load_stats(key):
        return key, team_stats(*key)

    with ThreadPoolExecutor(max_workers=16) as pool:
        for key, value in pool.map(load_stats, list(needed.keys())):
            stats[key] = value

    def best_stats(league_id, team_id):
        season = seasons.get(league_id)
        own = stats.get((league_id, season, team_id))
        home_league = domestic.get(team_id)
        domestic_stats = stats.get((home_league, seasons.get(home_league, season), team_id)) if home_league else None
        if domestic_stats and (not own or domestic_stats["games"] >= own["games"]):
            return domestic_stats, BY_ID[home_league]["goals"]
        return own, BY_ID[league_id]["goals"]

    matches = []
    for (league_id, event_id), (league, event) in events.items():
        competition = event["competitions"][0]
        sides = {c["homeAway"]: c for c in competition["competitors"]}
        if "home" not in sides or "away" not in sides:
            continue
        status = event.get("status", {}).get("type", {})
        row = {
            "id": event_id,
            "league": {"id": league_id, "name": league["name"], "country": league["country"]},
            "date": event["date"],
            "state": status.get("state", "pre"),
            "detail": status.get("shortDetail", ""),
        }
        for side in ("home", "away"):
            team = sides[side]["team"]
            row[side] = {
                "id": str(team["id"]),
                "name": team.get("displayName", ""),
                "abbr": team.get("abbreviation", ""),
                "logo": team.get("logo", ""),
                "score": sides[side].get("score"),
            }
        home_stats, home_avg = best_stats(league_id, row["home"]["id"])
        away_stats, away_avg = best_stats(league_id, row["away"]["id"])
        row["sample"] = {
            "home": int(home_stats["games"]) if home_stats else 0,
            "away": int(away_stats["games"]) if away_stats else 0,
        }
        row["lowData"] = min(row["sample"]["home"], row["sample"]["away"]) < 4
        if home_stats and away_stats:
            avg = league["goals"]
            att_h = shrink(home_stats["gf"], home_stats["games"], home_avg) / home_avg
            def_h = shrink(home_stats["ga"], home_stats["games"], home_avg) / home_avg
            att_a = shrink(away_stats["gf"], away_stats["games"], away_avg) / away_avg
            def_a = shrink(away_stats["ga"], away_stats["games"], away_avg) / away_avg
            lam_h = min(3.8, max(0.35, avg * att_h * def_a * HOME_BOOST))
            lam_a = min(3.8, max(0.35, avg * att_a * def_h * AWAY_FACTOR))
            home, draw, away, o15, o25 = goals_probs(lam_h, lam_a)
            cf_h = shrink(home_stats["cf"], home_stats["games"], CORNERS_PER_TEAM) / CORNERS_PER_TEAM
            ca_h = shrink(home_stats["ca"], home_stats["games"], CORNERS_PER_TEAM) / CORNERS_PER_TEAM
            cf_a = shrink(away_stats["cf"], away_stats["games"], CORNERS_PER_TEAM) / CORNERS_PER_TEAM
            ca_a = shrink(away_stats["ca"], away_stats["games"], CORNERS_PER_TEAM) / CORNERS_PER_TEAM
            exp_c = min(14.0, max(6.0, CORNERS_PER_TEAM * 1.06 * cf_h * ca_a + CORNERS_PER_TEAM * 0.94 * cf_a * ca_h))
            row["probs"] = {
                "home": round(home, 4), "draw": round(draw, 4), "away": round(away, 4),
                "o15": round(o15, 4), "o25": round(o25, 4),
                "c85": round(negbin_over(exp_c, 8.5), 4),
                "c95": round(negbin_over(exp_c, 9.5), 4),
                "c105": round(negbin_over(exp_c, 10.5), 4),
            }
            row["expected"] = {"home": round(lam_h, 2), "away": round(lam_a, 2), "corners": round(exp_c, 1)}
        matches.append(row)

    matches.sort(key=lambda m: m["date"])
    out = {
        "generated": dt.datetime.now(dt.timezone.utc).isoformat(),
        "leagues": [{"id": l["id"], "name": l["name"], "country": l["country"]} for l in LEAGUES],
        "matches": matches,
    }
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "matches.json")
    with open(path + ".tmp", "w", encoding="utf-8") as handle:
        json.dump(out, handle)
    os.replace(path + ".tmp", path)
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    if "--form" in sys.argv:
        position = sys.argv.index("--form")
        team_form(sys.argv[position + 1], sys.argv[position + 2].split(","))
    elif "--positions" in sys.argv:
        positions()
    elif "--standings" in sys.argv:
        standings(sys.argv[sys.argv.index("--standings") + 1])
    elif "--live" in sys.argv:
        live_update()
    else:
        main()
