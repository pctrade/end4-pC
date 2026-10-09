pragma ComponentBehavior: Bound

import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Quickshell.Io
import qs.services

Item {
    id: root

    readonly property bool connected: !!surfaceLoader.item?.surface?.hasContent
    readonly property bool running: scrcpy.running
    property string errorMessage: ""
    property string lastError: ""
    property var shellSurface: null
    property bool stopping: false
    property size videoSize: Qt.size(0, 0)
    property int displayRotation: 0
    readonly property real videoAspectRatio: videoSize.width > 0 && videoSize.height > 0
        ? (displayRotation % 180 === 90 ? videoSize.height / videoSize.width : videoSize.width / videoSize.height)
        : 0
    signal dismissed()

    function configureSurface() {
        if (!shellSurface?.toplevel || width <= 0 || height <= 0) return
        shellSurface.toplevel.sendConfigure(Qt.size(Math.round(width), Math.round(height)),
            [XdgToplevel.MaximizedState, XdgToplevel.ActivatedState])
    }

    function retry() {
        if (scrcpy.running || !compositor.created) return
        errorMessage = ""
        lastError = ""
        displayRotation = 0
        forceActiveFocus()
        scrcpy.running = true
        startupTimeout.restart()
    }

    function readOutput(line) {
        // Track the video dimensions, independent of the container's window size.
        const texture = line.match(/\bTexture:\s+(\d+)x(\d+)\b/)
        if (texture && Number(texture[1]) > 0 && Number(texture[2]) > 0) {
            videoSize = Qt.size(Number(texture[1]), Number(texture[2]))
        }
        const orientation = line.match(/(?:Initial display|Display) orientation set to (?:flip)?(0|90|180|270)\b/)
        if (orientation) displayRotation = Number(orientation[1])

        if (line.includes("unauthorized")) {
            lastError = Translation.tr("Unlock your phone and allow USB debugging, then retry.")
        } else if (line.includes("Could not find any ADB device") || line.includes("no devices")) {
            lastError = Translation.tr("Connect your phone and enable USB debugging, then retry.")
        } else if (line.includes("Multiple") && line.includes("device")) {
            lastError = Translation.tr("More than one phone is connected. Connect only the phone you want to mirror.")
        } else if (line.startsWith("ERROR:") && !lastError) {
            lastError = line.slice(6).trim()
        }
    }

    onWidthChanged: configureSurface()
    onHeightChanged: configureSurface()
    onConnectedChanged: {
        if (connected) startupTimeout.stop()
        else if (!stopping) forceActiveFocus()
    }
    Component.onCompleted: Qt.callLater(retry)
    Component.onDestruction: {
        stopping = true
        scrcpy.running = false
    }

    // A private Wayland display embeds scrcpy's real surface and forwards input.
    WaylandCompositor {
        id: compositor
        socketName: `end4-scrcpy-${Date.now()}-${Math.floor(Math.random() * 1000000)}`

        WaylandOutput {
            id: output
            window: root.Window.window
            sizeFollowsWindow: true
        }

        XdgShell {
            onToplevelCreated: (toplevel, xdgSurface) => {
                root.shellSurface = xdgSurface
                root.configureSurface()
                surfaceLoader.item?.takeFocus()
            }
        }
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        active: root.shellSurface !== null
        sourceComponent: WaylandQuickItem {
            surface: root.shellSurface?.surface ?? null
            output: output
            inputEventsEnabled: true
            focusOnClick: true
            onSurfaceDestroyed: root.shellSurface = null
            Keys.onEscapePressed: root.dismissed()
        }
    }

    Connections {
        target: root.shellSurface?.toplevel ?? null
        function onSetMaximized() { root.configureSurface() }
        function onUnsetMaximized() { root.configureSurface() }
        function onSetFullscreen() { root.configureSurface() }
        function onUnsetFullscreen() { root.configureSurface() }
    }

    Timer {
        id: startupTimeout
        interval: 15000
        onTriggered: {
            root.errorMessage = Translation.tr("Could not start scrcpy. Check that your phone is connected and USB debugging is allowed.")
            scrcpy.running = false
        }
    }

    Process {
        id: scrcpy
        // Flush dimension/orientation reports immediately, including during rotation.
        command: ["stdbuf", "-oL", "-eL", "scrcpy", "--verbosity=info", "--window-title=end4-scrcpy", "--window-borderless",
            `--window-width=${Math.round(root.width)}`, `--window-height=${Math.round(root.height)}`,
            "--no-window-aspect-ratio-lock", "--background-color=000000",
            "--max-size=1160", "--max-fps=60", "--render-driver=software", "--no-terminal-title"]
        environment: ({
            "WAYLAND_DISPLAY": compositor.socketName,
            "SDL_VIDEO_DRIVER": "wayland",
            "SDL_VIDEODRIVER": "wayland"
        })
        stdout: SplitParser { onRead: data => root.readOutput(data) }
        stderr: SplitParser { onRead: data => root.readOutput(data) }
        onExited: (exitCode, exitStatus) => {
            startupTimeout.stop()
            if (root.stopping) return
            if (exitCode === 0 && !root.errorMessage) {
                root.dismissed()
            } else if (!root.errorMessage) {
                root.errorMessage = root.lastError || Translation.tr("Phone disconnected. Check the connection and retry.")
            }
        }
    }
}
