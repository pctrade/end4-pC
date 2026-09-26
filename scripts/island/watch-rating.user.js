// ==UserScript==
// @name         Dynamic Island — current episode (Netflix / Disney+)
// @namespace    end4-pC
// @version      3.2
// @description  Publishes series, season and episode in the browser media metadata, which Chrome passes on to MPRIS, so the Dynamic Island can show the IMDb rating of each episode.
// @match        https://www.netflix.com/*
// @match        https://www.disneyplus.com/*
// @match        https://*.disneyplus.com/*
// @grant        none
// @sandbox      JavaScript
// @run-at       document-idle
// ==/UserScript==

// What the island reads (services/WatchRating.qml):
//   artist = series (or film)
//   album  = "S06E19|disneyplus" for an episode, "|netflix" for a film (service after the |)
//   title  = episode title (or the code itself while the title is unknown; the island then uses IMDb's)
// Disney+ builds its player from Web Components with Shadow DOM, and the current episode only exists while the
// controls are on screen, so there are three sources, most reliable first: the visible current episode, the
// "up next" the previous page showed (autoplay), and this page's "up next" minus one.

(function () {
    "use strict"

    const EPISODE = /(?:^|[\s(])(?:S|T|Temporada\s*|Season\s*)(\d{1,2})\s*[:·.,]?\s*(?:E|Ep\.?\s*|Episódio\s*|Episode\s*)(\d{1,3})\b/i

    function parse(text) {
        const clean = (text ?? "").replace(/\s+/g, " ").trim()
        if (!clean || clean.length > 200) return null
        const match = clean.match(EPISODE)
        if (!match) return null
        const title = clean.slice(match.index + match[0].length).replace(/^[\s:·"“—–-]+/, "").replace(/["”]$/, "").trim()
        return { season: Number(match[1]), episode: Number(match[2]), title }
    }

    function deepAll(selector, root = document) {
        const out = [...root.querySelectorAll(selector)]
        for (const element of root.querySelectorAll("*"))
            if (element.shadowRoot) out.push(...deepAll(selector, element.shadowRoot))
        return out
    }

    function textOf(root) {
        if (!root) return ""
        const parts = []
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
        for (let node = walker.nextNode(); node; node = walker.nextNode()) {
            const text = node.textContent.trim()
            if (text) parts.push(text)
        }
        return parts.join(" ")
    }

    function deepText(element) {
        if (!element) return ""
        return textOf(element.shadowRoot ?? element)
    }

    function netflixState() {
        try {
            const metadata = window.netflix?.appContext?.state?.playerApp?.getState()?.videoPlayer?.videoMetadata
            if (!metadata) return null
            const watching = Number(location.pathname.match(/\/watch\/(\d+)/)?.[1])
            const entry = metadata[watching] ?? Object.values(metadata)[0]
            const video = entry?._metadataObject?.video ?? entry?._metadata?.video
            if (!video) return null
            if (video.type !== "show") return { series: video.title, episode: null }
            const current = video.currentEpisode ?? watching
            for (const season of video.seasons ?? [])
                for (const episode of season.episodes ?? [])
                    if (episode.id === current || episode.episodeId === current)
                        return { series: video.title, episode: { season: season.seq, episode: episode.seq, title: episode.title ?? "" } }
            return { series: video.title, episode: null }
        } catch (e) {
            return null
        }
    }

    function currentEpisode() {
        for (const bug of deepAll("title-bug")) {
            const info = parse(deepText(bug))
            if (info) return info
        }
        const netflix = netflixState()?.episode
        if (netflix) return netflix
        for (const block of deepAll('[data-uia="video-title"]')) {
            const info = parse(textOf(block))
            if (info) return info
        }
        return null
    }

    function upNext() {
        for (const tile of deepAll('[data-qa="pivot-tray-tile.episodeTitle"]')) {
            const info = parse(textOf(tile))
            if (info) return info
        }
        return null
    }

    function seriesName() {
        const netflix = netflixState()?.series || document.querySelector('[data-uia="video-title"] h4')?.textContent?.trim()
        if (netflix) return netflix
        const title = document.title.replace(/\s*[|–—-]\s*(Disney\+|Netflix)\s*$/i, "").trim()
        return title && !/^(Netflix|Disney\+)$/i.test(title) ? title : ""
    }

    const known = {}
    const nextOf = {}
    let lastPath = ""
    let published = ""

    function resolve(path) {
        const seen = currentEpisode()
        if (seen) known[path] = seen
        const next = upNext()
        if (next) nextOf[path] = next

        if (!known[path] && path !== lastPath && lastPath && nextOf[lastPath])
            known[path] = { ...nextOf[lastPath] }

        if (known[path]) return known[path]
        if (next && next.episode > 1) return { season: next.season, episode: next.episode - 1, title: "" }
        return null
    }

    function publish() {
        if (!("mediaSession" in navigator) || !document.querySelector("video")) return
        const path = location.pathname
        const episode = resolve(path)
        if (path !== lastPath) lastPath = path
        const series = seriesName()
        if (!series) return

        const pad = n => String(n).padStart(2, "0")
        const service = /netflix\./.test(location.hostname) ? "netflix" : /disneyplus\./.test(location.hostname) ? "disneyplus" : ""
        const code = (episode ? `S${pad(episode.season)}E${pad(episode.episode)}` : "") + `|${service}`
        const title = episode ? (episode.title || code.split("|")[0]) : series
        const signature = `${series}|${code}|${title}`

        const current = navigator.mediaSession.metadata
        if (signature === published && current && current.artist === series && current.album === code) return
        published = signature
        navigator.mediaSession.metadata = new MediaMetadata({
            title,
            artist: series,
            album: code,
            artwork: current?.artwork ? [...current.artwork] : [],
        })
    }

    let burst = []
    function lookSoon() {
        burst.forEach(clearTimeout)
        burst = [300, 1500, 4000].map(ms => setTimeout(publish, ms))
    }

    for (const type of ["loadedmetadata", "playing"])
        document.addEventListener(type, lookSoon, true)

    if (window.navigation) navigation.addEventListener("currententrychange", lookSoon)
    else for (const name of ["pushState", "replaceState"]) {
        const original = history[name]
        history[name] = function (...args) { const out = original.apply(this, args); lookSoon(); return out }
    }
    window.addEventListener("popstate", lookSoon)

    let lastPointer = 0
    document.addEventListener("pointermove", () => {
        if (known[location.pathname]) return
        const now = Date.now()
        if (now - lastPointer < 1500) return
        lastPointer = now
        setTimeout(publish, 250)
    }, { passive: true, capture: true })

    lookSoon()
})()
