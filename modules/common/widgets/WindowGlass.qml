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
    property real tintStrength: 0.3
    // Glass on the wallpaper layer (desktop widgets) has only the wallpaper
    // behind it, so it keeps the wallpaper lens even in live-blur mode.
    property bool liveBlurAllowed: true
    readonly property bool live: glassEnabled && (Config.options?.background?.widgets?.glass?.enable ?? false)
    // Live blur: Hyprland blurs the real windows behind the layer and only
    // the rim, sheen and tint are drawn here (shaders/frostedRim.frag).
    readonly property bool liveBlur: live && liveBlurAllowed && (Config.options?.background?.widgets?.glass?.liveBlur ?? false)
    readonly property real liveTint: Config.options?.background?.widgets?.glass?.liveTint ?? 0.55
    readonly property bool tracking: live && !liveBlur && (win?.visible ?? true)

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

    property real floatX: 0
    property real floatY: 0

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
        let best = null
        let bestDist = Infinity
        for (const level of Object.values(mon.levels ?? {})) {
            for (const layer of level) {
                if (!layer.namespace.startsWith("quickshell:")) continue
                if (layer.w !== Math.round(w.width) || layer.h !== Math.round(w.height)) continue
                const dist = Math.abs(layer.x - guess.x) + Math.abs(layer.y - guess.y)
                if (dist < bestDist) {
                    bestDist = dist
                    best = layer
                }
            }
        }
        return best ? Qt.point(best.x, best.y) : guess
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

    Process {
        id: tracker
        running: root.live && !root.liveBlur && root.floating && !!root.win?.visible
        command: ["bash", "-c", "while :; do hyprctl -j activewindow | tr -d '\\n'; echo; sleep 0.016; done"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const client = JSON.parse(line)
                    if (client.title !== root.win.title || !root.scr) return
                    const mon = HyprlandData.monitors.find(m => m.name === root.scr.name)
                    root.floatX = client.at[0] - (mon?.x ?? 0)
                    root.floatY = client.at[1] - (mon?.y ?? 0)
                } catch (e) {}
            }
        }
    }

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
    Component.onCompleted: kick()

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
        active: root.liveBlur

        sourceComponent: ShaderEffect {
            property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
            property color wash: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.liveTint)
            property vector2d size: Qt.vector2d(width, height)
            property real rimWidth: 4
            property real sheen: 0.31

            fragmentShader: Qt.resolvedUrl("shaders/frostedRim.frag.qsb")
        }
    }

    Loader {
        anchors.fill: parent
        active: root.live && !root.liveBlur && !!root.scr && root.wallpaper !== ""

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
                trackX: wallpaperImage.x
                trackY: wallpaperImage.y
            }
        }
    }
}
