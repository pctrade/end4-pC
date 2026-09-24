// ==UserScript==
// @name         Ilha — enviar pro Gemini
// @namespace    end4-pC
// @version      1.0
// @description  Recebe um texto da Dynamic Island pelo link (gemini.google.com/app#ilha=…), coloca na caixa do Gemini e envia.
// @match        https://gemini.google.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// Contrato com a Ilha (IslandEvents.askGemini): o texto vem no #fragmento do link, que nunca sai do navegador.
// Passivo: só age quando o link traz "#ilha=" — nenhum loop, nenhuma checagem fora disso.
//
// O que a página real mostrou (set/2026): a caixa é `rich-textarea .ql-editor` (contenteditable, Quill); o botão
// de enviar só aparece depois que há texto, com aria-label "Enviar mensagem" (ou "Send message" em inglês); e a
// página bloqueia innerHTML (Trusted Types), então o texto entra só por execCommand("insertText").

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
        history.replaceState(null, "", location.pathname + location.search)   // no resend on reload
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
