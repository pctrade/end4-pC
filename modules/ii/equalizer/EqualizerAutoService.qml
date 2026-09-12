pragma Singleton
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Owns "Auto" genre-follow: watching for track changes, looking up genre
// tags, and switching the EQ preset to match. This used to live inside
// EqualizerView.qml, but that view is only instantiated while the
// equalizer popup is open (see the Loader in EqualizerPopup.qml gated on
// GlobalStates.equalizerOpen) - so the Connections/Process chain that makes
// Auto actually follow the currently playing track only existed while you
// had the popup open, and died the moment you closed it. Living here
// instead means Auto keeps following track changes in the background
// regardless of whether the popup is open, same as any other always-on
// service singleton (MprisController, etc).
//
// EqualizerView.qml should now just read/display root.autoEnabled and call
// root.toggleAuto()/root.maybeLookupGenre() rather than owning any of this
// state itself.
Singleton {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer

    // Restricts which player Auto is even willing to react to - e.g. so a
    // random video in some other app playing in the background doesn't
    // yank the EQ around. Matched case-insensitively as a substring against
    // MprisPlayer.identity (the standard MPRIS "human-readable app name"
    // property, e.g. "Spotify", "Firefox", "Chromium"). Leave empty to fall
    // back to the old behavior of reacting to whatever player is active.
    //
    // NOTE: verify "spotify"/"firefox" are actually what your setup reports
    // before relying on this - identity strings vary a bit by distro
    // packaging. Quickest way to check: `playerctl -p spotify metadata`
    // and `playerctl -p firefox metadata` while each is playing, or peek at
    // `busctl --user list | grep mpris` for the exact bus names running.
    readonly property var allowedPlayerIdentities: ["spotify", "firefox"]

    // For an identity in this map, Auto also requires the current track's
    // page/source URL to come from one of the listed hosts before it'll
    // react - e.g. so Firefox playing Bandcamp/SoundCloud/a podcast in
    // another tab doesn't count as "watching YouTube".
    //
    // Confirmed against real `playerctl -p firefox metadata` output: there's
    // no dedicated URL property on MprisPlayer (and Firefox doesn't
    // populate trackArtUrl at all), but the raw `metadata` map Quickshell
    // exposes alongside it does carry "xesam:url" - Firefox mirrors the
    // page URL there, and it showed "https://www.youtube.com/" while a
    // YouTube tab was playing. That's what this checks against.
    readonly property var domainRestrictedIdentities: ({
        "firefox": ["youtube.com"]
    })

    // True if `p` is a player Auto is allowed to react to at all, per the
    // two properties above.
    function isEligiblePlayer(p) {
        if (!p) return false
        const identity = (p.identity ?? "").toLowerCase()
        if (root.allowedPlayerIdentities.length > 0 &&
            !root.allowedPlayerIdentities.some(id => identity.includes(id))) {
            return false
        }
        for (const key in root.domainRestrictedIdentities) {
            if (!identity.includes(key)) continue
            const hosts = root.domainRestrictedIdentities[key]
            const pageUrl = String(p.metadata?.["xesam:url"] ?? "").toLowerCase()
            return hosts.some(host => pageUrl.includes(host))
        }
        return true
    }

    property bool autoEnabled: false
    // Avoids re-querying (network + cache reads) on every metadata blip for
    // the same song - only look up again once the artist+track pair
    // actually changes. Keyed on both (not just artist, like this used to
    // be) since track-level tags below need to re-fetch per track, not
    // just per artist.
    property string lastLookupKey: ""
    // Raw tag lists from the two lookups below, kept around so whichever
    // Process finishes second can score against both together rather than
    // each trying to decide the preset on its own from partial info. Reset
    // to empty at the start of every new lookup (see maybeLookupGenre()).
    property var lastArtistTags: []
    property var lastTrackTags: []
    // Mirrors the preset currently applied, so a genre lookup that resolves
    // to the preset that's already active is a no-op instead of reloading
    // EasyEffects redundantly. Seeded from the backend on startup and kept
    // in sync whenever this service applies a preset itself; a preset
    // change made manually in the UI while the popup is open is picked up
    // next time refresh() runs (see EqualizerView.qml's refresh()/applyPreset()).
    property string currentPresetName: "Flat"

    // Genre-aware Auto EQ: neither Spotify nor a browser exposes genre over
    // MPRIS, so equalizer.sh looks up genre tags via Last.fm instead (see
    // genre_tags/track_genre_tags in that script). This maps those (messy,
    // crowdsourced) tags to one of our presets by substring.
    //
    // Unlike the old "first tag that matches anything wins" approach, every
    // tag in the list gets to vote (see scoreTagGroup()/presetForTags()
    // below) - so one noisy or overly-generic top tag (Last.fm's tag lists
    // are full of non-genre stuff like decades, nationalities, "seen live",
    // "male vocalists", etc.) can no longer single-handedly decide the
    // preset, and a genre only wins if it actually has the strongest
    // support across the tag list.
    //
    // Grouped by target preset for readability. Within a tag string,
    // whichever key is found first (iterating in the order below) is the
    // one that counts, so a more specific compound key needs to come
    // before a broader one only when they'd otherwise disagree on the
    // target preset (e.g. "trip hop" must be listed - and resolved to
    // Jazz - before it could ever fall through to "hip hop"/Bass; it
    // doesn't actually contain that substring, but the same caution
    // applies to any new keys added here).
    readonly property var genreTagPresetMap: ({
        // Rock and its harder/punkier relatives.
        "metal": "Rock", "punk": "Rock", "grunge": "Rock",
        "emo": "Rock", "screamo": "Rock", "ska": "Rock", "rock": "Rock",
        // Orchestral / acoustic-ensemble genres.
        "classical": "Classic", "orchestra": "Classic", "orchestral": "Classic",
        "opera": "Classic", "baroque": "Classic", "symphony": "Classic", "soundtrack": "Classic",
        // Jazz, plus other mellow/low-peak genres that suit its gentle curve.
        "jazz": "Jazz", "blues": "Jazz", "swing": "Jazz", "bossa nova": "Jazz",
        "lounge": "Jazz", "trip hop": "Jazz", "ambient": "Jazz", "chillout": "Jazz",
        "downtempo": "Jazz", "lo-fi": "Jazz", "lofi": "Jazz",
        // Bass-forward / rhythm-driven genres.
        "hip hop": "Bass", "hip-hop": "Bass", "rap": "Bass", "trap": "Bass",
        "edm": "Bass", "electronic": "Bass", "house": "Bass", "techno": "Bass",
        "dubstep": "Bass", "dnb": "Bass", "d&b": "Bass", "reggae": "Bass", "dub": "Bass",
        "grime": "Bass", "funk": "Bass", "disco": "Bass", "afrobeat": "Bass",
        "synthwave": "Bass", "bass": "Bass",
        // Vocal-forward genres - benefit from the same mid-range boost as
        // singer-songwriter material.
        "acoustic": "Vocal", "folk": "Vocal", "singer-songwriter": "Vocal",
        "a cappella": "Vocal", "country": "Vocal", "gospel": "Vocal", "choir": "Vocal",
        "soul": "Vocal", "r&b": "Vocal", "rnb": "Vocal", "vocal": "Vocal",
        // Catch-all - also covers k-pop/j-pop/synth-pop/dance-pop/etc, which
        // all contain "pop" as a substring already.
        "pop": "Pop"
    })

    // A couple of the keys above are risky substrings of extremely common
    // non-genre Last.fm tags - rather than dropping the keyword entirely
    // (it's still useful in its own right), skip it specifically when the
    // full tag looks like one of these known false positives. "male
    // vocalists"/"female vocalists" are near-ubiquitous Last.fm tags with
    // nothing to do with genre, and "double bass"/"upright bass" show up on
    // plenty of jazz artists (as an instrument credit, not a Bass-preset
    // genre).
    readonly property var falsePositiveSubstrings: ({
        "vocal": ["vocalist"],
        "bass": ["double bass", "upright bass", "bass guitar", "bassist", "bass player"]
    })

    function refresh() {
        eqGetProc.running = false
        eqGetProc.running = true
    }

    function refreshAuto() {
        eqGetAutoProc.running = false
        eqGetAutoProc.running = true
    }

    function toggleAuto() {
        const next = !root.autoEnabled
        root.autoEnabled = next
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_auto", next ? "true" : "false"])
        if (next) {
            // Force a fresh lookup rather than skipping it because the
            // song "hasn't changed" since last time Auto happened to be on.
            root.lastLookupKey = ""
            root.maybeLookupGenre()
        }
    }

    // MPRIS-native artist field parsed from the tab title text as a last
    // resort - see deriveYouTubeArtistTrack() below for why this exists and
    // its real limitations. Only ever used when trackArtist is empty, so it
    // never overrides a player (Spotify, etc.) that already gives us a
    // proper artist field.
    function deriveYouTubeArtistTrack(rawTitle) {
        let t = String(rawTitle ?? "")
        // Strip a leading unread-notification-count badge some setups
        // prepend to the tab title (confirmed against real Firefox output:
        // "(784) IV Of Spades - Kabisado (Lyrics) - YouTube"), and the
        // trailing " - YouTube" the tab title always carries.
        t = t.replace(/^\(\d+\)\s*/, "").replace(/\s*-\s*YouTube$/i, "").trim()
        if (!t) return null
        // The "Artist - Title" convention most official audio/lyric-video
        // uploads use. This is a guess, not a real signal - plenty of
        // videos don't follow it (vlogs, gameplay, a channel that just
        // posts "Song Name" with the artist implicit in the channel
        // itself), and some non-music titles that happen to contain a dash
        // will produce a wrong-but-harmless guess (Last.fm just won't
        // recognize "artist" as a real artist and comes back with no
        // tags, same as any other unrecognized name - see the
        // strip_featured_artists comment in equalizer.sh for the same
        // fail-safe pattern). No dash at all -> nothing to guess, return
        // null rather than treating the whole title as an artist name.
        const parts = t.split(" - ")
        if (parts.length < 2) return null
        const artist = parts[0].trim()
        // Upload-title noise that doesn't help (and can actively hurt) a
        // Last.fm track lookup, e.g. "(Lyrics)", "(Official Music Video)".
        let track = parts.slice(1).join(" - ").trim()
        track = track.replace(/[\[(](official\s*)?(music\s*)?(video|audio|lyrics?|visualizer|hd|4k)[\])]/gi, "").trim()
        if (!artist || !track) return null
        return { artist, track }
    }

    // Called whenever the current song might have changed (track or artist
    // change, Auto just got switched on, a Last.fm key just got saved).
    function maybeLookupGenre() {
        if (!root.autoEnabled) return
        if (!root.isEligiblePlayer(root.player)) return
        let artist = root.player?.trackArtist ?? ""
        let title = root.player?.trackTitle ?? ""
        if (!artist && title) {
            // No native MPRIS artist field (confirmed: Firefox never
            // populates one for YouTube, even mid-playback of a real
            // song) - fall back to parsing it out of the title text.
            const parsed = root.deriveYouTubeArtistTrack(title)
            if (!parsed) return
            artist = parsed.artist
            title = parsed.track
        }
        if (!artist) return
        // \u241F (a control-picture stand-in, never going to appear in real
        // metadata) joins the two so e.g. artist "A", title "B - C" can't
        // collide with artist "A - B", title "C". Built from the resolved
        // artist/title (post-YouTube-parsing) rather than the raw MPRIS
        // fields, so a notification-count badge ticking up in the tab
        // title while the same video keeps playing doesn't look like a
        // song change.
        const key = artist + "\u241F" + title
        if (key === root.lastLookupKey) return
        root.lastLookupKey = key
        root.lastArtistTags = []
        root.lastTrackTags = []
        genreTagsProc.artist = artist
        genreTagsProc.running = false
        genreTagsProc.running = true
        if (title) {
            trackGenreTagsProc.artist = artist
            trackGenreTagsProc.title = title
            trackGenreTagsProc.running = false
            trackGenreTagsProc.running = true
        }
    }

    // Adds one tag list's votes into `scores`, keyed by target preset.
    // `multiplier` lets a more specific/reliable tag source (the current
    // track) outweigh a broader one (the artist's whole catalog) without
    // one being an all-or-nothing override of the other - a track with no
    // tags of its own still benefits from the artist-level signal, and a
    // track with strong tags of its own can override a misleading
    // artist-level genre (e.g. one folk artist's one EDM remix).
    function scoreTagGroup(tags, multiplier, scores) {
        if (!Array.isArray(tags)) return
        tags.forEach((tag, i) => {
            const lower = String(tag).toLowerCase()
            if (!lower) return
            // Tags come back ordered most-to-least relevant, so rank
            // position (rather than Last.fm's raw, wildly artist-popularity-
            // skewed relevance counts) makes a consistent, comparable
            // weight: the top tag counts most, and it decays from there.
            const rankWeight = tags.length - i
            for (const key in root.genreTagPresetMap) {
                if (!lower.includes(key)) continue
                const exclusions = root.falsePositiveSubstrings[key]
                if (exclusions && exclusions.some(bad => lower.includes(bad))) continue
                const preset = root.genreTagPresetMap[key]
                scores[preset] = (scores[preset] || 0) + rankWeight * multiplier
                break // most-specific/first-matching keyword per tag only
            }
        })
    }

    // Blends track-level and artist-level tags into a single vote and
    // returns whichever preset comes out on top. No tag from either list
    // matching anything (unset API key, unknown artist/track, no network,
    // or a genre we just don't have a mapping for) returns null, which
    // leaves the current preset alone rather than guessing.
    function presetForTags(artistTags, trackTags) {
        const scores = {}
        root.scoreTagGroup(trackTags, 3, scores)
        root.scoreTagGroup(artistTags, 1, scores)
        let best = null
        let bestScore = 0
        for (const preset in scores) {
            if (scores[preset] > bestScore) {
                best = preset
                bestScore = scores[preset]
            }
        }
        return bestScore > 0 ? best : null
    }

    // Re-run whenever either the artist-level or track-level lookup
    // resolves, scoring against whatever's currently known for the other
    // one too (which may still be mid-flight, or may have come back empty).
    function recomputePreset() {
        if (!root.autoEnabled) return
        const preset = root.presetForTags(root.lastArtistTags, root.lastTrackTags)
        if (preset && preset !== root.currentPresetName) {
            root.applyAutoPreset(preset)
        }
    }

    function applyAutoPreset(name) {
        root.currentPresetName = name
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "preset", name])
    }

    Component.onCompleted: {
        root.refresh()
        root.refreshAuto()
    }

    // Covers switching which player is active (e.g. pausing an ineligible
    // Firefox tab and hitting play on Spotify) - onTrackArtistChanged below
    // only fires for changes within whichever player Connections is
    // currently targeting, so a fresh eligibility check on the switch
    // itself is what makes Auto react right away instead of waiting for
    // that new player's own next metadata blip.
    onPlayerChanged: root.maybeLookupGenre()

    Connections {
        target: root.player
        function onTrackArtistChanged() { root.maybeLookupGenre() }
        function onTrackTitleChanged() { root.maybeLookupGenre() }
    }

    Process {
        id: eqGetProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.currentPresetName = data.preset ?? "Custom"
                } catch (e) {
                    // Leave previous value if the state file isn't ready yet
                }
            }
        }
    }

    Process {
        id: eqGetAutoProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get_auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.autoEnabled = (t === "true" || t === "1")
                if (root.autoEnabled) root.maybeLookupGenre()
            }
        }
    }

    // Artist-level lookup - broad signal, covers most artists on Last.fm,
    // but describes their whole catalog rather than the specific song.
    Process {
        id: genreTagsProc
        property string artist: ""
        // "true" is a harmless no-op command for when artist is still
        // empty (e.g. before the first real onTrackArtistChanged fires).
        command: artist.length > 0
            ? ["bash", Directories.eqScriptPath, Directories.eqStateDir, "genre_tags", artist]
            : ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastArtistTags = JSON.parse(text)
                } catch (e) {
                    root.lastArtistTags = []
                }
                root.recomputePreset()
            }
        }
    }

    // Track-level lookup - narrower/more specific when Last.fm actually has
    // tags for this exact song (far from guaranteed - most individual
    // tracks have none), weighted higher than the artist-level tags above
    // in presetForTags() precisely because it's more specific when present.
    Process {
        id: trackGenreTagsProc
        property string artist: ""
        property string title: ""
        command: (artist.length > 0 && title.length > 0)
            ? ["bash", Directories.eqScriptPath, Directories.eqStateDir, "track_genre_tags", artist, title]
            : ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastTrackTags = JSON.parse(text)
                } catch (e) {
                    root.lastTrackTags = []
                }
                root.recomputePreset()
            }
        }
    }
}
