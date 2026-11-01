import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common

Item {
    id: root
    property real cardRadius: 0
    property real topLeftRadius: cardRadius
    property real topRightRadius: cardRadius
    property real bottomRightRadius: cardRadius
    property real bottomLeftRadius: cardRadius
    property color tint: "transparent"
    property bool glassEnabled: true
    property bool fullscreenSurface: false
    property real tintStrength: 0
    property real flareLeft: 0
    property real flareRight: 0
    property real hangLeft: 0
    property real hangRight: 0
    property int edge: 0
    readonly property bool live: glassEnabled && (Config.options?.background?.widgets?.glass?.enable ?? false)
    readonly property bool tracking: live && (win?.visible ?? true)

    readonly property var win: QsWindow.window
    readonly property var surfaceScreen: ({
        name: "",
        width: root.Window.width,
        height: root.Window.height,
        devicePixelRatio: root.Window.window?.devicePixelRatio ?? 1
    })
    readonly property var scr: win?.screen ?? (fullscreenSurface && root.Window.window ? surfaceScreen : null)
    readonly property bool floating: !fullscreenSurface && !!win && win.anchors === undefined && win.anchor === undefined
    readonly property bool popup: !fullscreenSurface && !!win && win.anchor !== undefined

    readonly property var floatPos: GlassFloating.positions[win?.title ?? ""] ?? null
    readonly property var floatMonitor: scr ? HyprlandData.monitors.find(m => m.name === scr.name) : null
    readonly property real floatX: floatPos ? floatPos.x - (floatMonitor?.x ?? 0) : 0
    readonly property real floatY: floatPos ? floatPos.y - (floatMonitor?.y ?? 0) : 0
    readonly property bool wantsFloatTracking: live && floating && !!win?.visible
    property bool claimed: false

    function syncClaim() {
        if (root.wantsFloatTracking && !root.claimed) {
            GlassFloating.claim()
            root.claimed = true
        } else if (!root.wantsFloatTracking && root.claimed) {
            GlassFloating.release()
            root.claimed = false
        }
    }

    onWantsFloatTrackingChanged: syncClaim()
    Component.onDestruction: if (root.claimed) GlassFloating.release()

    function panelOffset(w, s) {
        const a = w.anchors
        const m = w.margins
        const pushed = w.exclusionMode !== ExclusionMode.Ignore
        const x = a?.left ? (m?.left ?? 0) + (pushed ? GlassLayers.leftZone : 0)
            : a?.right ? s.width - w.width - (m?.right ?? 0) - (pushed ? GlassLayers.rightZone : 0)
            : (s.width - w.width) / 2
        const y = a?.top ? (m?.top ?? 0) + (pushed ? GlassLayers.topZone : 0)
            : a?.bottom ? s.height - w.height - (m?.bottom ?? 0) - (pushed ? GlassLayers.bottomZone : 0)
            : (s.height - w.height) / 2
        return layerOffset(w, s, Qt.point(x, y))
    }

    function layerOffset(w, s, guess) {
        const mon = GlassLayers.layers[s.name]
        if (!mon) return guess
        const monitor = HyprlandData.monitors.find(m => m.name === s.name)
        const ox = monitor?.x ?? 0
        const oy = monitor?.y ?? 0
        let best = null
        let bestDist = Infinity
        for (const level of Object.values(mon.levels ?? {})) {
            for (const layer of level) {
                if (!layer.namespace.startsWith("quickshell:")) continue
                if (layer.w !== Math.round(w.width) || layer.h !== Math.round(w.height)) continue
                const dist = Math.abs(layer.x - ox - guess.x) + Math.abs(layer.y - oy - guess.y)
                if (dist < bestDist) {
                    bestDist = dist
                    best = layer
                }
            }
        }
        return best ? Qt.point(best.x - ox, best.y - oy) : guess
    }

    function popupOffset(w, s) {
        const an = w.anchor
        const host = an.window
        if (!host) return Qt.point(0, 0)
        const base = host.anchor !== undefined ? popupOffset(host, s) : panelOffset(host, s)
        let rx = an.rect.x, ry = an.rect.y, rw = an.rect.width, rh = an.rect.height
        if (an.item) {
            const p = an.item.mapToItem(null, 0, 0)
            rx = p.x; ry = p.y; rw = an.item.width; rh = an.item.height
        }
        const e = an.edges, g = an.gravity
        const ax = (e & Qt.LeftEdge) ? rx : (e & Qt.RightEdge) ? rx + rw : rx + rw / 2
        const ay = (e & Qt.TopEdge) ? ry : (e & Qt.BottomEdge) ? ry + rh : ry + rh / 2
        const gx = (g & Qt.LeftEdge) ? ax - w.width : (g & Qt.RightEdge) ? ax : ax - w.width / 2
        const gy = (g & Qt.TopEdge) ? ay - w.height : (g & Qt.BottomEdge) ? ay : ay - w.height / 2
        const x = Math.max(0, Math.min(base.x + gx, s.width - w.width))
        const y = Math.max(0, Math.min(base.y + gy, s.height - w.height))
        return Qt.point(x, y)
    }

    readonly property point winPos: {
        if (!live || !win || !scr) return Qt.point(0, 0)
        if (fullscreenSurface) return Qt.point(0, 0)
        if (floating) return Qt.point(floatX, floatY)
        if (popup) return popupOffset(win, scr)
        return panelOffset(win, scr)
    }
    readonly property real winX: winPos.x
    readonly property real winY: winPos.y

    property point origin: Qt.point(0, 0)

    function refresh() {
        const p = mapToItem(null, 0, 0)
        if (p.x !== origin.x || p.y !== origin.y) origin = p
    }

    function kick() {
        if (!tracking) return
        refresh()
        if (win && !floating && !fullscreenSurface) GlassLayers.refresh()
        settleTimer.restart()
        ticker.running = true
    }

    readonly property var ancestorGeometry: {
        if (!tracking) return []
        const sig = []
        for (let it = parent; it; it = it.parent) sig.push(it.x, it.y, it.width, it.height, it.scale)
        return sig
    }

    onAncestorGeometryChanged: kick()
    onTrackingChanged: kick()
    onParentChanged: kick()
    onXChanged: kick()
    onYChanged: kick()
    onWidthChanged: kick()
    onHeightChanged: kick()
    onVisibleChanged: kick()
    Component.onCompleted: {
        syncClaim()
        kick()
    }

    Connections {
        target: root.win
        enabled: root.live
        function onWidthChanged() { root.kick() }
        function onHeightChanged() { root.kick() }
        function onVisibleChanged() { root.kick() }
    }

    Timer {
        id: ticker
        interval: 16
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: settleTimer
        interval: 1000
        onTriggered: ticker.running = false
    }

    readonly property string wallpaper: {
        const lockWall = Config.options.background.lockWall ?? ""
        const path = GlobalStates.screenLocked && lockWall !== "" ? lockWall : Config.options.background.wallpaperPath
        return /\.(mp4|webm|mkv|avi|mov)$/.test(path) ? Config.options.background.thumbnailPath : path
    }

    Loader {
        anchors.fill: parent
        active: root.live && !!root.scr && root.wallpaper !== ""

        sourceComponent: Item {
            Image {
                id: wallpaperImage
                visible: false
                width: root.scr.width
                height: root.scr.height
                x: -(root.winX + root.origin.x)
                y: -(root.winY + root.origin.y)
                source: "file://" + root.wallpaper
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.ceil(root.scr.width * root.scr.devicePixelRatio), Math.ceil(root.scr.height * root.scr.devicePixelRatio))
                asynchronous: true
                cache: true
            }

            FrostedGlass {
                anchors.fill: parent
                blurSource: wallpaperImage
                cardRadius: root.cardRadius
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomRightRadius: root.bottomRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                tint: root.tint
                tintOpacity: root.tintStrength
                flareLeft: root.flareLeft
                flareRight: root.flareRight
                hangLeft: root.hangLeft
                hangRight: root.hangRight
                edge: root.edge
                trackX: wallpaperImage.x
                trackY: wallpaperImage.y
            }
        }
    }
}
