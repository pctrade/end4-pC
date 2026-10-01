pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    property int viewers: 0
    readonly property bool wanted: root.viewers > 0 || ((Config.options?.bar?.dynamicIsland?.lyrics ?? true)
        && ((Config.options?.bar?.dynamicIsland?.lyricsPill ?? true) || (Config.options?.bar?.dynamicIsland?.lyricsCard ?? true)))
    readonly property bool playing: root.activePlayer?.isPlaying ?? false
    property string fetchedFor: ""
    readonly property string trackKey: `${root.activePlayer?.trackTitle ?? ""}|${root.activePlayer?.trackArtist ?? ""}`
    onWantedChanged: if (root.wanted && root.fetchedFor !== root.trackKey) root.restartLyrics()

    property var lyricsLines: []
    property int activeIndex: -1
    property string status: "loading"
    property var slots: ["", "", "", "", "", "", ""]

    readonly property int before: 3
    readonly property int after:  3
    readonly property int total:  7

    function buildSlots(idx) {
        let result = []
        for (let i = 0; i < root.total; i++) {
            let lineIdx = idx - root.before + i
            if (lineIdx >= 0 && lineIdx < root.lyricsLines.length)
                result.push(root.lyricsLines[lineIdx].text || "♪")
            else
                result.push("")
        }
        return result
    }

    Timer {
        id: syncTimer
        interval: 150
        repeat: true
        running: root.status === "ok" && root.lyricsLines.length > 0 && root.wanted && root.playing
        onTriggered: root.syncNow()
    }

    // Highlights the line at the player position. Also runs on lyrics arrival, pause/resume and view requests,
    // so a paused song keeps its line.
    function syncNow() {
        if (root.status !== "ok" || root.lyricsLines.length === 0) return
        const pos = root.activePlayer?.position ?? 0
        let idx = -1
        for (let i = 0; i < root.lyricsLines.length; i++) {
            if (root.lyricsLines[i].time <= pos) idx = i
            else break
        }
        if (idx !== root.activeIndex) {
            root.activeIndex = idx
            root.slots = root.buildSlots(idx)
        }
    }
    onPlayingChanged: root.syncNow()

    Process {
        id: lyricsProc
        running: false
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed === "not_found") { root.status = "not_found"; return }
                if (trimmed === "no_info")   { root.status = "no_info";   return }

                const parts = trimmed.split("§")
                if (parts.length < 3) return
                if (parts[parts.length - 1].trim() !== "ok") return

                let lines = []
                for (let i = 0; i < parts.length - 1; i += 2) {
                    const t = parseFloat(parts[i])
                    const txt = parts[i + 1] || ""
                    if (!isNaN(t)) lines.push({ time: t, text: txt })
                }

                if (lines.length === 0) { root.status = "not_found"; return }

                root.lyricsLines = lines
                root.activeIndex = -1
                root.slots = root.buildSlots(-1)
                root.status = "ok"
                Qt.callLater(root.syncNow)
            }
        }
    }

    function restartLyrics() {
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = "loading"
        if (!root.wanted) {
            root.status = "off"
            root.fetchedFor = ""
            return
        }
        root.fetchedFor = root.trackKey

        const title    = root.activePlayer?.trackTitle  ?? ""
        const artist   = root.activePlayer?.trackArtist ?? ""
        const duration = root.activePlayer?.length       ?? 0

        if (!title || !artist) { root.status = "no_info"; return }

        lyricsProc.command = [
            "python3",
            `${Directories.scriptPath}/lyrics/lyrics.py`,
            title, artist, String(Math.floor(duration))
        ]
        lyricsProc.running = true
    }

    // Keyed on title + artist (and so on the player): title alone missed player switches and reloads. Debounced
    // because title and artist often arrive apart.
    onTrackKeyChanged: lyricsDebounce.restart()
    Timer {
        id: lyricsDebounce
        interval: 250
        onTriggered: if (root.fetchedFor !== root.trackKey) root.restartLyrics()
    }

    Component.onCompleted: root.restartLyrics()
}