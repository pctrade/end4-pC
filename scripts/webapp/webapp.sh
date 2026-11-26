#!/usr/bin/env bash
set -u

APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/shell-webapps/icons"
PREFIX="shell-webapp-"

find_browser() {
    local candidate
    for candidate in chromium google-chrome-stable google-chrome chrome; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

normalize_url() {
    local url
    url="$(printf '%s' "$1" | tr -d '[:space:]')"
    [ -n "$url" ] || return 1
    case "$url" in
        http://*|https://*) ;;
        *) url="https://$url" ;;
    esac
    printf '%s' "$url"
}

parse_url() {
    python3 -I - "$1" <<'PY'
import sys, re
from urllib.parse import urlparse
url = sys.argv[1]
p = urlparse(url)
host = p.hostname or ""
if not host or "." not in host and host != "localhost":
    sys.exit(1)
path = p.path or "/"
bare = re.sub(r"^www\.", "", host)
slug = re.sub(r"[^a-z0-9]+", "-", (bare + path).lower()).strip("-")
parts = bare.split(".")
if bare == "localhost" or len(parts) < 2:
    label = parts[0]
elif len(parts) >= 3 and len(parts[-1]) == 2 and parts[-2] in ("co", "com", "org", "net", "gov", "edu", "ac"):
    label = parts[-3]
else:
    label = parts[-2]
print(slug)
print(label.capitalize())
print(host + "_" + path.replace("/", "_"))
PY
}

page_info() {
    python3 -I - "$1" <<'PY'
import sys, re, json
from urllib.request import Request, urlopen
from urllib.parse import urljoin

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0 Safari/537.36"
base = sys.argv[1]

def get(url, limit=400000):
    req = Request(url, headers={"User-Agent": UA})
    with urlopen(req, timeout=10) as resp:
        return resp.geturl(), resp.read(limit)

def attrs(tag):
    return {k.lower(): v for k, _, v in re.findall(r'([\w:-]+)\s*=\s*(["\'])(.*?)\2', tag)}

name = ""
cands = []
try:
    final, raw = get(base)
    html = raw.decode("utf-8", "ignore")
    for tag in re.findall(r"<meta\b[^>]*>", html, re.I):
        a = attrs(tag)
        key = (a.get("property") or a.get("name") or "").lower()
        if key in ("og:site_name", "application-name") and a.get("content") and not name:
            name = a["content"].strip()
    manifest = None
    for tag in re.findall(r"<link\b[^>]*>", html, re.I):
        a = attrs(tag)
        rel = (a.get("rel") or "").lower()
        href = a.get("href")
        if not href:
            continue
        if "manifest" in rel:
            manifest = urljoin(final, href)
        elif "icon" in rel:
            size = 0
            m = re.match(r"(\d+)x\d+", (a.get("sizes") or "").split(" ")[0])
            if m:
                size = int(m.group(1))
            elif "apple-touch" in rel:
                size = 180
            cands.append((size, urljoin(final, href)))
    if manifest:
        try:
            murl, mraw = get(manifest, 200000)
            data = json.loads(mraw.decode("utf-8", "ignore"))
            name = name or data.get("short_name") or data.get("name") or ""
            for icon in data.get("icons", []):
                m = re.match(r"(\d+)x\d+", (icon.get("sizes") or "").split(" ")[0])
                cands.append((int(m.group(1)) if m else 0, urljoin(murl, icon.get("src", ""))))
        except Exception:
            pass
except Exception:
    pass

print(name)
seen = set()
for size, url in sorted(cands, key=lambda c: -c[0]):
    if url and url not in seen:
        seen.add(url)
        print(url)
PY
}

icon_ok() {
    local file="$1" width
    width="$(magick identify -quiet -format '%w\n' "$file" 2>/dev/null | sort -n | tail -n1)"
    [ -n "$width" ] && [ "$width" -ge "${2:-48}" ]
}

save_icon() {
    local src="$1" out="$2" frame
    frame="$(magick identify -quiet -format '%p %w\n' "$src" 2>/dev/null | sort -k2 -n | tail -n1 | cut -d' ' -f1)"
    magick "$src[${frame:-0}]" -background none -resize 256x256 "png:$out.part" 2>/dev/null && mv -f "$out.part" "$out"
}

