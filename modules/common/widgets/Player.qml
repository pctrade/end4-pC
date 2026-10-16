pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl ?? ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary),
        Appearance.colors.colPrimaryContainer,
        0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: Boolean(root.artUrl && (root.artUrl.startsWith("data:") || root.artUrl.startsWith("file:/") || root.artUrl.startsWith("/")))
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real radius
    property bool allowLyrics: true
    property bool animateResize: false
    property string growFrom: "top"
    property bool showLyrics: allowLyrics && Config.options.bar.media.showLyrics

    readonly property real cardMargin: Appearance.sizes.elevationMargin
    property real designHeight: root.height
    property real cardHeight: root.designHeight - cardMargin * 2
    property bool resizeReady: false
    property real artReveal: 1

    Behavior on artReveal {
        SpringAnimation {
            spring: 3.4
            damping: 0.3
            epsilon: 0.002
        }
    }

    Timer {
        id: artRevealTimer
        interval: 520
        onTriggered: root.artReveal = 1
    }

    onDesignHeightChanged: {
        if (!root.animateResize || !root.resizeReady) return
        root.artReveal = 0
        artRevealTimer.restart()
    }
    property alias cardItem: background

    Behavior on cardHeight {
        enabled: root.animateResize && root.resizeReady
        NumberAnimation {
            duration: 460
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        running: true
        interval: 200
        onTriggered: root.resizeReady = true
    }

    property string displayedArtFilePath: {
        if (!root.artUrl || root.artUrl.length === 0) return ""
        if (root.artUrl.startsWith("data:")) return root.artUrl
        if (root.artUrl.startsWith("file:/")) return root.artUrl
        if (root.artUrl.startsWith("/")) return "file://" + root.artUrl
        if (!root.downloaded) return ""
        return Qt.resolvedUrl(artFilePath)
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            root.downloaded = false
            return
        }

        if (root.artUrl.startsWith("data:") || root.artUrl.startsWith("file:/") || root.artUrl.startsWith("/")) {
            root.downloaded = true
            return
        }

        if (root.artUrl.startsWith("http://") || root.artUrl.startsWith("https://")) {
            coverArtDownloader.targetFile = root.artUrl
            coverArtDownloader.artFilePath = root.artFilePath
            root.downloaded = false
            coverArtDownloader.running = true
        } else {
            root.downloaded = true
        }
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -4 -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    StyledRectangularShadow {
        target: background
    }

    Rectangle {
        id: background
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.cardMargin
            rightMargin: root.cardMargin
            top: root.growFrom === "top" ? parent.top : undefined
            topMargin: root.cardMargin
            bottom: root.growFrom === "bottom" ? parent.bottom : undefined
            bottomMargin: root.cardMargin
            verticalCenter: root.growFrom === "center" ? parent.verticalCenter : undefined
        }
        height: root.cardHeight
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: root.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: root.width - root.cardMargin * 2
            sourceSize.height: root.designHeight - root.cardMargin * 2
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true
            opacity: Math.max(0, Math.min(1, root.artReveal))
            scale: 0.88 + 0.12 * root.artReveal

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        PlayerContent {
            anchors.fill: parent
            player: root.player
            blendedColors: root.blendedColors
            displayedArtFilePath: root.displayedArtFilePath
            artDominantColor: root.artDominantColor
            lyricsMode: root.showLyrics
            lyricsAllowed: root.allowLyrics
            onToggleLyrics: {
                root.showLyrics = !root.showLyrics
                Config.options.bar.media.showLyrics = root.showLyrics
            }
        }
    }
}
