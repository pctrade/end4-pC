pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * Downloads user-requested Google Fonts family into a project-local cache
 * directory and registers it with a FontLoader, making the family usable by
 * name everywhere (including custom text widgets).  No shell is involved —
 * families are sanitized and passed to curl as a single argv element, and
 * files are downloaded via curl's `-o` (no shell redirects).
 */
Singleton {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property string lastAppliedFamily: ""

    signal applied(string family)
    signal failed(string message)

    readonly property string cacheDir: Directories.customWidgetFonts

    property string registerSource: ""
    property string _pendingFamily: ""

    // Cached font files discovered at startup are re-registered so persisted
    // `appliedFont` values resolve across reboots.
    property var _cachedFiles: []
    property var _fontLoaders: []
    property bool _cacheRegistered: false
    property Component _fontLoaderComp: Component {
        FontLoader {
            property string src: ""
            source: src
        }
    }

    function _registerCachedFonts() {
        if (root._cacheRegistered || !root.cacheDir) return
        root._cacheRegistered = true
        listProc.autostart = true
        listProc.buffer = ""
        listProc._needStarted = true
        listProc.command = ["ls", "-1", "-A", root.cacheDir]
        listProc.running = true
    }

    function _onCachedListReady() {
        const files = listProc.buffer.split("\n").map(s => s.trim()).filter(s => s.length > 0)
        root._cachedFiles = files
        for (const file of files) {
            const ext = file.toLowerCase()
            if (!ext.endsWith(".woff2") && !ext.endsWith(".ttf")) continue
            const loader = root._fontLoaderComp.createObject(null, { src: "file://" + root.cacheDir + "/" + file })
            root._fontLoaders.push(loader)
        }
    }

    FontLoader {
        id: registeredFont
        source: root.registerSource
        onStatusChanged: {
            if (registeredFont.status === FontLoader.Ready) {
                root.loading = false
                root.lastAppliedFamily = root._pendingFamily
                root.errorMessage = ""
                const family = root._pendingFamily
                root._pendingFamily = ""
                if (family) root.applied(family)
            } else if (registeredFont.status === FontLoader.Error) {
                if (root._pendingFamily) {
                    root.loading = false
                    root._pendingFamily = ""
                    root.failed(Translation.tr("Failed to load Google font. The downloaded file could not be registered."))
                }
            }
        }
    }

    function sanitizeFamily(name) {
        return String(name ?? "").trim().replace(/[^\w\s-]/g, "").slice(0, 64)
    }

    // Register a cached/downloaded file and guarantee applied() fires even when
    // the same family is applied twice in a row: re-assigning an identical
    // FontLoader.source does not emit statusChanged, so a naive apply would be
    // a silent no-op with no UI feedback.
    function _registerFontFromFile(family, absolutePath) {
        const src = "file://" + absolutePath
        root._pendingFamily = family
        if (root.registerSource === src) {
            if (registeredFont.status === FontLoader.Ready) {
                root.loading = false
                root._pendingFamily = ""
                root.applied(family)
            } else {
                root.registerSource = ""
                root.registerSource = src
            }
            return
        }
        root.registerSource = src
    }

    // A recent-browser user-agent makes Google serve woff2 (variable) fonts
    // instead of plain ttf, which produces smaller caches and better support.
    readonly property string _browserUA: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    function apply(rawFamily) {
        const family = root.sanitizeFamily(rawFamily)
        if (family === "") {
            root.failed(Translation.tr("Please enter a font name."))
            return
        }
        if (root.loading) return
        root.loading = true
        root.errorMessage = ""
        root._pendingFamily = family

        // Cache-first: if this exact family is already in the local font
        // cache, register it directly instead of hitting the network again.
        // Downloads happen only on an explicit Apply click.
        const fname = root._safeFileName(family) + ".woff2"
        if (root._cachedFiles.includes(fname)) {
            root._registerFontFromFile(family, root.cacheDir + "/" + fname)
            return
        }

        // Ensure the cache dir exists first; chain the css fetch on its exit.
        cssProc.requestedFamily = family
        mkdirProc.directory = root.cacheDir
        mkdirProc._needStarted = true
        mkdirProc.command = ["mkdir", "-p", mkdirProc.directory]
        mkdirProc.running = true
    }

    function _onCssReady(family, css) {
        if (!css || css.length === 0) {
            root.loading = false
            root.failed(Translation.tr("Font \"%1\" not found.").arg(family))
            return
        }
        const parsed = root._parseCss(css)
        const realFamily = parsed.family || family
        if (!parsed.url) {
            root.loading = false
            root.failed(Translation.tr("Font \"%1\" not found.").arg(family))
            return
        }
        root._pendingFamily = realFamily
        downloadProc.fname = root._safeFileName(cssProc.requestedFamily) + ".woff2"
        downloadProc.downloadPath = root.cacheDir + "/" + downloadProc.fname
        downloadProc._needStarted = true
        downloadProc.command = ["curl", "-sL", "--max-time", "60", "-A", root._browserUA, parsed.url, "-o", downloadProc.downloadPath]
        downloadProc.running = true
    }

    function _safeFileName(family) {
        return family.replace(/[^\w-]+/g, "_")
    }

    // Pull the first font-face out of the css2 response. Family names are
    // quoted; we prefer the first src url (woff2 by default).
    function _parseCss(css) {
        const familyMatch = /font-family\s*:\s*['"]?([^'"}{;]+?)['"]?\s*;/i.exec(css)
        const family = familyMatch ? familyMatch[1].trim() : ""
        const urlMatch = /url\((['"]?)([^'")]+)\1\)/i.exec(css)
        const url = urlMatch ? urlMatch[2].trim() : ""
        return { family: family, url: url }
    }

    Process {
        id: cssProc
        property string requestedFamily: ""
        property string buffer: ""
        property string errBuffer: ""
        property bool _needStarted: false
        onStarted: { cssProc._needStarted = false }
        onRunningChanged: {
            if (!root.loading) return
            if (running) {
                cssProc._needStarted = false
                cssProc.errBuffer = ""
                cssProc.buffer = ""
            } else if (cssProc._needStarted) {
                cssProc._needStarted = false
                root.loading = false
                root.failed(Translation.tr("Failed to execute curl for \"%1\". Is curl installed?").arg(cssProc.requestedFamily))
            }
        }
        stdout: SplitParser {
            onRead: data => { cssProc.buffer += data }
        }
        stderr: SplitParser {
            onRead: data => { cssProc.errBuffer += data }
        }
        onExited: (exitCode, exitStatus) => {
            cssProc._needStarted = false
            if (exitCode !== 0) {
                root.loading = false
                root.failed(Translation.tr("Network error while checking \"%1\". (%2)%3").arg(cssProc.requestedFamily).arg(exitCode).arg(cssProc.errBuffer.length > 0 ? "\n" + cssProc.errBuffer.trim() : ""))
                return
            }
            root._onCssReady(cssProc.requestedFamily, cssProc.buffer)
        }
    }

    Process {
        id: listProc
        property string buffer: ""
        property bool autostart: false
        property bool _needStarted: false
        onStarted: { listProc._needStarted = false }
        onRunningChanged: {
            if (listProc.running) {
                listProc._needStarted = false
                listProc.buffer = ""
            } else if (listProc._needStarted && listProc.autostart) {
                listProc._needStarted = false
                console.warn("GoogleFonts: failed to start 'ls' command in cache listing.")
            }
        }
        stdout: SplitParser {
            onRead: data => { listProc.buffer += data }
        }
        onExited: (exitCode) => {
            listProc._needStarted = false
            if (!listProc.autostart) return
            if (exitCode === 0) root._onCachedListReady()
        }
    }

    Process {
        id: downloadProc
        property string downloadPath: ""
        property string fname: ""
        property bool _needStarted: false
        onStarted: { downloadProc._needStarted = false }
        onRunningChanged: {
            if (!root.loading) return
            if (running) {
                downloadProc._needStarted = false
            } else if (downloadProc._needStarted) {
                downloadProc._needStarted = false
                root.loading = false
                root.failed(Translation.tr("Failed to execute curl for font download. Is curl installed?"))
            }
        }
        onExited: (exitCode, exitStatus) => {
            downloadProc._needStarted = false
            if (exitCode !== 0) {
                root.loading = false
                const badFamily = root._pendingFamily
                root._pendingFamily = ""
                root.failed(Translation.tr("Unable to download font \"%1\". (%2)").arg(badFamily).arg(exitCode))
                return
            }
            if (root._pendingFamily) {
                verifyProc.buffer = ""
                verifyProc._needStarted = true
                verifyProc.command = ["wc", "-c", downloadProc.downloadPath]
                verifyProc.running = true
            } else {
                root.loading = false
                root.failed(Translation.tr("Downloaded font could not be identified."))
            }
        }
    }

    Process {
        id: verifyProc
        property string buffer: ""
        property bool _needStarted: false
        onStarted: { verifyProc._needStarted = false }
        onRunningChanged: {
            if (!root.loading) return
            if (running) {
                verifyProc._needStarted = false
                verifyProc.buffer = ""
            } else if (verifyProc._needStarted) {
                verifyProc._needStarted = false
                root.loading = false
                root.failed(Translation.tr("Failed to execute wc for verification."))
            }
        }
        stdout: SplitParser {
            onRead: data => { verifyProc.buffer += data }
        }
        onExited: (exitCode, exitStatus) => {
            verifyProc._needStarted = false
            const fam = root._pendingFamily
            const bytes = parseInt(verifyProc.buffer.trim().split(/\s+/)[0] ?? "0", 10)
            root.loading = false
            if (exitCode !== 0 || isNaN(bytes) || bytes <= 0) {
                root._pendingFamily = ""
                root.failed(Translation.tr("Downloaded font file for \"%1\" is empty or invalid.").arg(fam))
                return
            }
            if (root._pendingFamily) {
                if (!root._cachedFiles.includes(downloadProc.fname)) {
                    root._cachedFiles = root._cachedFiles.concat([downloadProc.fname])
                }
                root._registerFontFromFile(fam, downloadProc.downloadPath)
            } else {
                root.failed(Translation.tr("Downloaded font could not be identified."))
            }
        }
    }

    Process {
        id: mkdirProc
        property string directory: ""
        property bool _needStarted: false
        onStarted: { mkdirProc._needStarted = false }
        onRunningChanged: {
            if (!root.loading) return
            if (running) {
                mkdirProc._needStarted = false
            } else if (mkdirProc._needStarted) {
                mkdirProc._needStarted = false
                root.loading = false
                root.failed(Translation.tr("Failed to create font cache directory. Is mkdir available?"))
            }
        }
        command: ["mkdir", "-p", mkdirProc.directory]
        onExited: (exitCode) => {
            mkdirProc._needStarted = false
            if (exitCode !== 0) {
                root.loading = false
                root.failed(Translation.tr("Could not create font cache directory."))
                return
            }
            if (!cssProc.requestedFamily) {
                root.loading = false
                return
            }
            cssProc._needStarted = true
            cssProc.command = [
                "curl", "-sL", "--max-time", "30", "-A", root._browserUA,
                "https://fonts.googleapis.com/css2?family="
                    + encodeURIComponent(cssProc.requestedFamily).replace(/%20/g, "+")
            ]
            cssProc.running = true
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._registerCachedFonts()
        }
    }

    Component.onCompleted: {
        if (Config.ready) root._registerCachedFonts()
    }
}