pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    readonly property var settings: Config.options.background.collage
    readonly property bool enabled: root.settings.enable
    readonly property int maxTiles: 6
    readonly property int gap: root.settings.gap
    readonly property int margin: root.settings.margin
    readonly property int radius: root.settings.radius
    readonly property int primaryId: root.settings.primaryId
    readonly property var tree: {
        try {
            return JSON.parse(root.settings.tree)
        } catch (error) {
            return { t: "leaf", id: 1, img: "" }
        }
    }
    readonly property int leafCount: root.countLeaves(root.tree)
    readonly property string primaryImage: root.imageForLeaf(root.findLeaf(root.tree, root.primaryId) ?? root.firstLeaf(root.tree))

    property bool dragging: false
    property var liveRatios: ({})

    property bool armed: false
    property bool entranceActive: false
    property int entranceSerial: 0

    function armEntrance() {
        root.armed = true
        armTimer.restart()
    }

    function startEntrance(reason) {
        if (!root.armed || !root.enabled) return
        root.armed = false
        armTimer.stop()
        root.entranceActive = true
        root.entranceSerial += 1
        activeTimer.restart()
    }

    Timer {
        id: armTimer
        interval: 8000
        onTriggered: {
            root.armed = false
        }
    }

    Timer {
        id: activeTimer
        interval: 6000
        onTriggered: {
            root.entranceActive = false
        }
    }

    Connections {
        target: root.settings
        function onTreeChanged() { root.startEntrance("tree changed") }
        function onEnableChanged() { root.startEntrance("enabled") }
    }

    function countLeaves(node) {
        return node.t === "leaf" ? 1 : root.countLeaves(node.a) + root.countLeaves(node.b)
    }

    function firstLeaf(node) {
        return node.t === "leaf" ? node : root.firstLeaf(node.a)
    }

    function findLeaf(node, id) {
        if (node.t === "leaf") return node.id === id ? node : null
        return root.findLeaf(node.a, id) ?? root.findLeaf(node.b, id)
    }

    function imageForLeaf(leaf) {
        return leaf.img || Config.options.background.wallpaperPath
    }

    function barInsets(screenName) {
        const bar = Config.options.bar
        const frame = bar.showFrame ? bar.frameThickness : 0
        const insets = { left: frame, right: frame, top: frame, bottom: frame }
        const onScreen = bar.screenList.length === 0 || bar.screenList.includes(screenName)
        if (GlobalStates.barOpen && !GlobalStates.screenLocked && onScreen && !bar.autoHide.enable) {
            const thickness = bar.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
            const edge = bar.vertical ? (bar.bottom ? "right" : "left") : (bar.bottom ? "bottom" : "top")
            insets[edge] = Math.max(insets[edge], thickness)
        }
        return insets
    }

    function layout(width, height, insets) {
        const leaves = []
        const splits = []
        const gap = root.gap
        const eps = 0.0005
        const margin = root.margin
        const x0 = margin + insets.left
        const y0 = margin + insets.top
        const areaWidth = Math.max(1, width - x0 - margin - insets.right)
        const areaHeight = Math.max(1, height - y0 - margin - insets.bottom)

        function walk(node, fx, fy, fw, fh, path) {
            if (node.t === "leaf") {
                const left = fx < eps ? 0 : gap / 2
                const right = fx + fw > 1 - eps ? 0 : gap / 2
                const top = fy < eps ? 0 : gap / 2
                const bottom = fy + fh > 1 - eps ? 0 : gap / 2
                leaves.push({
                    id: node.id,
                    src: root.imageForLeaf(node),
                    x: x0 + fx * areaWidth + left,
                    y: y0 + fy * areaHeight + top,
                    w: Math.max(1, fw * areaWidth - left - right),
                    h: Math.max(1, fh * areaHeight - top - bottom)
                })
                return
            }
            const ratio = root.liveRatios[path] ?? node.r
            const vertical = node.d === "v"
            const edgeStart = vertical ? (fy < eps ? 0 : gap / 2) : (fx < eps ? 0 : gap / 2)
            const edgeEnd = vertical ? (fy + fh > 1 - eps ? 0 : gap / 2) : (fx + fw > 1 - eps ? 0 : gap / 2)
            splits.push({
                path: path,
                d: node.d,
                r: ratio,
                fx: fx, fy: fy, fw: fw, fh: fh,
                line: vertical ? x0 + (fx + fw * ratio) * areaWidth : y0 + (fy + fh * ratio) * areaHeight,
                from: vertical ? y0 + fy * areaHeight + edgeStart : x0 + fx * areaWidth + edgeStart,
                to: vertical ? y0 + (fy + fh) * areaHeight - edgeEnd : x0 + (fx + fw) * areaWidth - edgeEnd
            })
            if (vertical) {
                walk(node.a, fx, fy, fw * ratio, fh, path + "a")
                walk(node.b, fx + fw * ratio, fy, fw * (1 - ratio), fh, path + "b")
            } else {
                walk(node.a, fx, fy, fw, fh * ratio, path + "a")
                walk(node.b, fx, fy + fh * ratio, fw, fh * (1 - ratio), path + "b")
            }
        }

        walk(root.tree, 0, 0, 1, 1, "")
        return { leaves: leaves, splits: splits, area: { x: x0, y: y0, w: areaWidth, h: areaHeight } }
    }

    function clone(node) {
        return JSON.parse(JSON.stringify(node))
    }

    function save(tree) {
        root.settings.tree = JSON.stringify(tree)
    }

    function mapLeaf(node, id, replacement) {
        if (node.t === "leaf") return node.id === id ? replacement(node) : node
        return { t: "split", d: node.d, r: node.r, a: root.mapLeaf(node.a, id, replacement), b: root.mapLeaf(node.b, id, replacement) }
    }

    function splitLeaf(id, direction) {
        if (root.leafCount >= root.maxTiles) return
        const newId = root.settings.nextId
        const next = root.mapLeaf(root.tree, id, leaf => ({
            t: "split", d: direction, r: 0.5,
            a: leaf,
            b: { t: "leaf", id: newId, img: root.imageForLeaf(leaf) }
        }))
        root.settings.nextId = newId + 1
        root.save(next)
    }

    function removeNode(node, id) {
        if (node.t === "leaf") return node
        if (node.a.t === "leaf" && node.a.id === id) return node.b
        if (node.b.t === "leaf" && node.b.id === id) return node.a
        return { t: "split", d: node.d, r: node.r, a: root.removeNode(node.a, id), b: root.removeNode(node.b, id) }
    }

    function removeLeaf(id) {
        if (root.leafCount <= 1) return
        const next = root.removeNode(root.tree, id)
        root.save(next)
        if (id === root.primaryId) root.setPrimary(root.firstLeaf(next).id)
    }

    function setRatio(path, ratio) {
        const next = root.clone(root.tree)
        let node = next
        for (const step of path) node = step === "a" ? node.a : node.b
        node.r = Math.max(0.15, Math.min(0.85, ratio))
        root.save(next)
    }

    function setImage(id, path) {
        root.save(root.mapLeaf(root.tree, id, leaf => ({ t: "leaf", id: leaf.id, img: path })))
        if (id === root.primaryId && path !== Config.options.background.wallpaperPath)
            Wallpapers.select(path)
    }

    function setPrimary(id) {
        root.settings.primaryId = id
        const leaf = root.findLeaf(root.tree, id)
        if (leaf && leaf.img && leaf.img !== Config.options.background.wallpaperPath)
            Wallpapers.select(leaf.img)
    }

    function leaf() {
        return { t: "leaf" }
    }

    function split(d, r, a, b) {
        return { t: "split", d: d, r: r, a: a, b: b }
    }

    readonly property var presets: {
        const L = root.leaf
        const S = root.split
        return [
            { name: "duo", tree: S("v", 0.5, L(), L()) },
            { name: "stack", tree: S("h", 0.5, L(), L()) },
            { name: "heroLeft", tree: S("v", 0.62, L(), S("h", 0.5, L(), L())) },
            { name: "heroRight", tree: S("v", 0.38, S("h", 0.5, L(), L()), L()) },
            { name: "heroTop", tree: S("h", 0.6, L(), S("v", 0.5, L(), L())) },
            { name: "columns", tree: S("v", 0.333, L(), S("v", 0.5, L(), L())) },
            { name: "grid", tree: S("v", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L())) },
            { name: "heroThree", tree: S("v", 0.6, L(), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "mosaic", tree: S("v", 0.5, S("h", 0.5, L(), S("v", 0.5, L(), L())), S("h", 0.5, S("v", 0.5, L(), L()), L())) },
            { name: "sixGrid", tree: S("v", 0.333, S("h", 0.5, L(), L()), S("v", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L()))) },
            { name: "triptychRows", tree: S("h", 0.333, L(), S("h", 0.5, L(), L())) },
            { name: "pillar", tree: S("v", 0.25, L(), S("v", 0.667, L(), L())) },
            { name: "heroBottom", tree: S("h", 0.62, S("v", 0.5, L(), L()), L()) },
            { name: "sidebarStack", tree: S("v", 0.3, S("h", 0.333, L(), S("h", 0.5, L(), L())), L()) },
            { name: "filmstrip", tree: S("h", 0.7, L(), S("v", 0.333, L(), S("v", 0.5, L(), L()))) },
            { name: "twinRail", tree: S("v", 0.7, S("h", 0.5, L(), L()), S("h", 0.25, L(), S("h", 0.333, L(), S("h", 0.5, L(), L())))) },
            { name: "topThree", tree: S("h", 0.5, S("v", 0.333, L(), S("v", 0.5, L(), L())), S("v", 0.5, L(), L())) },
            { name: "bigPlusFour", tree: S("v", 0.5, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L()))) },
            { name: "heroFive", tree: S("v", 0.5, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.333, L(), S("v", 0.5, L(), L())))) },
            { name: "cornerFour", tree: S("v", 0.5, L(), S("h", 0.5, L(), S("v", 0.5, L(), L()))) },
            { name: "wideBanner", tree: S("h", 0.3, L(), S("v", 0.5, L(), L())) },
            { name: "unevenRight", tree: S("v", 0.5, L(), S("h", 0.7, L(), L())) },
            { name: "unevenLeft", tree: S("v", 0.5, S("h", 0.35, L(), L()), L()) },
            { name: "railThree", tree: S("v", 0.35, L(), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "fourColumns", tree: S("v", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L())) },
            { name: "fourRows", tree: S("h", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L())) },
            { name: "centerHero", tree: S("v", 0.25, S("h", 0.5, L(), L()), S("v", 0.667, L(), S("h", 0.5, L(), L()))) },
            { name: "heroTwoRows", tree: S("h", 0.55, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L()))) },
            { name: "cornerSix", tree: S("v", 0.6, S("h", 0.6, L(), S("v", 0.5, L(), L())), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "staggered", tree: S("v", 0.5, S("h", 0.333, L(), S("h", 0.5, L(), L())), S("h", 0.5, L(), L())) }
        ]
    }

    function presetLabel(name) {
        const words = name.replace(/([A-Z])/g, " $1").toLowerCase()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }

    readonly property var presetOptions: [{ displayName: Translation.tr("Custom"), value: "" }].concat(
        root.presets.map(preset => ({
            displayName: root.presetLabel(preset.name) + " (" + root.countLeaves(preset.tree) + ")",
            value: preset.name
        }))
    )

    readonly property string currentPreset: {
        const current = root.signature(root.tree)
        const match = root.presets.find(preset => root.signature(preset.tree) === current)
        return match ? match.name : ""
    }

    function applyPresetByName(name) {
        const match = root.presets.find(preset => preset.name === name)
        if (match) root.applyPreset(match.tree)
    }

    function signature(node) {
        if (node.t === "leaf") return "L"
        return node.d + Math.round(node.r * 100) + "(" + root.signature(node.a) + "," + root.signature(node.b) + ")"
    }

    function collectLeaves(node, out) {
        if (node.t === "leaf") out.push(node)
        else {
            root.collectLeaves(node.a, out)
            root.collectLeaves(node.b, out)
        }
        return out
    }

    function rects(node, x, y, w, h, out) {
        if (node.t === "leaf") {
            out.push({ x: x, y: y, w: w, h: h })
        } else if (node.d === "v") {
            root.rects(node.a, x, y, w * node.r, h, out)
            root.rects(node.b, x + w * node.r, y, w * (1 - node.r), h, out)
        } else {
            root.rects(node.a, x, y, w, h * node.r, out)
            root.rects(node.b, x, y + h * node.r, w, h * (1 - node.r), out)
        }
        return out
    }

    function applyPreset(spec) {
        const current = root.collectLeaves(root.tree, [])
        const primary = root.findLeaf(root.tree, root.primaryId) ?? current[0]
        const images = [root.imageForLeaf(primary)].concat(current.filter(l => l !== primary).map(l => root.imageForLeaf(l)))
        let nextId = 1
        function assign(node) {
            if (node.t === "leaf") {
                const id = nextId++
                return { t: "leaf", id: id, img: images[(id - 1) % images.length] }
            }
            return { t: "split", d: node.d, r: node.r, a: assign(node.a), b: assign(node.b) }
        }
        const next = assign(spec)
        root.settings.nextId = nextId
        root.settings.primaryId = 1
        root.save(next)
    }

    function reset() {
        root.settings.nextId = 2
        root.settings.primaryId = 1
        root.save({ t: "leaf", id: 1, img: Config.options.background.wallpaperPath })
    }

    function isImagePath(path) {
        return /\.(png|jpe?g|webp|bmp|gif)$/i.test(path)
    }

    function dropImage(id, urls) {
        if (!urls || urls.length !== 1) return false
        const path = FileUtils.trimFileProtocol(decodeURIComponent(urls[0].toString()))
        if (!root.isImagePath(path)) return false
        root.setImage(id, path)
        return true
    }

    function dropShapeImage(urls) {
        if (!urls || urls.length !== 1) return false
        const path = FileUtils.trimFileProtocol(decodeURIComponent(urls[0].toString()))
        if (!root.isImagePath(path)) return false
        Config.options.background.centeredWallpaperImage = path
        return true
    }

    Process {
        id: pickProc
        property int tileId: -1
        stdout: StdioCollector {
            id: pickOutput
        }
        onExited: code => {
            if (code !== 0) return
            const path = pickOutput.text.trim()
            if (path !== "") root.setImage(pickProc.tileId, path)
        }
    }

    function pickImage(id) {
        const startDir = FileUtils.trimFileProtocol(Wallpapers.directory.toString()) || (Quickshell.env("HOME") + "/Pictures")
        pickProc.tileId = id
        pickProc.command = ["kdialog", "--getopenfilename", startDir, "image/png image/jpeg image/webp image/gif"]
        pickProc.running = true
    }

    Connections {
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (!root.enabled) return
            const path = Config.options.background.wallpaperPath
            const leaf = root.findLeaf(root.tree, root.primaryId)
            if (leaf && leaf.img !== path)
                root.save(root.mapLeaf(root.tree, root.primaryId, node => ({ t: "leaf", id: node.id, img: path })))
        }
    }
}
