#!/usr/bin/env bash
#
# Live 10-band equalizer backend for illogical-impulse / end-4's pC fork,
# ported from ilyaMiro's Serpantinum shell.
#
# It writes a 32-band EasyEffects "Equalizer" preset (only 10 of the bands
# are user-editable, matching Serpantinum's slider layout) and loads it live
# through `easyeffects -l`.
#
# Usage:
#   equalizer.sh <state_dir> get
#   equalizer.sh <state_dir> set_band <1-10> <gainDb>
#   equalizer.sh <state_dir> set_preamp <gainDb>   (master gain, independent of the curve/preset)
#   equalizer.sh <state_dir> set_dim <0-0.85>      (blurred-art scrim darkness, UI-only, no apply needed)
#   equalizer.sh <state_dir> preview                (live-audio preview only - merges current slider
#                                                     state into a scratch preset and loads that, never
#                                                     touching the real active preset's own file)
#   equalizer.sh <state_dir> save                   (the real commit - writes into the actual active
#                                                     preset's file and reloads it)
#   equalizer.sh <state_dir> revert_preview         (discards an unsaved preview: restores STATE_FILE
#                                                     from the real active preset's saved equalizer
#                                                     block and reloads it live)
#   equalizer.sh <state_dir> apply
#   equalizer.sh <state_dir> preset <Flat|Bass|Treble|Vocal|Pop|Rock|Jazz|Classic>
#   equalizer.sh <state_dir> genre_tags <artist>   (cache-first Last.fm artist.getTopTags
#                                                     lookup, requires <state_dir>/lastfm_api_key
#                                                     to exist)
#   equalizer.sh <state_dir> track_genre_tags <artist> <track>
#                                                   (same, but Last.fm track.getTopTags for the
#                                                     specific track - genre-crossing artists get
#                                                     tags that describe their whole catalog from
#                                                     genre_tags alone, this narrows it down to
#                                                     the song actually playing. Often empty, since
#                                                     far fewer tracks than artists get tagged -
#                                                     the QML side treats that as "no opinion" and
#                                                     falls back to genre_tags rather than erroring)
#   equalizer.sh <state_dir> get_lastfm_key        (prints the saved key, or nothing)
#   equalizer.sh <state_dir> set_lastfm_key <key>  (writes it; empty arg clears it)
#   equalizer.sh <state_dir> list_presets           (JSON array of EasyEffects preset names
#                                                     actually saved in PRESET_DIR, so the UI
#                                                     can offer a picker instead of guessing)
#   equalizer.sh <state_dir> get_active_preset      (name of the preset the equalizer merges into)
#   equalizer.sh <state_dir> set_active_preset <n>  (switch which preset it merges into)
#   equalizer.sh <state_dir> create_preset <n>      (make a brand-new preset from scratch and
#                                                     switch to it - refuses if <n> already exists)
#   equalizer.sh <state_dir> delete_preset <n>       (delete a saved EasyEffects preset file from
#                                                     PRESET_DIR - refuses if <n> is the active preset
#                                                     or doesn't exist on disk)
#
# <state_dir> is expected to be Directories.eqStateDir from the QML side
# (e.g. ~/.local/state/quickshell/user/eq), passed in so this script never
# has to guess XDG paths itself.

set -u

STATE_DIR="$1"; shift
cmd="${1:-}"; arg1="${2:-}"; arg2="${3:-}"

mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/eq_state.json"

# EasyEffects >= 8.0 (Qt/Kirigami port) moved presets from
# ~/.config/easyeffects/output to $XDG_DATA_HOME/easyeffects/output
# (usually ~/.local/share/easyeffects/output), migrating existing files
# on first launch of the new version. Blindly writing to the old
# ~/.config path keeps recreating it, which confuses that migration
# logic (EasyEffects finds "new" files in a directory it already
# thinks it migrated away from) and has been observed to crash the app,
# e.g. when creating a new preset. Detect whichever directory the
# installed EasyEffects is actually using instead of assuming.
EE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects"
EE_CONFIG_DIR="$HOME/.config/easyeffects"
if [ -d "$EE_DATA_DIR/output" ]; then
    # >= 8.0: already migrated, this is the live directory.
    PRESET_DIR="$EE_DATA_DIR/output"
elif [ -d "$EE_CONFIG_DIR/output" ]; then
    # < 8.0 (GTK4), or >= 8.0 that hasn't been launched yet and hasn't
    # migrated - either way this is the directory currently in use.
    PRESET_DIR="$EE_CONFIG_DIR/output"
