pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string thumbsDir: `${Quickshell.env("HOME")}/.cache/quickshell/presets_local_thumbs`

    property var queued: ({})
    property int attempts: 0

    readonly property var thumbSet: {
        const names = new Set();
        for (let i = 0; i < thumbsModel.count; i++)
            names.add(thumbsModel.get(i, "fileName"));
        return names;
    }

    function shQuote(str) {
        return "'" + String(str).replace(/'/g, "'\"'\"'") + "'";
    }

    function cleanPath(source) {
        const raw = String(source ?? "");
        if (raw === "") return "";
        return decodeURIComponent(raw.replace(/^file:\/\//, ""));
    }

    function keyFor(source) {
        return Qt.md5(root.cleanPath(source));
    }

    function thumbFor(source) {
        const clean = root.cleanPath(source);
        if (clean === "") return "";
        const name = `${root.keyFor(clean)}.jpg`;
        return root.thumbSet.has(name) ? `${root.thumbsDir}/${name}` : "";
    }

    function request(source) {
        const clean = root.cleanPath(source);
        if (clean === "" || clean.startsWith("http")) return;
        if (root.thumbSet.has(`${root.keyFor(clean)}.jpg`)) return;
        if (root.queued[clean]) return;
        root.queued[clean] = true;
        batchTimer.restart();
    }

    function generate() {
        if (thumbProc.running) return;
        const paths = Object.keys(root.queued);
        if (paths.length === 0) {
            root.attempts = 0;
            return;
        }
        root.queued = ({});
        const dir = root.thumbsDir;
        let script = `D=${root.shQuote(dir)}; gen() { out="$D/$1.jpg"; [ -s "$out" ] && [ "$out" -nt "$2" ] && return; if magick "$2[0]" -auto-orient -resize 720x -quality 82 "jpg:$D/.$1.part" && mv -f "$D/.$1.part" "$out"; then echo "THUMB ok $1"; else echo "THUMB fail $1"; fi; rm -f "$D/.$1.part"; }; `;
        paths.forEach((path, i) => {
            script += `gen ${root.keyFor(path)} ${root.shQuote(path)} & `;
            if (i % 4 === 3) script += "wait; ";
        });
        script += "wait";
        thumbProc.command = ["bash", "-c", script];
        thumbProc.running = true;
    }

    Timer {
        id: batchTimer
        interval: 120
        onTriggered: root.generate()
    }

    FolderListModel {
        id: thumbsModel
        folder: ""
        showDirs: false
        nameFilters: ["*.jpg"]
    }

    Process {
        id: prepareProc
        running: true
        command: ["bash", "-c", `mkdir -p ${root.shQuote(root.thumbsDir)} && for f in ${root.shQuote(root.thumbsDir)}/*.jpg; do [ -e "$f" ] || continue; magick identify -quiet "$f" >/dev/null 2>&1 || rm -f "$f"; done; rm -f ${root.shQuote(root.thumbsDir)}/.*.part`]
        onExited: thumbsModel.folder = Qt.resolvedUrl(root.thumbsDir)
    }

    Process {
        id: thumbProc
        onExited: Qt.callLater(root.generate)
    }
}
