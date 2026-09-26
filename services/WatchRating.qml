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

    readonly property var browserPlayer: {
        for (const player of Mpris.players.values) {
            const source = `${player.dbusName ?? ""} ${player.identity ?? ""} ${player.desktopEntry ?? ""}`.toLowerCase()
            if (!/chrom|firefox|zen|brave|vivaldi|opera|edge/.test(source)) continue
            if (root.parse(player) !== null) return player
        }
        return null
    }
    readonly property var now: root.fake ?? (root.browserPlayer ? root.parse(root.browserPlayer) : null)
    readonly property bool playing: root.fake !== null || (root.browserPlayer?.isPlaying ?? false)

    property var fake: null
    Timer {
        id: fakeEnd
        interval: 9000
        onTriggered: root.fake = null
    }
    function simulate(kind) {
        const rated = root.allEpisodes.filter(e => root.ratingOf(e) >= 0)
        if (!root.info || !root.now || rated.length === 0) return
        const sorted = [...rated].sort((a, b) => root.ratingOf(b) - root.ratingOf(a))
        const bestOf = season => rated.filter(e => e.Season === season).reduce((a, b) => root.ratingOf(b) > root.ratingOf(a) ? b : a)
        const seasons = [...new Set(rated.map(e => e.Season))]
        let pick = null
        if (kind === "top3") pick = sorted[0]
        else if (kind === "top10") pick = sorted[6]
        else if (kind === "best") pick = seasons.map(bestOf).find(e => sorted.indexOf(e) >= 12)
        else if (kind === "high") pick = sorted.find((e, i) => i >= 12 && root.ratingOf(e) >= 8.5 && bestOf(e.Season) !== e)
        else pick = sorted[Math.floor(sorted.length / 2)]
        if (!pick) return
        root.announced = ({})
        root.fake = { series: root.now.series, season: pick.Season, episode: Number(pick.Episode), episodeTitle: "",
            service: root.now.service || "netflix", source: "script" }
        fakeEnd.restart()
    }

    readonly property var siteServices: ({ "disney+": "disneyplus", "netflix": "netflix", "prime video": "primevideo",
        "max": "max", "apple tv+": "appletv", "crunchyroll": "crunchyroll", "paramount+": "paramountplus" })

    function parse(player) {
        const title = (player?.trackTitle ?? "").trim()
        const artist = (player?.trackArtist ?? "").trim()
        const album = (player?.trackAlbum ?? "").trim()
        const code = album.match(/^(?:S(\d+)E(\d+))?\|(\w*)$/i)
        if (code && artist !== "") {
            if (code[1]) return { series: artist, season: Number(code[1]), episode: Number(code[2]), episodeTitle: title, service: code[3], source: "script" }
            return { series: artist, season: 0, episode: 0, episodeTitle: "", service: code[3], source: "script" }
        }
        const site = title.match(/^(.+?)\s*\|\s*(Disney\+|Netflix|Prime Video|Max|Apple TV\+|Crunchyroll|Paramount\+)\s*$/i)
        if (site)
            return { series: site[1].trim(), season: 0, episode: 0, episodeTitle: "", service: root.siteServices[site[2].toLowerCase()] ?? "", source: "page" }
        return null
    }
    readonly property string service: root.now?.service ?? ""

    property var titleCache: ({})
    property var seriesCache: ({})
    property int revision: 0

    function fetchSeries(id, done, after, collected) {
        const all = collected ?? []
        const page = after ? `, after: "${after}"` : ""
        const query = `query { title(id: "${id}") { episodes { episodes(first: 250${page}) { pageInfo { hasNextPage endCursor }
            edges { node { id titleText { text } releaseDate { year month day } ratingsSummary { aggregateRating voteCount }
            series { displayableEpisodeNumber { episodeNumber { text } displayableSeason { text } } } } } } } } }`
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let block = null
            try { block = JSON.parse(xhr.responseText).data.title.episodes.episodes } catch (e) {}
            for (const edge of block?.edges ?? []) {
                const n = edge.node
                const number = n.series?.displayableEpisodeNumber
                const date = n.releaseDate
                const episode = {
                    Season: Number(number?.displayableSeason?.text),
                    Episode: number?.episodeNumber?.text ?? "",
                    Title: n.titleText?.text ?? "",
                    Released: date ? [date.day, date.month, date.year].filter(Boolean).join("/") : "",
                    imdbRating: n.ratingsSummary?.aggregateRating != null ? String(n.ratingsSummary.aggregateRating) : "N/A",
                    imdbVotes: n.ratingsSummary?.voteCount ?? 0,
                    imdbID: n.id
                }
                if (episode.Season > 0 && /^\d+$/.test(episode.Episode)) all.push(episode)
            }
            if (block?.pageInfo?.hasNextPage && all.length < 2000) root.fetchSeries(id, done, block.pageInfo.endCursor, all)
            else done(all)
        }
        xhr.open("POST", "https://caching.graphql.imdb.com/")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("x-imdb-client-name", "imdb-web-next")
        xhr.send(JSON.stringify({ query: query }))
    }

    readonly property var info: {
        root.revision
        return root.now ? (root.titleCache[root.now.series.toLowerCase()] ?? null) : null
    }
    readonly property var allEpisodes: {
        root.revision
        return root.info ? (root.seriesCache[root.info.imdbID] || []) : []
    }
    readonly property var seasonEpisodes: root.now && root.now.season > 0
        ? root.allEpisodes.filter(e => e.Season === root.now.season).sort((a, b) => Number(a.Episode) - Number(b.Episode))
        : []
    readonly property var currentEpisode: root.seasonEpisodes.find(e => Number(e.Episode) === root.now?.episode) ?? null

    function ratingOf(episode) {
        const value = parseFloat(episode?.imdbRating ?? "")
        return isNaN(value) ? -1 : value
    }
    readonly property string episodeTitle: {
        const own = root.now?.episodeTitle ?? ""
        return own !== "" && !/^S\d+E\d+$/i.test(own) ? own : (root.currentEpisode?.Title ?? "")
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
    readonly property int rank: {
        if (root.episodeRating < 0) return -1
        return root.seasonEpisodes.filter(e => root.ratingOf(e) > root.episodeRating).length + 1
    }
    readonly property int ratedCount: root.seasonEpisodes.filter(e => root.ratingOf(e) >= 0).length

    readonly property int seriesRated: root.allEpisodes.filter(e => root.ratingOf(e) >= 0).length
    readonly property int seriesRank: root.episodeRating < 0 ? -1
        : root.allEpisodes.filter(e => root.ratingOf(e) > root.episodeRating).length + 1
    readonly property bool isTop3: root.seriesRank > 0 && root.seriesRank <= 3 && root.seriesRated >= 8
    readonly property bool isTop10: !root.isTop3 && root.seriesRank > 0 && root.seriesRank <= 10 && root.seriesRated >= 25
    readonly property string tier: root.isTop3 ? "top3" : root.isTop10 ? "top10" : root.isBest ? "best"
        : root.episodeRating >= 8.5 ? "high" : ""
    function statsFor(episode) {
        const rating = root.ratingOf(episode)
        if (!episode || rating < 0) return null
        const season = root.allEpisodes.filter(e => e.Season === episode.Season)
        const best = season.every(e => root.ratingOf(e) <= rating)
        const seriesRank = root.allEpisodes.filter(e => root.ratingOf(e) > rating).length + 1
        const top3 = seriesRank <= 3 && root.seriesRated >= 8
        const top10 = !top3 && seriesRank <= 10 && root.seriesRated >= 25
        return {
            season: episode.Season, episode: Number(episode.Episode), title: episode.Title ?? "", rating: rating, seriesRank: seriesRank,
            tier: top3 ? "top3" : top10 ? "top10" : best ? "best" : rating >= 8.5 ? "high" : ""
        }
    }

    readonly property var nextEpisode: {
        if (!root.now || root.now.season <= 0 || root.allEpisodes.length === 0) return null
        const inSeason = root.seasonEpisodes.find(e => Number(e.Episode) === root.now.episode + 1)
        if (inSeason) return inSeason
        return root.allEpisodes.filter(e => e.Season === root.now.season + 1)
            .sort((a, b) => Number(a.Episode) - Number(b.Episode))[0] ?? null
    }
    readonly property var nextStats: root.statsFor(root.nextEpisode)

    readonly property bool ready: {
        root.revision
        return root.info !== null && (root.now?.season <= 0 || root.seriesCache[root.info.imdbID] !== undefined)
    }
    readonly property bool active: root.enabled && root.now !== null && root.ready && (root.now.season > 0
        ? root.episodeRating >= 0
        : (root.now.source === "script" && root.info?.Type === "movie" && root.seriesRating >= 0))

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

    // Netflix/Disney+ show their own language's title ("O Mentalista"); OMDb's exact-title search only knows
    // it in English and fails outright. IMDb's own search-as-you-type resolves almost any language or spelling.
    function resolveByName(name, done) {
        const letter = /[a-z0-9]/i.test(name.trim()[0] ?? "") ? name.trim()[0].toLowerCase() : "a"
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let id = null
            try { id = JSON.parse(xhr.responseText).d?.find(e => (e.id ?? "").startsWith("tt"))?.id ?? null } catch (e) {}
            done(id)
        }
        xhr.open("GET", `https://v2.sg.media-imdb.com/suggestion/${letter}/${encodeURIComponent(name.trim())}.json`)
        xhr.send()
    }

    function lookup() {
        if (!root.enabled || !root.now) return
        // Captured once: root.now can turn null while these requests are in flight, and every step below only
        // needs the name it started with
        const seriesName = root.now.series
        const key = seriesName.toLowerCase()
        const base = `https://www.omdbapi.com/?apikey=${encodeURIComponent(root.apiKey)}`
        const cached = root.titleCache[key]
        if (cached === undefined) {
            root.request(`${base}&t=${encodeURIComponent(seriesName)}`, data => {
                if (data) {
                    root.titleCache[key] = data
                    root.revision++
                    root.lookup()
                    return
                }
                root.resolveByName(seriesName, id => {
                    if (!id) {
                        root.titleCache[key] = false
                        root.revision++
                        root.lookup()
                        return
                    }
                    root.request(`${base}&i=${id}`, byId => {
                        root.titleCache[key] = byId ?? false
                        root.revision++
                        root.lookup()
                    })
                })
            })
            return
        }
        if (!cached || root.now.season <= 0) return
        const id = cached.imdbID
        if (root.seriesCache[id] !== undefined || root.pending[id]) return
        root.pending[id] = true
        root.fetchSeries(id, episodes => {
            delete root.pending[id]
            root.seriesCache[id] = episodes
            root.revision++
        })
    }

    readonly property string nowKey: root.now ? `${root.now.series}|${root.now.season}|${root.now.episode}` : ""
    onNowKeyChanged: {
        root.lookup()
        settle.restart()
        root.aimEnding()
    }
    onEnabledChanged: root.lookup()

    property var announced: ({})

    Timer {
        id: settle
        interval: 3000
        onTriggered: root.announce()
    }

    function announce() {
        if (settle.running) return
        if (!root.active || !root.playing || root.announced[root.nowKey]) return
        root.announced[root.nowKey] = true
        IslandEvents.watchRating.show({ key: root.nowKey }, 6000)
    }
    onActiveChanged: root.announce()

    property var announcedNext: ({})

    function aimEnding() {
        endingTimer.stop()
        const player = root.browserPlayer
        if (root.fake || !root.enabled || !root.playing || !player || !root.now || root.now.season <= 0) return
        const length = player.length ?? 0
        if (!(length > 300)) return
        const left = length - (player.position ?? 0) - 100
        if (left < -60) return
        endingTimer.interval = Math.max(1000, left * 1000)
        endingTimer.restart()
    }

    Timer {
        id: endingTimer
        onTriggered: root.announceNext()
    }

    Connections {
        target: root.browserPlayer
        ignoreUnknownSignals: true
        function onPositionChanged() { root.aimEnding() }
        function onLengthChanged() { root.aimEnding() }
    }

    function announceNext(force) {
        const stats = root.nextStats
        if (!stats || (!force && root.announcedNext[root.nowKey])) return
        root.announcedNext[root.nowKey] = true
        IslandEvents.watchRating.show({ key: root.nowKey, next: stats }, 9000)
    }
    onPlayingChanged: {
        root.announce()
        root.aimEnding()
    }
    onRevisionChanged: root.announce()
}
