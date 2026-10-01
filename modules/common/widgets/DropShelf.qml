pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs

Singleton {
    id: root
    property var items: []
    property var addedAt: ({})
    property int maxItems: 30
    readonly property string storeDir: FileUtils.trimFileProtocol(`${Directories.state}/user/dropshelf`)
    readonly property string storeFile: FileUtils.trimFileProtocol(`${Directories.state}/user/dropshelf.json`)
    readonly property int expireDays: Config.options.bar.dynamicIsland.shelfExpireDays ?? 14
    property string toolStatus: ""

    signal itemsAdded(var paths)

    function fileName(path) {
        return (path ?? "").split("/").pop()
    }

    function isImage(path) {
        return /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(path ?? "")
    }

    function isPdf(path) {
        return /\.pdf$/i.test(path ?? "")
    }

    function iconFor(path) {
        const p = path ?? ""
        if (/\.pdf$/i.test(p)) return "picture_as_pdf"
        if (/\.(mp4|mkv|webm|mov|avi)$/i.test(p)) return "movie"
        if (/\.(mp3|flac|ogg|wav|m4a|opus)$/i.test(p)) return "audio_file"
        if (/\.(zip|tar|gz|xz|7z|rar|zst)$/i.test(p)) return "folder_zip"
        if (/\.(txt|md|json|qml|js|py|c|cpp|rs|ts|html|css|sh)$/i.test(p)) return "description"
        if (!/\.[A-Za-z0-9]{1,8}$/.test(p)) return "folder"
        return "draft"
    }

    function normalize(url) {
        return FileUtils.trimFileProtocol(decodeURIComponent(url.toString()))
    }

    function addItems(urls) {
        const arr = [...root.items]
        const stamps = Object.assign({}, root.addedAt)
        const added = []
        const remote = []
        for (const url of urls) {
            const text = url.toString()
            if (/^https?:\/\//.test(text)) {
                remote.push(text)
                continue
            }
            const path = root.normalize(text)
            if (path && !arr.includes(path) && arr.length < root.maxItems) {
                arr.push(path)
                stamps[path] = Date.now()
                added.push(path)
            }
        }
        root.addedAt = stamps
        root.items = arr
        root.save()
        if (added.length > 0) root.itemsAdded(added)
        if (remote.length > 0) root.download(remote)
    }

    function addText(text) {
        if (!text || text.trim() === "") return
        const name = `nota-${Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")}.txt`
        writeTextProc.target = `${root.storeDir}/${name}`
        writeTextProc.payload = text
        writeTextProc.running = true
    }

    function download(urls) {
        const script = urls.map(u => {
            const base = decodeURIComponent(u.split("?")[0].split("/").pop() || "download")
            return `f='${root.storeDir}/${StringUtils.shellSingleQuoteEscape(base)}'; curl -4 -sSL '${StringUtils.shellSingleQuoteEscape(u)}' -o "$f" && echo "$f"`
        }).join("; ")
        downloadProc.command = ["bash", "-c", `mkdir -p '${root.storeDir}'; ${script}`]
        downloadProc.running = true
    }

    function remove(path) {
        const stamps = Object.assign({}, root.addedAt)
        delete stamps[path]
        root.addedAt = stamps
        root.items = root.items.filter(p => p !== path)
        root.save()
    }

    function pruneExpired() {
        if (root.expireDays <= 0) return
        const cutoff = Date.now() - root.expireDays * 24 * 3600 * 1000
        const stamps = Object.assign({}, root.addedAt)
        let changed = false
        for (const path of root.items) {
            if (!stamps[path]) {
                stamps[path] = Date.now()
                changed = true
            }
        }
        const kept = root.items.filter(p => stamps[p] >= cutoff)
        if (kept.length !== root.items.length) {
            for (const gone of root.items.filter(p => !kept.includes(p))) delete stamps[gone]
            root.items = kept
            changed = true
        }
        root.addedAt = stamps
        if (changed) root.save()
    }

    function daysLeft(path) {
        if (root.expireDays <= 0 || !root.addedAt[path]) return -1
        return Math.max(0, Math.ceil((root.addedAt[path] + root.expireDays * 24 * 3600 * 1000 - Date.now()) / (24 * 3600 * 1000)))
    }

    function mergePdfs(paths) {
        if (paths.length < 2) return
        const target = `${root.storeDir}/juntos-${Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")}.pdf`
        const quoted = paths.map(p => `'${StringUtils.shellSingleQuoteEscape(p)}'`).join(" ")
        root.runTool(`mkdir -p '${root.storeDir}' && pdfunite ${quoted} '${target}'`, target, Translation.tr("PDFs merged"))
    }

    function compressPdf(path) {
        const target = `${root.storeDir}/${root.fileName(path).replace(/\.pdf$/i, "")}-comprimido.pdf`
        root.runTool(`mkdir -p '${root.storeDir}' && gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile='${target}' '${StringUtils.shellSingleQuoteEscape(path)}' && du -h '${target}' | cut -f1`,
            target, Translation.tr("PDF compressed"))
    }

    function zipItems(paths) {
        if (!paths || paths.length === 0) return
        const q = p => `'${StringUtils.shellSingleQuoteEscape(p)}'`
        const base = paths.length === 1
            ? root.fileName(paths[0]).replace(/\.[^.\/]+$/, "")
            : `gaveta-${Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")}`
        const target = `${root.storeDir}/${base}.zip`
        const adds = paths.map(p => `(cd ${q(p.replace(/\/[^\/]*$/, "") || "/")} && zip -qr ${q(target)} ${q(root.fileName(p))})`).join(" && ")
        root.runTool(`mkdir -p ${q(root.storeDir)} && rm -f ${q(target)} && ${adds} && du -h ${q(target)} | cut -f1`,
            target, Translation.tr("Compressed"))
    }

    function isArchive(path) {
        return /\.(zip|7z|rar|tar|tgz|tar\.(gz|xz|zst|bz2))$/i.test(path)
    }

    function extract(path) {
        const q = p => `'${StringUtils.shellSingleQuoteEscape(p)}'`
        const dir = `${root.storeDir}/${root.fileName(path).replace(/\.(zip|7z|rar|tar|tgz|tar\.(gz|xz|zst|bz2))$/i, "")}`
        root.runTool(`mkdir -p ${q(dir)} && bsdtar -xf ${q(path)} -C ${q(dir)} && du -sh ${q(dir)} | cut -f1`, dir, Translation.tr("Extracted"))
    }

    function runTool(script, target, successText) {
        root.toolStatus = Translation.tr("Working…")
        toolProc.target = target
        toolProc.successText = successText
        toolProc.command = ["bash", "-c", script]
        toolProc.running = true
    }

    function show(urls, x, y) {
        root.addItems(urls)
        GlobalStates.dropShelfX = x
        GlobalStates.dropShelfY = y
        GlobalStates.dropShelfOpen = true
    }

    function copyAll() {
        if (root.items.length === 0) return
        const uriList = root.items.map(p => "file://" + p).join("\n")
        copyProc.payload = uriList
        copyProc.running = true
    }

    function clear() {
        root.items = []
        root.addedAt = ({})
        root.save()
        GlobalStates.dropShelfOpen = false
    }

    function hide() {
        GlobalStates.dropShelfOpen = false
    }

    function save() {
        shelfFile.setText(JSON.stringify({ items: root.items, addedAt: root.addedAt }))
    }

    Timer {
        interval: 3600 * 1000
        repeat: true
        running: true
        onTriggered: root.pruneExpired()
    }

    FileView {
        id: shelfFile
        path: root.storeFile
        onLoaded: {
            try {
                const parsed = JSON.parse(shelfFile.text())
                if (Array.isArray(parsed)) {
                    root.items = parsed
                } else if (parsed && Array.isArray(parsed.items)) {
                    root.items = parsed.items
                    root.addedAt = parsed.addedAt ?? ({})
                }
                root.pruneExpired()
            } catch (e) {
                console.warn("[DropShelf] Could not read saved items:", e)
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) shelfFile.setText("[]")
        }
    }

    IpcHandler {
        target: "shelf"

        function add(path: string): void {
            root.addItems([path.startsWith("/") ? `file://${path}` : path])
        }
        function remove(path: string): void {
            root.remove(path)
        }
        function clear(): void {
            root.clear()
        }
        function list(): string {
            return root.items.join("\n")
        }
    }

    Process {
        id: copyProc
        property string payload: ""
        command: ["bash", "-c", `printf '%s' '${StringUtils.shellSingleQuoteEscape(copyProc.payload)}' | wl-copy --type text/uri-list`]
    }

    Process {
        id: toolProc
        property string target: ""
        property string successText: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const size = text.trim()
                if (size !== "") toolProc.successText = `${toolProc.successText} · ${size}`
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.toolStatus = toolProc.successText
                root.addItems([`file://${toolProc.target}`])
            } else {
                root.toolStatus = Translation.tr("Something went wrong")
            }
        }
    }

    Process {
        id: writeTextProc
        property string target: ""
        property string payload: ""
        command: ["bash", "-c", `mkdir -p '${root.storeDir}' && printf '%s' '${StringUtils.shellSingleQuoteEscape(writeTextProc.payload)}' > '${writeTextProc.target}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.addItems([`file://${writeTextProc.target}`])
        }
    }

    Process {
        id: downloadProc
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") root.addItems([`file://${line.trim()}`])
            }
        }
    }
}