else
    # EasyEffects has never been launched at all yet. Default to the
    # current (>= 8.0) location so we don't seed the legacy directory.
    PRESET_DIR="$EE_DATA_DIR/output"
fi

CUSTOM_PRESETS_FILE="$STATE_DIR/custom_presets.json"
AUTO_FILE="$STATE_DIR/auto_eq_enabled"
# Genre-aware auto-EQ: neither Spotify's nor a browser's MPRIS metadata
# expose genre, so this looks it up by artist name via Last.fm's
# artist.gettoptags API instead, and caches the result locally so we're
# not hitting the network on every replay of an already-seen artist.
# LASTFM_KEY_FILE is intentionally just a path, not a value - drop your
# own free API key (from https://www.last.fm/api/account/create) in a
# plain text file at that path. Nothing here ever hardcodes a key, so
# this script is safe to share/version-control as-is.
GENRE_CACHE_FILE="$STATE_DIR/genre_cache.json"
# Separate from GENRE_CACHE_FILE (which is keyed by artist name alone) since
# this is keyed by artist+track together - a flat "artist\x1ftrack" string
# key, using \x1f (ASCII unit separator) as the join character since it's
# vanishingly unlikely to appear in a real artist or track name, unlike "-"
# or ":" which plenty of track titles already contain.
TRACK_GENRE_CACHE_FILE="$STATE_DIR/track_genre_cache.json"
LASTFM_KEY_FILE="$STATE_DIR/lastfm_api_key"
# Set to 'true' by apply_eq() when it refuses to touch a never-saved
# preset file, so the UI can tell the user to save their current
# EasyEffects setup first instead of the widget silently doing nothing.
NEEDS_SAVE_FILE="$STATE_DIR/needs_manual_save"
# Name of the EasyEffects output preset the equalizer merges into - i.e.
# whatever preset holds the *rest* of your chain (compressor, limiter,
# deesser, etc). Defaults to "output" purely as a guess (EasyEffects does
# NOT actually create a preset with that name on its own - presets are
# always user-named), so this is very likely wrong until you point it at
# whichever preset your own chain actually lives under, either via
# `set_active_preset <name>` or the picker in the equalizer widget (see
# list_presets below for what that picker is populated from).
ACTIVE_PRESET_FILE="$STATE_DIR/active_preset"

mkdir -p "$PRESET_DIR"

if [ ! -f "$CUSTOM_PRESETS_FILE" ]; then
    echo '{}' > "$CUSTOM_PRESETS_FILE"
fi

if [ ! -f "$GENRE_CACHE_FILE" ]; then
    echo '{}' > "$GENRE_CACHE_FILE"
fi

if [ ! -f "$TRACK_GENRE_CACHE_FILE" ]; then
    echo '{}' > "$TRACK_GENRE_CACHE_FILE"
fi

if [ ! -f "$AUTO_FILE" ]; then
    echo 'false' > "$AUTO_FILE"
fi

if [ ! -f "$NEEDS_SAVE_FILE" ]; then
    echo 'false' > "$NEEDS_SAVE_FILE"
fi

if [ ! -f "$ACTIVE_PRESET_FILE" ]; then
    echo 'output' > "$ACTIVE_PRESET_FILE"
fi

if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "preamp": 0, "dim": 0.3, "pending": false}' > "$STATE_FILE"
fi

apply_custom_preset() {
    local name="$1"
    local vals current_preamp current_dim
    vals=$(jq -c --arg n "$name" '.[$n] // empty' "$CUSTOM_PRESETS_FILE")
    [ -n "$vals" ] || exit 1
    # Preamp is a master control independent of which curve is active -
    # carry it forward instead of letting it reset to 0 just because the
    # preset switched. Same reasoning for dim - it's a UI/background
    # setting, not part of the curve's identity.
    current_preamp=$(jq -r '.preamp // 0' "$STATE_FILE" 2>/dev/null)
    case "$current_preamp" in ''|null) current_preamp=0 ;; esac
    current_dim=$(jq -r '.dim // 0.3' "$STATE_FILE" 2>/dev/null)
    case "$current_dim" in ''|null) current_dim=0.3 ;; esac
    echo "$vals" | jq -c '{b1:.b1,b2:.b2,b3:.b3,b4:.b4,b5:.b5,b6:.b6,b7:.b7,b8:.b8,b9:.b9,b10:.b10,preset:$name,preamp:($preamp|tonumber),dim:($dim|tonumber),pending:false}' \
        --arg name "$name" --arg preamp "$current_preamp" --arg dim "$current_dim" > "$STATE_FILE"
    apply_eq
}

