pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * IMDb rating of what's playing in the browser (Netflix / Disney+), via the OMDb API.
 *
 * Where the episode comes from: scripts/island/watch-rating.user.js (Tampermonkey) writes it into the page's
 * media metadata, which Chrome forwards to MPRIS as title = episode title, artist = series, album = "S03E05".
 * Without the userscript it still works for the series itself: Chrome publishes "Series | Disney+" as the title.
 *
 * The API key lives outside the repo, in ~/.config/illogical-impulse/omdb.key. Lookups are cached per series
 * and per season (a whole season is one request), so a binge costs a handful of calls, not one per episode.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.ready && (Config.options.bar.dynamicIsland.watchRatings ?? true) && root.apiKey !== ""
    property string apiKey: ""

    FileView {
        path: `${Quickshell.env("HOME")}/.config/illogical-impulse/omdb.key`
        watchChanges: true
        onLoaded: root.apiKey = text().trim()
        onFileChanged: reload()
        onLoadFailed: root.apiKey = ""
    }

    // ── What's playing ────────────────────────────────────────────────────────────────────────────────────
    readonly property var browserPlayer: {
        for (const player of Mpris.players.values) {
            const source = `${player.dbusName ?? ""} ${player.identity ?? ""} ${player.desktopEntry ?? ""}`.toLowerCase()
            if (!/chrom|firefox|zen|brave|vivaldi|opera|edge/.test(source)) continue
            if (root.parse(player) !== null) return player
        }
        return null
    }
    readonly property var now: root.browserPlayer ? root.parse(root.browserPlayer) : null
    readonly property bool playing: root.browserPlayer?.isPlaying ?? false

    // title/artist/album → { series, season, episode, episodeTitle } or null when it isn't a show or a film
    function parse(player) {
        const title = (player?.trackTitle ?? "").trim()
        const artist = (player?.trackArtist ?? "").trim()
        const album = (player?.trackAlbum ?? "").trim()
        const code = album.match(/^S(\d+)E(\d+)$/i)
        if (code && artist !== "")
            return { series: artist, season: Number(code[1]), episode: Number(code[2]), episodeTitle: title, source: "script" }
        // A film from the userscript: series and title are the same thing
        if (artist !== "" && artist === title)
            return { series: title, season: 0, episode: 0, episodeTitle: "", source: "script" }
        // No userscript: the tab title Chrome publishes on its own
        const site = title.match(/^(.+?)\s*\|\s*(Disney\+|Netflix)\s*$/i)
        if (site)
            return { series: site[1].trim(), season: 0, episode: 0, episodeTitle: "", source: "page" }
        return null
    }

    // ── OMDb ──────────────────────────────────────────────────────────────────────────────────────────────
    property var titleCache: ({})
    property var seasonCache: ({})
    property int revision: 0

    readonly property var info: {
        root.revision
        return root.now ? (root.titleCache[root.now.series.toLowerCase()] ?? null) : null
    }
    readonly property var seasonEpisodes: {
        root.revision
        if (!root.info || !root.now || root.now.season <= 0) return []
        return root.seasonCache[`${root.info.imdbID}|${root.now.season}`] ?? []
    }
    readonly property var currentEpisode: root.seasonEpisodes.find(e => Number(e.Episode) === root.now?.episode) ?? null

    function ratingOf(episode) {
        const value = parseFloat(episode?.imdbRating ?? "")
        return isNaN(value) ? -1 : value
    }
    readonly property real seriesRating: root.ratingOf(root.info)
    readonly property real episodeRating: root.ratingOf(root.currentEpisode)
    readonly property var bestEpisode: {
        let best = null
        for (const e of root.seasonEpisodes) if (root.ratingOf(e) > root.ratingOf(best)) best = e
        return best
    }
    readonly property bool isBest: root.currentEpisode !== null && root.bestEpisode !== null
        && root.episodeRating > 0 && root.episodeRating >= root.ratingOf(root.bestEpisode)
    // 1 = best of the season, among the episodes that have a rating
    readonly property int rank: {
        if (root.episodeRating < 0) return -1
        return root.seasonEpisodes.filter(e => root.ratingOf(e) > root.episodeRating).length + 1
    }
    readonly property int ratedCount: root.seasonEpisodes.filter(e => root.ratingOf(e) >= 0).length
    readonly property bool ready: root.info !== null && (root.now?.season <= 0 || root.seasonEpisodes.length > 0)
    readonly property bool active: root.enabled && root.now !== null && root.ready && root.seriesRating >= 0

    property var pending: ({})

    function request(url, done) {
        if (root.pending[url]) return
        root.pending[url] = true
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            delete root.pending[url]
            let data = null
            try { data = JSON.parse(xhr.responseText) } catch (e) {}
            done(data && data.Response === "True" ? data : null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function lookup() {
        if (!root.enabled || !root.now) return
        const key = root.now.series.toLowerCase()
        const base = `https://www.omdbapi.com/?apikey=${encodeURIComponent(root.apiKey)}`
        const cached = root.titleCache[key]
        if (cached === undefined) {
            root.request(`${base}&t=${encodeURIComponent(root.now.series)}`, data => {
                root.titleCache[key] = data ?? false
                root.revision++
                root.lookup()
            })
            return
        }
        if (!cached || root.now.season <= 0) return
        const seasonKey = `${cached.imdbID}|${root.now.season}`
        if (root.seasonCache[seasonKey] === undefined) {
            root.request(`${base}&i=${cached.imdbID}&Season=${root.now.season}`, data => {
                root.seasonCache[seasonKey] = data?.Episodes ?? []
                root.revision++
            })
        }
    }

    readonly property string nowKey: root.now ? `${root.now.series}|${root.now.season}|${root.now.episode}` : ""
    onNowKeyChanged: {
        root.lookup()
        Qt.callLater(root.announce)
    }
    onEnabledChanged: root.lookup()

    // ── The Peek: once per episode (or film), as soon as its rating is known and it's actually playing ──
    property var announced: ({})

    function announce() {
        if (!root.active || !root.playing || root.announced[root.nowKey]) return
        root.announced[root.nowKey] = true
        IslandEvents.watchRating.show({ key: root.nowKey }, 6000)
    }
    onActiveChanged: root.announce()
    onPlayingChanged: root.announce()
    onRevisionChanged: root.announce()
}
