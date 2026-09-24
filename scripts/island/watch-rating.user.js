// ==UserScript==
// @name         Ilha — episódio atual (Netflix / Disney+)
// @namespace    end4-pC
// @version      3.1
// @description  Publica série, temporada e episódio nos metadados de mídia do navegador, que o Chrome repassa ao MPRIS — é daí que a Dynamic Island tira a nota do IMDb de cada episódio.
// @match        https://www.netflix.com/*
// @match        https://www.disneyplus.com/*
// @match        https://*.disneyplus.com/*
// @grant        none
// @sandbox      JavaScript
// @run-at       document-idle
// ==/UserScript==

// Contrato com a Ilha (services/WatchRating.qml):
//   artist = série (ou filme)
//   album  = "S06E19|disneyplus" quando é episódio; "|netflix" quando é filme (o serviço vai depois do |)
//   title  = título do episódio (ou o próprio código, quando o título ainda não é conhecido — a Ilha usa o do IMDb)
//
// O que a página real do Disney+ mostrou (set/2026):
// - o player é feito de Web Components com Shadow DOM: sem atravessar shadowRoot não se acha nada;
// - o episódio atual fica em main-app-controls-overlay › title-bug ("T6:E19 Churrasqueira Furada"), e só existe
//   enquanto os controles estão na tela;
// - o "a seguir" (pivot-tray-tile.episodeTitle, "T6:E20 …") fica no DOM o tempo todo — e é justamente o que
//   vai tocar quando o autoplay trocar de episódio.
// Daí as três fontes, da mais para a menos confiável: o episódio atual visível; o "a seguir" que a página
// anterior mostrava (autoplay); e o "a seguir" desta página menos um.

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

    // querySelectorAll that also looks inside every shadow root
    function deepAll(selector, root = document) {
        const out = [...root.querySelectorAll(selector)]
        for (const element of root.querySelectorAll("*"))
            if (element.shadowRoot) out.push(...deepAll(selector, element.shadowRoot))
        return out
    }

    // Every text piece joined with a space: Netflix splits "Suits", "T1:E3" and the title into sibling tags, and
    // plain textContent glues them into "SuitsT1:E3Title", which no episode pattern can read
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

    // Netflix keeps the whole show in its player state: the episode is known even with the controls hidden
    // (autoplay included). Internal and undocumented — if it's not there, this just returns nothing.
    function netflixState() {
        try {
            const app = window.netflix?.appContext?.state?.playerApp
            if (!app) return null
            const videoPlayer = app.getAPI().videoPlayer
            const session = videoPlayer.getAllPlayerSessionIds().find(id => id.startsWith("watch"))
            const movieId = session ? videoPlayer.getVideoPlayerBySessionId(session).getMovieId()
                : Number(location.pathname.match(/\/watch\/(\d+)/)?.[1])
            const video = app.getState().videoPlayer.videoMetadata[movieId]?._metadata?.video
            if (!video) return null
            if (video.type !== "show") return { series: video.title, episode: null }
            for (const season of video.seasons ?? [])
                for (const episode of season.episodes ?? [])
                    if (episode.id === movieId || episode.episodeId === movieId)
                        return { series: video.title, episode: { season: season.seq, episode: episode.seq, title: episode.title ?? "" } }
            return { series: video.title, episode: null }
        } catch (e) {
            return null
        }
    }

    function currentEpisode() {
        // Disney+: the title bug over the player, only while the controls are up
        for (const bug of deepAll("title-bug")) {
            const info = parse(deepText(bug))
            if (info) return info
        }
        // Netflix: its own player state first (works with the controls hidden), then the title block on screen
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

    const known = {}        // path → episode seen on screen (authoritative)
    const nextOf = {}       // path → its "up next"
    let lastPath = ""
    let published = ""

    function resolve(path) {
        const seen = currentEpisode()
        if (seen) known[path] = seen
        const next = upNext()
        if (next) nextOf[path] = next

        // Autoplay: the page just changed to what the previous page announced as next
        if (!known[path] && path !== lastPath && lastPath && nextOf[lastPath])
            known[path] = { ...nextOf[lastPath] }

        if (known[path]) return known[path]
        // Controls hidden since the start: the episode before "up next" (same season only)
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

    // Passive: no timer loop. It only looks when something happens — the video starts or loads, the URL changes
    // (autoplay moving on), or the controls come up under the pointer while the episode isn't confirmed yet —
    // and then just a few times, a moment apart, while the player finishes drawing.
    let burst = []
    function lookSoon() {
        burst.forEach(clearTimeout)
        burst = [300, 1500, 4000].map(ms => setTimeout(publish, ms))
    }

    for (const type of ["loadedmetadata", "playing"])
        document.addEventListener(type, lookSoon, true)   // media events don't bubble, but capture sees them

    if (window.navigation) navigation.addEventListener("currententrychange", lookSoon)
    else for (const name of ["pushState", "replaceState"]) {
        const original = history[name]
        history[name] = function (...args) { const out = original.apply(this, args); lookSoon(); return out }
    }
    window.addEventListener("popstate", lookSoon)

    let lastPointer = 0
    document.addEventListener("pointermove", () => {
        if (known[location.pathname]) return          // already confirmed on screen: nothing left to learn
        const now = Date.now()
        if (now - lastPointer < 1500) return
        lastPointer = now
        setTimeout(publish, 250)                      // give the controls a beat to draw the title
    }, { passive: true, capture: true })

    lookSoon()
})()