# Shared by genre_tags/track_genre_tags below. Prints a JSON array of tag
# names (possibly "[]") for the given Last.fm method+params; never errors
# out to stderr-visible failure - a bad/missing key, no network, or an
# unrecognized artist/track all just come back as "[]" so the caller can
# treat "found nothing" uniformly.
lastfm_toptags() {
    local method="$1" api_key="$2"; shift 2
    local qs="method=${method}&api_key=${api_key}&format=json"
    while [ "$#" -gt 0 ]; do
        qs="${qs}&$1=$(jq -rn --arg v "$2" '$v|@uri')"
        shift 2
    done
    local resp tags
    resp=$(curl -fsS --max-time 5 "https://ws.audioscrobbler.com/2.0/?${qs}" 2>/dev/null)
    tags=$(echo "$resp" | jq -c '[.toptags.tag[]?.name]' 2>/dev/null)
    if [ -z "$tags" ] || [ "$tags" = "null" ]; then
        tags='[]'
    fi
    echo "$tags"
}

# Spotify (and MPRIS more generally) often reports a collab track's artist
# as one joined string - "Drake, 21 Savage", "Artist feat. Someone Else",
# "A & B" - which usually isn't a real Last.fm artist page on its own, even
# though every individual name in it is. Prints just the first-listed name,
# unchanged if there was nothing to strip (a normal single-artist string
# passes straight through). Used as a fallback, not the primary lookup -
# see genre_tags below - so a genuinely separate act named e.g. "Simon &
# Garfunkel" is tried as-is first and never needs this at all.
strip_featured_artists() {
    printf '%s' "$1" \
        | sed -E 's/[[:space:]]*,.*//' \
        | sed -E 's/[[:space:]]+&[[:space:]].*//' \
        | sed -E 's/[[:space:]]+([fF]eat(uring)?|[fF]t)\.?[[:space:]].*//' \
        | sed -E 's/[[:space:]]+[xX][[:space:]].*//' \
        | sed -E 's/[[:space:]]+[vV]s\.?[[:space:]].*//'
}

