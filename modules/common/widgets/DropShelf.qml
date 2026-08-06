pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common.functions
import qs

Singleton {
    id: root
    property var items: []
    property int maxItems: 30

    function addItems(urls) {
        let arr = [...items]
        for (const url of urls) {
            const path = FileUtils.trimFileProtocol(decodeURIComponent(url.toString()))
            if (!arr.includes(path) && arr.length < root.maxItems) {
                arr.push(path)
            }
        }
        root.items = arr
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
        GlobalStates.dropShelfOpen = false
    }

    function hide() {
        GlobalStates.dropShelfOpen = false
    }

    Process {
        id: copyProc
        property string payload: ""
        command: ["bash", "-c", `printf '%s' '${StringUtils.shellSingleQuoteEscape(copyProc.payload)}' | wl-copy --type text/uri-list`]
    }
}