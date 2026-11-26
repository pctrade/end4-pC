pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property list<string> entries: []

    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))

    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }
        if (root.sloppySearch) {
            const results = entries.slice(0, 100).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results.map(item => item.entry)
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function entryId(entry) {
        return entry.split("\t")[0]
    }

    function entryText(entry) {
        return entry.replace(/^\s*\S+\s+/, "")
    }

    function pinIndex(entry) {
        const pins = Config.options.search.clipboardPins ?? []
        const id = root.entryId(entry)
        const text = root.entryText(entry)
        const image = root.entryIsImage(entry)
        return pins.findIndex(pin => pin.id === id || (!image && pin.text !== "" && pin.text === text))
    }

    function isPinned(entry) {
        return root.pinIndex(entry) !== -1
    }

    function togglePin(entry) {
        const pins = (Config.options.search.clipboardPins ?? []).slice()
        const index = root.pinIndex(entry)
        if (index !== -1) pins.splice(index, 1)
        else pins.push({ id: root.entryId(entry), text: root.entryIsImage(entry) ? "" : root.entryText(entry), content: "" })
        Config.options.search.clipboardPins = pins
        if (index === -1 && !root.entryIsImage(entry)) {
            pinContentProc.pinId = root.entryId(entry);
            pinContentProc.running = true;
        }
    }

    function missingPins(search) {
        if (root.entries.length === 0) return [];
        const pins = Config.options.search.clipboardPins ?? [];
        const ids = new Set(root.entries.map(entry => root.entryId(entry)));
        const texts = new Set(root.entries.map(entry => root.entryText(entry)));
        const query = (search ?? "").trim().toLowerCase();
        return pins.filter(pin => pin.text && !ids.has(pin.id) && !texts.has(pin.text)
            && (query === "" || pin.text.toLowerCase().includes(query)));
    }

    function removePin(pin) {
        Config.options.search.clipboardPins = (Config.options.search.clipboardPins ?? []).filter(item => item.id !== pin.id);
    }

    Process {
        id: pinContentProc
        property string pinId: ""
        command: ["bash", "-c", `${root.cliphistBinary} decode ${pinContentProc.pinId} | head -c 20000`]
        stdout: StdioCollector {
            id: pinContentOut
        }
        onExited: {
            const pins = (Config.options.search.clipboardPins ?? []).map(pin => pin.id === pinContentProc.pinId ? { id: pin.id, text: pin.text, content: pinContentOut.text } : pin);
            Config.options.search.clipboardPins = pins;
        }
    }

    function dedupePinned() {
        if (dedupeProc.running) return;
        const pins = (Config.options.search.clipboardPins ?? []).slice();
        const groups = [];
        let pinsChanged = false;
        pins.forEach((pin, index) => {
            if (!pin.text) return;
            const matches = root.entries.filter(entry => !root.entryIsImage(entry) && root.entryText(entry) === pin.text);
            if (matches.length === 0) return;
            const newestId = root.entryId(matches[0]);
            if (pin.id !== newestId) {
                pins[index] = { id: newestId, text: pin.text };
                pinsChanged = true;
            }
            if (matches.length > 1) groups.push(matches.map(entry => root.entryId(entry)));
        });
        if (pinsChanged) Config.options.search.clipboardPins = pins;
        if (groups.length === 0) return;
        dedupeProc.command = ["python3", "-I", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/clipboard/dedupe.py`, JSON.stringify(groups)];
        dedupeProc.running = true;
    }

    function refresh() {
        readProc.buffer = []
        readProc.running = true
    }

    function copy(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy`]);
        }
    }

    function paste(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && wl-paste`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy; ${root.pressPasteCommand}`]);
        }
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: dedupeProc
        stdout: StdioCollector {
            id: dedupeOut
        }
        onExited: {
            if (parseInt(dedupeOut.text) > 0) root.refresh();
        }
    }

    Process {
        id: deleteProc
        property string entry: ""
        command: ["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(deleteProc.entry)}' | ${root.cliphistBinary} delete`]
        function deleteEntry(entry) {
            deleteProc.entry = entry;
            deleteProc.running = true;
            deleteProc.entry = "";
        }
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    Process {
        id: wipeProc
        command: ["bash", "-c", `${root.cliphistBinary} wipe; rm -rf ~/.cache/cliphist/db`]
        onExited: (exitCode, exitStatus) => {
            root.entries = [];
            root.refresh();
        }
    }

    function wipe() {
        root.entries = [];
        wipeProc.running = true;
    }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            delayedUpdateTimer.restart()
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: Config.options.hacks.arbitraryRaceConditionDelay
        repeat: false
        onTriggered: {
            root.refresh()
        }
    }

    Process {
        id: readProc
        property var buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = readProc.buffer
                root.dedupePinned()
            } else {
                root.entries = []
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }
}