apply_eq() {
    # force_create=1 means "yes, really create this preset from scratch" -
    # only ever passed by create_preset below, which itself only runs for
    # a name confirmed not to exist yet (see there for why this is safe to
    # gate behind an explicit flag rather than just checking file
    # existence here: the real risk isn't the file, it's replacing
    # whatever's currently live in EasyEffects, which can happen either way).
    local force_create="${1:-0}"
    # target_name lets a caller write the merged result somewhere OTHER
    # than the real active preset and load THAT instead - used by
    # apply_eq_preview() below so live-dragging a slider can be heard
    # immediately without touching (and risking corrupting) a real,
    # possibly hand-crafted preset until the user explicitly saves.
    # Defaults to the real active preset, i.e. today's original behavior.
    local target_name="${2:-}"
    vals=$(cat "$STATE_FILE")
    active_preset=$(cat "$ACTIVE_PRESET_FILE" 2>/dev/null)
    [ -n "$active_preset" ] || active_preset="output"
    active_preset_path="$PRESET_DIR/${active_preset}.json"
    write_name="${target_name:-$active_preset}"
    write_path="$PRESET_DIR/${write_name}.json"

    # Merge into whatever preset is actually the active one instead of
    # loading a scratch preset that only contains the equalizer - loading a
    # preset in EasyEffects replaces the *entire* pipeline, so a preset with
    # only 'equalizer' in plugins_order was silently dropping every other
    # effect (compressor, limiter, deesser, ...) the user had running. This
    # reads the existing preset file, leaves every other plugin's block
    # exactly as-is, and only adds/updates the 'equalizer' entry (and makes
    # sure 'equalizer' is present in plugins_order without disturbing the
    # rest of that list), then writes to write_path (the SAME file as the
    # source unless a preview target_name was passed) and reloads write_name -
    # so the other effects stay loaded either way.
    python3 -c "
import sys, json, os

state_json, preset_path, write_path, force_create = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == '1'

try:
    data = json.loads(state_json)
    # 10 user-facing sliders -> spread across a 32-band IIR equalizer,
    # same mapping Serpantinum uses so presets/behaviour stay identical.
    slider_map = { 0:0, 1:3, 2:6, 3:9, 4:12, 5:15, 6:18, 7:21, 8:24, 9:27 }
    freqs = [32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000, 22000, 24000, 24000]
    gains = [float(data['b1']), float(data['b2']), float(data['b3']), float(data['b4']), float(data['b5']), float(data['b6']), float(data['b7']), float(data['b8']), float(data['b9']), float(data['b10'])]
    # Master gain layered on top of the 10 bands - compensates for
    # headroom lost when several bands are boosted, instead of just
    # clipping. Falls back to 0 for state files saved before this existed.
    preamp = float(data.get('preamp', 0))
    bands = {}
    for i in range(32):
        freq = freqs[i] if i < len(freqs) else 20000.0
        gain = 0.0
        for s_idx, b_idx in slider_map.items():
            if i == b_idx:
                gain = gains[s_idx]
                break
        bands[f'band{i}'] = { 'frequency': freq, 'gain': gain, 'type': 'Bell', 'mode': 'RLC (BT)', 'mute': False, 'q': 1.0, 'solo': False, 'width': 4.0, 'slope': 'x1' }
    eq_block = { 'balance': 0.0, 'bypass': False, 'input-gain': 0.0, 'output-gain': preamp, 'left': bands, 'right': bands, 'mode': 'IIR', 'num-bands': 32, 'split-channels': False }

    try:
        with open(preset_path) as f:
            preset = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        preset = {}

    # EasyEffects only writes your live settings to this file when you
    # explicitly hit Save in its own UI - changing something live does
    # NOT update the file on disk. So if this file has never been saved
    # (doesn't exist, or has no 'output'/plugins_order yet), any other
    # effects you've configured live (Crystalizer, compressor, whatever)
    # only exist in the running EasyEffects session, not here. Loading a
    # preset replaces the ENTIRE live pipeline with what's in the file -
    # if we built and loaded an equalizer-only preset right now, it would
    # silently erase everything else you have running. Bail out instead:
    # leave the file untouched, and let the caller (equalizer.sh) know so
    # it can tell you to save your current setup first. force_create skips
    # this bail-out - only create_preset sets it, and only after the UI has
    # explicitly warned that this will replace whatever's currently live.
    existing_output = preset.get('output')
    if not force_create and (not existing_output or not existing_output.get('plugins_order')):
        sys.exit(3)

    output = preset.setdefault('output', {})
    output.setdefault('blocklist', [])
    plugins_order = output.setdefault('plugins_order', [])

    # EasyEffects always names plugin instances with a '#N' suffix, even
    # the first/only one (e.g. 'equalizer#0') - never a bare 'equalizer'.
    # This used to write a bare 'equalizer' key, which didn't match a
    # real EasyEffects-created instance name. Result: if you ever added
    # an Equalizer yourself through EasyEffects' own GUI and saved that
    # preset, the file ended up with BOTH 'equalizer#0' (yours) and
    # 'equalizer' (this script's) in plugins_order - two separate
    # equalizers stacked in series, which is what caused the duplicate
    # entry and the extreme volume.
    eq_key = None
    for name in plugins_order:
        if name == 'equalizer' or name.startswith('equalizer#'):
            eq_key = name
            break

    if eq_key == 'equalizer':
        # Self-heal: migrate the old wrong name to a real one instead of
        # leaving a mismatched duplicate around.
        plugins_order[plugins_order.index('equalizer')] = 'equalizer#0'
        eq_key = 'equalizer#0'
    elif eq_key is None:
        eq_key = 'equalizer#0'
        plugins_order.append(eq_key)

    # Clean up any stray bare 'equalizer' entry left over from a previous
    # run of the old buggy version (e.g. if a real 'equalizer#0' already
    # existed separately, the loop above would have picked that one,
    # leaving this dangling bad entry behind).
    if 'equalizer' in plugins_order and eq_key != 'equalizer':
        plugins_order[:] = [p for p in plugins_order if p != 'equalizer']
    if 'equalizer' in output and eq_key != 'equalizer':
        del output['equalizer']

    output[eq_key] = eq_block

    # Write atomically: EasyEffects watches this file (and reads it as a
    # template when creating a new preset). Writing in place truncates it
    # first, so a watcher/reader can catch it mid-write and see corrupt or
    # empty JSON - this has been observed to crash EasyEffects >= 8.0.
    # Writing to a temp file in the same directory and renaming into place
    # means EasyEffects only ever sees the old complete file or the new
    # complete file, never a partial one.
    tmp_path = write_path + '.tmp'
    with open(tmp_path, 'w') as f:
        json.dump(preset, f, indent=4)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp_path, write_path)
