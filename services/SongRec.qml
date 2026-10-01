pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum MonitorSource { Monitor, Input }

    property var monitorSource: SongRec.MonitorSource.Monitor
    property int timeoutInterval: Config.options.musicRecognition.interval
    property int timeoutDuration: Config.options.musicRecognition.timeout
    readonly property bool running: recognizeMusicProc.running

    function toggleRunning(running) {
        if (recognizeMusicProc.running && !running === true) root.manuallyStopped = true;
        if (running != undefined) {
            recognizeMusicProc.running = running
        } else {
            recognizeMusicProc.running = !root.running
        }
        musicReconizedProc.running = false
    }

    function toggleMonitorSource(source) {
        if (source !== undefined) {
            root.monitorSource = source
            return
        }
        root.monitorSource = (root.monitorSource === SongRec.MonitorSource.Monitor) ? SongRec.MonitorSource.Input : SongRec.MonitorSource.Monitor
    }
    function monitorSourceToString(source) {
        if (source === SongRec.MonitorSource.Monitor) {
            return "monitor"
        } else {
            return "input"
        }
    }
    readonly property string monitorSourceString: monitorSourceToString(monitorSource)
    property var recognizedTrack: ({ title:"", subtitle:"", url:""})
    property bool manuallyStopped: false

    readonly property int historyMax: 8
    property var history: []

    function handleRecognition(jsonText) {
        try {
            var obj = JSON.parse(jsonText)
            var t = obj.track ?? {}
            var images = t.images ?? {}
            var hub = t.hub ?? {}
            var providers = hub.providers ?? []
            var spotify = providers.find(p => p.type === "SPOTIFY")
            var spotifyUri = (spotify?.actions ?? []).map(a => a.uri).find(u => !!u) ?? ""
            var sections = t.sections ?? []
            var metadata = sections.find(s => s.type === "SONG")?.metadata ?? []
            var album = metadata.find(m => /album/i.test(m.title ?? ""))?.text ?? ""
            var year = metadata.find(m => /release/i.test(m.title ?? ""))?.text ?? ""
            var search = encodeURIComponent(`${t.title ?? ""} ${t.subtitle ?? ""}`.trim())

            var track = {
                title: t.title ?? "",
                subtitle: t.subtitle ?? "",
                url: t.url ?? "",
                cover: images.coverarthq ?? images.coverart ?? "",
                album: album,
                year: year,
                spotifyUrl: spotifyUri,
                youtubeUrl: `https://www.youtube.com/results?search_query=${search}`,
                shazamUrl: t.url ?? ""
            }
            root.recognizedTrack = track
            root.history = [track].concat(root.history).slice(0, root.historyMax)
            musicReconizedProc.running = true
        } catch(e) {
            Quickshell.execDetached(["notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Perhaps what you're listening to is too niche"), "-a", "Shell"])
        }
    }

    Process {
        id: recognizeMusicProc
        running: false
        command: [`${Directories.scriptPath}/musicRecognition/recognize-music.sh`, "-i", root.timeoutInterval, "-t", root.timeoutDuration, "-s", root.monitorSourceString]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.manuallyStopped) {
                    root.manuallyStopped = false
                    return
                }
                handleRecognition(this.text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1) {
                Quickshell.execDetached(["notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Make sure you have songrec installed"), "-a", "Shell"])
            }
        }
    }

    Process {
        id: musicReconizedProc
        running: false
        command: [
            "notify-send",
            Translation.tr("Music Recognized"), 
            root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle, 
            "-A", "Shazam",
            "-A", "YouTube",
            "-a", "Shell"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === "") return
                if (this.text == 0) {
                    Qt.openUrlExternally(root.recognizedTrack.url);
                } else {
                    Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle);
                }
            }
        }
    }
}