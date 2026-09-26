// ==UserScript==
// @name         Dynamic Island — send to Gemini
// @namespace    end4-pC
// @version      1.0
// @description  Takes a text from the Dynamic Island through the link (gemini.google.com/app#ilha=…), types it into Gemini and sends it.
// @match        https://gemini.google.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// The text comes in the #fragment of the link (IslandEvents.askGemini), so it never leaves the browser. Only acts
// when the link carries "#ilha=". The page blocks innerHTML (Trusted Types), so the text goes in through
// execCommand("insertText"), and the send button only appears once there is text.

(function () {
    "use strict"

    const until = (find, timeoutMs) => new Promise(resolve => {
        const started = Date.now()
        const tick = () => {
            const found = find()
            if (found) return resolve(found)
            if (Date.now() - started > timeoutMs) return resolve(null)
            setTimeout(tick, 150)
        }
        tick()
    })

    async function deliver() {
        if (!location.hash.startsWith("#ilha=")) return
        const text = decodeURIComponent(location.hash.slice("#ilha=".length))
        history.replaceState(null, "", location.pathname + location.search)
        if (!text.trim()) return

        const editor = await until(() => document.querySelector("rich-textarea .ql-editor"), 15000)
        if (!editor) return
        editor.focus()
        document.execCommand("insertText", false, text)

        const send = await until(() => [...document.querySelectorAll("button")].find(b =>
            /^(enviar mensagem|send message)$/i.test(b.getAttribute("aria-label") ?? "") && !b.disabled
            && b.getAttribute("aria-disabled") !== "true"), 4000)
        send?.click()
    }

    deliver()
    window.addEventListener("hashchange", deliver)
})()