except Exception:
    sys.exit(1)
" "$vals" "$active_preset_path" "$write_path" "$force_create"
    py_status=$?

    if [ "$py_status" -eq 3 ]; then
        # Never-saved preset detected - the file above was left untouched
        # on purpose. Flag it so the UI can tell you to save your current
        # EasyEffects setup first, and skip the reload: there's nothing
        # new to load, and force-reloading here is exactly what would
        # wipe unsaved live effects.
        echo 'true' > "$NEEDS_SAVE_FILE"
        return 0
    fi
    echo 'false' > "$NEEDS_SAVE_FILE"

    easyeffects -l "$write_name" >/dev/null 2>&1 &
}

# Live-preview variant of apply_eq() - merges the current slider state into
# a copy of the real active preset (so every other effect is preserved)
# but writes that copy to a scratch preset name and loads THAT, instead of
# touching the real preset's own file. Used by the "preview" command below,
# which is what dragging a band/preamp slider now triggers (debounced) -
# you hear the change immediately, but nothing about your actual saved
# preset changes until you explicitly hit Save.
LIVE_PREVIEW_NAME="_eq_live_preview"
apply_eq_preview() {
    apply_eq 0 "$LIVE_PREVIEW_NAME"
}

# Undoes whatever apply_eq_preview() above has been previewing: pulls the
# equalizer's band gains and output-gain straight back out of the REAL
# active preset's own saved file (which preview never touched) into
# STATE_FILE, so the sliders next time the popup opens match what's
# actually saved - then reloads the real preset live, discarding the
# scratch preview. Called when the popup closes without an explicit Save,
# so previewing a change and backing out never leaves you (a) listening to
# an unsaved tweak with no on-screen indication, or (b) with EasyEffects'
# own "currently loaded preset" left pointed at the scratch file.
revert_preview() {
    active_preset=$(cat "$ACTIVE_PRESET_FILE" 2>/dev/null)
    [ -n "$active_preset" ] || active_preset="output"
    active_preset_path="$PRESET_DIR/${active_preset}.json"

    restored=$(python3 -c "
import sys, json

preset_path = sys.argv[1]
slider_map = { 0:0, 1:3, 2:6, 3:9, 4:12, 5:15, 6:18, 7:21, 8:24, 9:27 }

try:
    with open(preset_path) as f:
        preset = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    preset = {}

output = preset.get('output', {})
plugins_order = output.get('plugins_order', [])
eq_key = None
for name in plugins_order:
    if name == 'equalizer' or name.startswith('equalizer#'):
        eq_key = name
        break

# No equalizer saved in this preset yet - nothing to revert to but flat.
if eq_key is None or eq_key not in output:
    print(json.dumps({'bands': [0]*10, 'preamp': 0}))
    sys.exit(0)

eq_block = output[eq_key]
bands_src = eq_block.get('left', {})
bands = []
for s_idx in range(10):
    b_idx = slider_map[s_idx]
    band = bands_src.get(f'band{b_idx}', {})
    bands.append(band.get('gain', 0))
preamp = eq_block.get('output-gain', 0)
print(json.dumps({'bands': bands, 'preamp': preamp}))
" "$active_preset_path")

    tmp=$(cat "$STATE_FILE")
    updated=$(echo "$tmp" | jq -c --argjson r "$restored" \
        '.b1=($r.bands[0]|tostring) | .b2=($r.bands[1]|tostring) | .b3=($r.bands[2]|tostring) | .b4=($r.bands[3]|tostring) | .b5=($r.bands[4]|tostring) | .b6=($r.bands[5]|tostring) | .b7=($r.bands[6]|tostring) | .b8=($r.bands[7]|tostring) | .b9=($r.bands[8]|tostring) | .b10=($r.bands[9]|tostring) | .preamp=($r.preamp|tostring) | .preset="Custom" | .pending=false')
    echo "$updated" > "$STATE_FILE"

    easyeffects -l "$active_preset" >/dev/null 2>&1 &
}

save_preset() {
    local current_preamp current_dim
    current_preamp=$(jq -r '.preamp // 0' "$STATE_FILE" 2>/dev/null)
    case "$current_preamp" in ''|null) current_preamp=0 ;; esac
    current_dim=$(jq -r '.dim // 0.3' "$STATE_FILE" 2>/dev/null)
    case "$current_dim" in ''|null) current_dim=0.3 ;; esac
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" --arg preamp "$current_preamp" --arg dim "$current_dim" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "preamp": ($preamp|tonumber), "dim": ($dim|tonumber), "pending": false}' > "$STATE_FILE"
}

