// ==UserScript==
// @name         Ilha — episódio atual (Netflix / Disney+)
// @namespace    end4-pC
// @version      1.0
// @description  Publica série, temporada e episódio nos metadados de mídia do navegador, que o Chrome repassa ao MPRIS — é daí que a Dynamic Island tira a nota do IMDb.
// @match        https://www.netflix.com/*
// @match        https://www.disneyplus.com/*
// @match        https://*.disneyplus.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// Contrato com a Ilha (services/WatchRating.qml):
//   title  = título do episódio (ou do filme)
//   artist = nome da série (ou do filme)
//   album  = "S03E05" quando é episódio, vazio quando é filme
// As páginas escondem os controles (e às vezes o texto do episódio) depois de alguns segundos, então o que
// foi achado fica guardado por URL até ela mudar.

(function () {
    "use strict"

    // "S3:E5", "T3:E5", "T3 E5", "Temporada 3 Episódio 5", "Ep. 5"…
    const EPISODE = /(?:^|[\s(])(?:S|T|Temporada\s*|Season\s*)(\d{1,2})\s*[:·.,]?\s*(?:E|Ep\.?\s*|Episódio\s*|Episode\s*)(\d{1,3})\b/i
    const SELECTORS = [
        '[data-uia="video-title"]',                   // Netflix
        '[data-testid="playback-details-subtitle"]',  // Disney+
        '[data-testid="subtitle"]',
        '.subtitle-field',
        '.title-field',
    ]
    const found = {}
    let published = ""

    function parse(text) {
        const clean = (text ?? "").replace(/\s+/g, " ").trim()
        if (!clean || clean.length > 200) return null
        const match = clean.match(EPISODE)
        if (!match) return null
        const title = clean.slice(match.index + match[0].length).replace(/^[\s:·"“—–-]+/, "").replace(/["”]$/, "").trim()
        return { season: Number(match[1]), episode: Number(match[2]), title }
    }

    function episodeFromPage() {
        for (const selector of SELECTORS) {
            for (const element of document.querySelectorAll(selector)) {
                const info = parse(element.textContent)
                if (info) return info
            }
        }
        // Last resort: any short text on the player that looks like an episode label
        const player = document.querySelector("video")?.closest("div") ?? document.body
        const walker = document.createTreeWalker(player.parentElement ?? player, NodeFilter.SHOW_TEXT)
        for (let node = walker.nextNode(), seen = 0; node && seen < 4000; node = walker.nextNode(), seen++) {
            if (node.textContent.length > 120) continue
            const info = parse(node.parentElement?.textContent)
            if (info) return info
        }
        return null
    }

    function seriesName() {
        const netflix = document.querySelector('[data-uia="video-title"] h4')?.textContent?.trim()
        if (netflix) return netflix
        const title = document.title.replace(/\s*[|–—-]\s*(Disney\+|Netflix)\s*$/i, "").trim()
        return title && !/^(Netflix|Disney\+)$/i.test(title) ? title : ""
    }

    function publish() {
        if (!("mediaSession" in navigator)) return
        const video = document.querySelector("video")
        if (!video) return

        const key = location.pathname
        const fresh = episodeFromPage()
        if (fresh) found[key] = fresh
        const episode = found[key] ?? null
        const series = seriesName()
        if (!series) return

        const pad = n => String(n).padStart(2, "0")
        const code = episode ? `S${pad(episode.season)}E${pad(episode.episode)}` : ""
        const title = episode ? (episode.title || code) : series
        const signature = `${series}|${code}|${title}`

        // The site may put its own metadata back; only rewrite when what's there isn't ours
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

    setInterval(publish, 2500)
})()