fetch_icon() {
    local url="$1" host="$2" out="$3" tmp candidate bare
    mkdir -p "$ICONS"
    tmp="$out.src"
    bare="${host#www.}"
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if curl -sSL -f -m 12 -A "Mozilla/5.0" -o "$tmp" "$candidate" && icon_ok "$tmp" 96 && save_icon "$tmp" "$out"; then
            rm -f "$tmp"
            return 0
        fi
    done <<<"$PAGE_ICONS"
    for candidate in "$host" "$bare" "${bare#*.}"; do
        [ -n "$candidate" ] && [[ "$candidate" == *.* ]] || continue
        if curl -sSL -f -m 12 -o "$tmp" "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://$candidate&size=256" \
            && icon_ok "$tmp" 32 && save_icon "$tmp" "$out"; then
            rm -f "$tmp"
            return 0
        fi
    done
    rm -f "$tmp" "$out.part"
    return 1
}

create_one() {
    local raw="$1" browser url parsed slug name appid host icon file info site
    browser="$(find_browser)" || { echo "ERR no chromium or chrome found"; return 1; }
    url="$(normalize_url "$raw")" || { echo "ERR empty url"; return 1; }
    parsed="$(parse_url "$url")" || { echo "ERR invalid url: $raw"; return 1; }
    slug="$(printf '%s\n' "$parsed" | sed -n 1p)"
    name="$(printf '%s\n' "$parsed" | sed -n 2p)"
    appid="$(printf '%s\n' "$parsed" | sed -n 3p)"
    host="$(python3 -I -c 'import sys;from urllib.parse import urlparse;print(urlparse(sys.argv[1]).hostname)' "$url")"
    file="$APPS/$PREFIX$slug.desktop"
    icon="$ICONS/$slug.png"
    info="$(page_info "$url")"
    site="$(printf '%s\n' "$info" | sed -n 1p)"
    PAGE_ICONS="$(printf '%s\n' "$info" | sed -n '2,$p')"
    [ -n "$site" ] && name="$site"
    fetch_icon "$url" "$host" "$icon" || icon="applications-internet"

    mkdir -p "$APPS"
    cat > "$file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$browser --app=$url
Icon=$icon
Terminal=false
Categories=Network;
StartupWMClass=chrome-$appid-Default
X-Shell-Webapp=true
X-Shell-Webapp-Url=$url
DESKTOP
    echo "OK $slug"
}

list_all() {
    local file id name url icon items="[]"
    for file in "$APPS"/$PREFIX*.desktop; do
        [ -e "$file" ] || continue
        grep -q '^X-Shell-Webapp=true' "$file" || continue
        id="$(basename "$file" .desktop)"
        name="$(sed -n 's/^Name=//p' "$file" | head -n1)"
        url="$(sed -n 's/^X-Shell-Webapp-Url=//p' "$file" | head -n1)"
        icon="$(sed -n 's/^Icon=//p' "$file" | head -n1)"
        items="$(jq -c --arg id "$id" --arg name "$name" --arg url "$url" --arg icon "$icon" '. + [{id: $id, name: $name, url: $url, icon: $icon}]' <<<"$items")"
    done
    jq -c 'sort_by(.name | ascii_downcase)' <<<"$items"
}

remove_one() {
    local id="$1" file
    case "$id" in
        "$PREFIX"*) ;;
        *) echo "ERR not a shell webapp"; return 1 ;;
    esac
    file="$APPS/$id.desktop"
    [ -f "$file" ] && grep -q '^X-Shell-Webapp=true' "$file" || { echo "ERR not found"; return 1; }
    rm -f "$file" "$ICONS/${id#"$PREFIX"}.png"
    echo "OK $id"
}

open_one() {
    local id="$1" file url browser
    file="$APPS/$id.desktop"
    [ -f "$file" ] || { echo "ERR not found"; return 1; }
    url="$(sed -n 's/^X-Shell-Webapp-Url=//p' "$file" | head -n1)"
    browser="$(find_browser)" || { echo "ERR no chromium or chrome found"; return 1; }
    nohup "$browser" --app="$url" >/dev/null 2>&1 &
}

command="${1:-}"
shift || true
case "$command" in
    create) status=0; for url in "$@"; do create_one "$url" || status=1; done; exit "$status" ;;
    list) list_all ;;
    remove) remove_one "${1:-}" ;;
    open) open_one "${1:-}" ;;
    *) echo "usage: webapp.sh create <url>... | list | remove <id> | open <id>" >&2; exit 2 ;;
esac