case "$cmd" in
    "get") cat "$STATE_FILE" ;;
    "set_band")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "set_preamp")
        # Doesn't touch .preset - preamp is a master gain layered on top
        # of whichever curve is active, not part of the curve's identity.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg1" ".preamp = \$val | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "set_dim")
        # Purely a UI/background setting (how dark the blurred-art scrim
        # sits behind the popup) - unlike set_preamp, this never touches
        # .pending. There's nothing for EasyEffects to apply; writing it
        # straight through is the whole job.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg1" ".dim = \$val")
        echo "$updated" > "$STATE_FILE"
        ;;
    "save")
        # The real commit: writes the current slider state into the
        # actual active preset's own file and reloads it live. Only ever
        # triggered by the user explicitly hitting Save now - dragging a
        # slider triggers "preview" below instead, which never touches
        # this file.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "preview")
        # Debounced live-audio preview while dragging a band/preamp
        # slider - see apply_eq_preview() above. Deliberately does NOT
        # touch .pending: the change is audible now, but still unsaved
        # until "save" runs, and the UI's Save pill should keep saying so.
        apply_eq_preview
        ;;
    "revert_preview")
        # Popup closed without an explicit Save - discard whatever's been
        # previewing and go back to the real saved preset. See
        # revert_preview() above.
        revert_preview
        ;;
    "preset")
        case "$arg1" in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
            *) apply_custom_preset "$arg1"; exit $? ;;
        esac
        apply_eq
        ;;
    "get_auto") cat "$AUTO_FILE" ;;
    "set_auto")
        if [ "$arg1" = "true" ] || [ "$arg1" = "1" ]; then
            echo 'true' > "$AUTO_FILE"
        else
            echo 'false' > "$AUTO_FILE"
        fi
        ;;
    "get_custom") cat "$CUSTOM_PRESETS_FILE" ;;
    "save_custom")
        name="$arg1"
        shift 2
        vals=("$@")
        [ -n "$name" ] || exit 1
        jq -n --argjson old "$(cat "$CUSTOM_PRESETS_FILE")" \
            --arg n "$name" \
            --arg b1 "${vals[0]:-0}" --arg b2 "${vals[1]:-0}" --arg b3 "${vals[2]:-0}" --arg b4 "${vals[3]:-0}" --arg b5 "${vals[4]:-0}" \
            --arg b6 "${vals[5]:-0}" --arg b7 "${vals[6]:-0}" --arg b8 "${vals[7]:-0}" --arg b9 "${vals[8]:-0}" --arg b10 "${vals[9]:-0}" \
            '$old + {($n): {b1:($b1|tonumber),b2:($b2|tonumber),b3:($b3|tonumber),b4:($b4|tonumber),b5:($b5|tonumber),b6:($b6|tonumber),b7:($b7|tonumber),b8:($b8|tonumber),b9:($b9|tonumber),b10:($b10|tonumber)}}' > "$CUSTOM_PRESETS_FILE.tmp" && mv "$CUSTOM_PRESETS_FILE.tmp" "$CUSTOM_PRESETS_FILE"
        save_preset "${vals[0]:-0}" "${vals[1]:-0}" "${vals[2]:-0}" "${vals[3]:-0}" "${vals[4]:-0}" "${vals[5]:-0}" "${vals[6]:-0}" "${vals[7]:-0}" "${vals[8]:-0}" "${vals[9]:-0}" "$name"
        apply_eq
        ;;
    "delete_custom")
        jq --arg n "$arg1" 'del(.[$n])' "$CUSTOM_PRESETS_FILE" > "$CUSTOM_PRESETS_FILE.tmp" && mv "$CUSTOM_PRESETS_FILE.tmp" "$CUSTOM_PRESETS_FILE"
        ;;
    "get_active_preset") cat "$ACTIVE_PRESET_FILE" ;;
    "get_needs_save") cat "$NEEDS_SAVE_FILE" ;;
    "list_presets")
        # Real preset names actually saved on disk, so the UI can offer a
        # picker instead of guessing "output" and hoping it's right - see
        # the ACTIVE_PRESET_FILE comment above for why that guess so often
        # isn't. Empty/no PRESET_DIR just yields an empty list rather than
        # erroring, e.g. before EasyEffects has ever been launched.
        # $LIVE_PREVIEW_NAME is this script's own scratch file (see
        # apply_eq_preview() above), never a real user preset - excluded
        # so it never shows up as something to pick or switch to.
        if [ -d "$PRESET_DIR" ]; then
            find "$PRESET_DIR" -maxdepth 1 -type f -name '*.json' ! -name "${LIVE_PREVIEW_NAME}.json" -exec basename {} .json \; \
                | jq -R . | jq -cs 'sort'
        else
            echo '[]'
        fi
        ;;
    "set_active_preset")
        [ -n "$arg1" ] || exit 1
        # This name now flows straight into a filesystem path
        # ($PRESET_DIR/${active_preset}.json) and comes from free-typed UI
        # input rather than only ever a hardcoded/internal value, so guard
        # against a name that could escape PRESET_DIR (e.g. "../../foo") or
        # otherwise isn't a plain preset name.
        case "$arg1" in
            */*|*..*)
                echo "Invalid preset name: must not contain '/' or '..'" >&2
                exit 1
                ;;
        esac
        echo "$arg1" > "$ACTIVE_PRESET_FILE"
        apply_eq
        ;;
    "create_preset")
        # Spin up a brand-new EasyEffects preset containing just the
        # equalizer, then switch to it. Deliberately a separate command
        # from set_active_preset (rather than just letting a nonexistent
        # name auto-create): switching to it force-reloads EasyEffects,
        # which replaces whatever's CURRENTLY live - discarding any
        # unsaved changes to your other effects regardless of which
        # preset they're nominally under. The UI should only call this
        # after warning the user about exactly that, not the moment
        # they type an unrecognized name.
        name="$arg1"
        [ -n "$name" ] || exit 1
        case "$name" in
            */*|*..*)
                echo "Invalid preset name: must not contain '/' or '..'" >&2
                exit 1
                ;;
        esac
        target="$PRESET_DIR/${name}.json"
        if [ -e "$target" ]; then
            echo "Preset '$name' already exists - use set_active_preset instead." >&2
            exit 1
        fi
        echo "$name" > "$ACTIVE_PRESET_FILE"
        apply_eq 1
        ;;
    "delete_preset")
        # Deletes a real EasyEffects preset file from PRESET_DIR - distinct
        # from delete_custom above, which only ever removes an entry from
        # this script's own CUSTOM_PRESETS_FILE (a saved 10-band curve),
        # never a real EasyEffects preset on disk.
        name="$arg1"
        [ -n "$name" ] || exit 1
        # Same path-escape guard as set_active_preset/create_preset above -
        # this also flows straight into $PRESET_DIR/${name}.json.
        case "$name" in
            */*|*..*)
                echo "Invalid preset name: must not contain '/' or '..'" >&2
                exit 1
                ;;
        esac
        active_preset=$(cat "$ACTIVE_PRESET_FILE" 2>/dev/null)
        [ -n "$active_preset" ] || active_preset="output"
        if [ "$name" = "$active_preset" ]; then
            # Deleting the preset the equalizer currently merges into would
            # leave ACTIVE_PRESET_FILE pointing at nothing - apply_eq would
            # then either bail out (no plugins_order to preserve) or, worse,
            # silently start a fresh file. Make the user switch away first.
            echo "Cannot delete '$name' - it's the active preset. Switch to a different one first." >&2
            exit 1
        fi
        target="$PRESET_DIR/${name}.json"
        if [ ! -e "$target" ]; then
            echo "Preset '$name' does not exist." >&2
            exit 1
        fi
        rm -f "$target"
        ;;
    "genre_tags")
        # Returns a JSON array of Last.fm tags for arg1 (an artist name),
        # e.g. ["thrash metal","metal","80s"]. The QML side maps those to
        # a preset itself; this only fetches+caches the raw tags, since
        # neither Spotify nor a browser's MPRIS metadata expose genre.
        artist="$arg1"
        if [ -z "$artist" ]; then
            echo '[]'
            exit 0
        fi
        cached=$(jq -c --arg a "$artist" '.[$a] // empty' "$GENRE_CACHE_FILE" 2>/dev/null)
        if [ -n "$cached" ]; then
            echo "$cached"
            exit 0
        fi
        # No key file -> no lookup, fail quiet (no crash, no spam), rather
        # than erroring every time someone hasn't set this up.
        if [ ! -f "$LASTFM_KEY_FILE" ]; then
            echo '[]'
            exit 0
        fi
        api_key=$(tr -d '[:space:]' < "$LASTFM_KEY_FILE")
        if [ -z "$api_key" ]; then
            echo '[]'
            exit 0
        fi
        tags=$(lastfm_toptags "artist.gettoptags" "$api_key" artist "$artist")
        if [ "$tags" = "[]" ]; then
            primary=$(strip_featured_artists "$artist")
            if [ "$primary" != "$artist" ] && [ -n "$primary" ]; then
                tags=$(lastfm_toptags "artist.gettoptags" "$api_key" artist "$primary")
            fi
        fi
        # Cache even a miss/empty result, so an unrecognized or misspelled
        # artist doesn't get re-queried on every single track change.
        jq --arg a "$artist" --argjson t "$tags" '. + {($a): $t}' "$GENRE_CACHE_FILE" > "$GENRE_CACHE_FILE.tmp" 2>/dev/null \
            && mv "$GENRE_CACHE_FILE.tmp" "$GENRE_CACHE_FILE"
        echo "$tags"
        ;;
    "track_genre_tags")
        # Track-scoped counterpart to genre_tags above, via Last.fm's
        # track.getTopTags - see the usage comment at the top of this file
        # for why this exists alongside the artist-level lookup rather than
        # instead of it.
        artist="$arg1"
        track="$arg2"
        if [ -z "$artist" ] || [ -z "$track" ]; then
            echo '[]'
            exit 0
        fi
        cache_key="${artist}"$'\x1f'"${track}"
        cached=$(jq -c --arg k "$cache_key" '.[$k] // empty' "$TRACK_GENRE_CACHE_FILE" 2>/dev/null)
        if [ -n "$cached" ]; then
            echo "$cached"
            exit 0
        fi
        if [ ! -f "$LASTFM_KEY_FILE" ]; then
            echo '[]'
            exit 0
        fi
        api_key=$(tr -d '[:space:]' < "$LASTFM_KEY_FILE")
        if [ -z "$api_key" ]; then
            echo '[]'
            exit 0
        fi
        tags=$(lastfm_toptags "track.gettoptags" "$api_key" artist "$artist" track "$track")
        if [ "$tags" = "[]" ]; then
            primary=$(strip_featured_artists "$artist")
            if [ "$primary" != "$artist" ] && [ -n "$primary" ]; then
                tags=$(lastfm_toptags "track.gettoptags" "$api_key" artist "$primary" track "$track")
            fi
        fi
        # Cache even an empty result - most individual tracks have no tags
        # at all on Last.fm, and we don't want to re-hit the API for that
        # same track every time it comes back around in a playlist.
        jq --arg k "$cache_key" --argjson t "$tags" '. + {($k): $t}' "$TRACK_GENRE_CACHE_FILE" > "$TRACK_GENRE_CACHE_FILE.tmp" 2>/dev/null \
            && mv "$TRACK_GENRE_CACHE_FILE.tmp" "$TRACK_GENRE_CACHE_FILE"
        echo "$tags"
        ;;
    "clear_genre_cache")
        echo '{}' > "$GENRE_CACHE_FILE"
        echo '{}' > "$TRACK_GENRE_CACHE_FILE"
        ;;
    "get_lastfm_key")
        # Echoes back whatever's on disk so the UI field can be
        # pre-filled for editing. Same trust boundary as reading the
        # file directly - it already lives in the user's own state dir.
        if [ -f "$LASTFM_KEY_FILE" ]; then
            tr -d '[:space:]' < "$LASTFM_KEY_FILE"
        fi
        ;;
    "set_lastfm_key")
        # Empty/missing arg1 clears it (lets the UI have a "remove key" path).
        if [ -z "$arg1" ]; then
            rm -f "$LASTFM_KEY_FILE"
        else
            printf '%s' "$arg1" > "$LASTFM_KEY_FILE"
            chmod 600 "$LASTFM_KEY_FILE"
        fi
        ;;
    *)
        echo "Usage: equalizer.sh <state_dir> <get|set_band|apply|preset> [args...]" >&2
        exit 1
        ;;
esac
