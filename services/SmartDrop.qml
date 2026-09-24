pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Smart Drop (seção 21): what can be done with whatever is being dragged onto the island, by kind.
 *
 * To add a kind: extend kindOf(). To add an action: put it in `catalog` and handle it in run(). Actions get
 * paths and text as separate argv entries (never spliced into a shell string), so a file name with quotes or
 * `$(…)` in it is just a file name.
 */
Singleton {
    id: root

    readonly property var catalog: ({
        shelf:    { icon: "move_to_inbox", label: Translation.tr("Drawer") },
        open:     { icon: "open_in_new", label: Translation.tr("Open") },
        edit:     { icon: "edit", label: Translation.tr("Edit") },
        copy:     { icon: "content_copy", label: Translation.tr("Copy") },
        copyPath: { icon: "link", label: Translation.tr("Path") },
        editor:   { icon: "code", label: Translation.tr("Editor") },
        extract:  { icon: "unarchive", label: Translation.tr("Extract") },
        png:      { icon: "transform", label: "PNG" },
        qr:       { icon: "qr_code_2", label: "QR" }
    })

    function pathOf(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }

    function kindOf(urls, text) {
        const list = Array.from(urls ?? [])
        if (list.length === 0) return /^https?:\/\/\S+$/.test((text ?? "").trim()) ? "url" : "text"
        if (list.length > 1) return "files"
        if (/^https?:/.test(String(list[0]))) return "url"
        const path = root.pathOf(list[0]).toLowerCase()
        if (/\.(png|jpe?g|webp|gif|bmp|avif|heic|tiff?)$/.test(path)) return "image"
        if (/\.pdf$/.test(path)) return "pdf"
        if (/\.(zip|tar|tgz|gz|xz|bz2|zst|7z|rar)$/.test(path)) return "archive"
        if (/\.(txt|md|js|mjs|ts|tsx|jsx|py|qml|sh|fish|zsh|json|c|h|cpp|hpp|rs|go|java|kt|css|scss|html|xml|ya?ml|toml|lua|php|sql|rb|ini|conf)$/.test(path)) return "code"
        return "file"
    }

    // The first one is what a drop does when you don't aim at anything in particular
    function actionsFor(urls, text) {
        switch (root.kindOf(urls, text)) {
            case "image":   return ["shelf", "edit", "copy", "png"]
            case "pdf":     return ["shelf", "open", "copyPath"]
            case "archive": return ["extract", "shelf", "open"]
            case "code":    return ["shelf", "copy", "editor"]
            case "url":     return ["open", "copy", "qr", "shelf"]
            case "text":    return ["shelf", "copy"]
            case "files":   return ["shelf", "copyPath"]
            default:        return ["shelf", "open", "copyPath"]
        }
    }

    function sh(script, args) {
        Quickshell.execDetached(["sh", "-c", script, "sh", ...args])
    }

    // Runs everything except "shelf" (the island keeps that one: it knows how to fill the drawer).
    // Returns what to say about it afterwards: { icon, label }.
    function run(action, urls, text) {
        const paths = Array.from(urls ?? []).map(u => /^https?:/.test(String(u)) ? String(u) : root.pathOf(u))
        const first = paths[0] ?? (text ?? "").trim()
        switch (action) {
            case "open":
                root.sh('xdg-open "$1"', [first])
                return { icon: "open_in_new", label: Translation.tr("Opened") }
            case "edit":
                root.sh('swappy -f "$1"', [first])
                return { icon: "edit", label: Translation.tr("Opening the editor") }
            case "copy":
                if (paths.length > 0 && !/^https?:/.test(first)) root.sh('wl-copy < "$1"', [first])
                else root.sh('printf %s "$1" | wl-copy', [first])
                return { icon: "content_copy", label: Translation.tr("Copied") }
            case "copyPath":
                root.sh('printf "%s\\n" "$@" | head -c -1 | wl-copy', paths)
                return { icon: "link", label: Translation.tr("Path copied") }
            case "editor":
                root.sh('code "$1"', [first])
                return { icon: "code", label: Translation.tr("Opening in the editor") }
            case "extract":
                root.sh('dir="${1%.*}"; dir="${dir%.tar}"; mkdir -p "$dir" && bsdtar -xf "$1" -C "$dir" && xdg-open "$dir"', [first])
                return { icon: "unarchive", label: Translation.tr("Extracting…") }
            case "png":
                root.sh('magick "$1" "${1%.*}.png"', [first])
                return { icon: "transform", label: Translation.tr("Saved as PNG") }
            case "qr":
                root.sh('out="/tmp/quickshell/island/qr-$(date +%s).png"; mkdir -p "${out%/*}" && qrencode -s 10 -o "$out" "$1" && xdg-open "$out"', [first])
                return { icon: "qr_code_2", label: Translation.tr("QR code ready") }
            default:
                return null
        }
    }
}
