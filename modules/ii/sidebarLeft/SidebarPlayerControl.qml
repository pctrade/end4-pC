pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    property var player: Mpris.players.values[playerSelector.currentIndex] ?? Mpris.players.values[0]
    property var artUrl: player?.trackArtUrl ?? ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.8
    ) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real radius
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""

    property QtObject blendedColors: AdaptedMaterialScheme { color: artDominantColor }

    readonly property real btnSmall: Math.max(42, height * 0.06)
    readonly property real btnVol: Math.max(36, height * 0.05)

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return
        }
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: root.downloaded = true
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    component ControlButton: RippleButton {
        property real baseSize: root.btnSmall
        implicitWidth: baseSize * 1.5
        implicitHeight: baseSize * 1.5
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 0.7)
        colBackgroundHover: root.blendedColors.colSecondaryContainerHover
        colRipple: root.blendedColors.colSecondaryContainerActive
    }

    component VolumeButton: RippleButton {
        property real baseSize: root.btnVol
        implicitWidth: baseSize
        implicitHeight: baseSize
        buttonRadius: Appearance.rounding.large
        colBackground: ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 0.7)
        colBackgroundHover: root.blendedColors.colSecondaryContainerHover
        colRipple: root.blendedColors.colSecondaryContainerActive
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: -1
        anchors.bottomMargin: 4
        color: Appearance.colors.colLayer2
        radius: Appearance.rounding.normal

        WaveVisualizer {
            anchors.fill: parent
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: root.blendedColors.colPrimary
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.height * 0.04
            spacing: 0

            // ── Player selector ──
            StyledComboBox {
                id: playerSelector
                visible: Mpris.players.values.length > 1
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                model: Mpris.players.values.map(p => p.identity ?? p.desktopEntry ?? "Unknown")
                currentIndex: 0
            }

            // ── Album art ──
            Rectangle {
                id: artBackground
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(parent.width, parent.height * 0.45)
                Layout.preferredHeight: Layout.preferredWidth
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                StyledImage {
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width: artBackground.width
                    sourceSize.height: artBackground.height
                }
            }

            // ── Title & Artist ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: parent.height * 0.025
                Layout.bottomMargin: parent.height * 0.02
                spacing: parent.height * 0.005

                Repeater {
                    model: [
                        { txt: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled", big: true },
                        { txt: root.player?.trackArtist || "Unknown Artist",                        big: false }
                    ]
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: lbl.implicitHeight
                        Layout.minimumHeight: (modelData.big
                            ? Math.max(16, parent.parent.height * 0.024)
                            : Math.max(13, parent.parent.height * 0.018)) * 1.5
                        clip: true

                        StyledText {
                            id: lbl
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            font.pixelSize: modelData.big
                                ? Math.max(16, parent.parent.height * 0.024)
                                : Math.max(13, parent.parent.height * 0.018)
                            font.weight: modelData.big ? Font.Bold : Font.Normal
                            color: modelData.big ? root.blendedColors.colOnLayer0 : root.blendedColors.colSubtext
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: modelData.txt

                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: lbl; property: "x"; to: -lbl.width;  duration: 150; easing.type: Easing.InQuad }
                                    PropertyAction  { target: lbl; property: "text" }
                                    NumberAnimation { target: lbl; property: "x"; from: lbl.width; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }
            }

            // ── Lyrics ──
            Lyrics {
                player: root.player
                Layout.fillWidth: true
                Layout.fillHeight: true
                textAlignment: Text.AlignHCenter
                textColor: root.blendedColors.colOnLayer0
                activeColor: root.blendedColors.colPrimary
                dimColor: root.blendedColors.colSubtext
                indicatorColor: {
                    const c = root.blendedColors.colPrimaryContainer
                    return (c && c != "#000000" && c != "transparent") ? c : root.artDominantColor
                }
                indicatorShapeColor: {
                    const c = root.blendedColors.colOnPrimaryContainer
                    if (c && c != "#000000" && c != "#ffffff" && c != "transparent") return c
                    return root.blendedColors.colPrimary || Appearance.colors.colPrimary
                }
            }

            // ── Progress ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: parent.height * 0.01
                spacing: 12

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.blendedColors.colSubtext
                    font.letterSpacing: -0.4
                    font.features: { "tnum": 1 }
                    text: StringUtils.friendlyTimeForSeconds(root.player?.position)
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                    Loader {
                        id: sliderLoader
                        anchors.fill: parent
                        active: root.player?.canSeek ?? false
                        sourceComponent: StyledSlider {
                            configuration: StyledSlider.Configuration.Wavy
                            highlightColor: root.blendedColors.colPrimary
                            trackColor: root.blendedColors.colSecondaryContainer
                            handleColor: root.blendedColors.colPrimary
                            value: (root.player?.position ?? 0) / (root.player?.length ?? 1)
                            onMoved: root.player.position = value * root.player.length
                        }
                    }

                    Loader {
                        id: progressBarLoader
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
                        active: !(root.player?.canSeek ?? false)
                        sourceComponent: StyledProgressBar {
                            wavy: root.player?.isPlaying
                            highlightColor: root.blendedColors.colPrimary
                            trackColor: root.blendedColors.colSecondaryContainer
                            value: (root.player?.position ?? 0) / (root.player?.length ?? 1)
                        }
                    }
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.blendedColors.colSubtext
                    font.letterSpacing: -0.4
                    font.features: { "tnum": 1 }
                    text: StringUtils.friendlyTimeForSeconds(root.player?.length)
                }
            }

            // ── Controls ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: parent.height * 0.02
                Layout.preferredHeight: parent.height * 0.11
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                ControlButton {
                    downAction: () => root.player?.previous()
                    contentItem: MaterialSymbol {
                        iconSize: 25; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "skip_previous"
                    }
                }

                RippleButton {
                    property real baseSize: Math.max(70, parent.parent.height * 0.1)
                    Layout.fillWidth: true
                    implicitHeight: baseSize
                    buttonRadius: root.player?.isPlaying ? Appearance.rounding.verylarge : baseSize / 2
                    colBackground: root.player?.isPlaying ? root.blendedColors.colPrimary : root.blendedColors.colSecondaryContainer
                    colBackgroundHover: root.player?.isPlaying ? root.blendedColors.colPrimaryHover : root.blendedColors.colSecondaryContainerHover
                    colRipple: root.player?.isPlaying ? root.blendedColors.colPrimaryActive : root.blendedColors.colSecondaryContainerActive
                    downAction: () => root.player.togglePlaying()
                    contentItem: MaterialSymbol {
                        iconSize: 50; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.player?.isPlaying ? root.blendedColors.colOnPrimary : root.blendedColors.colOnSecondaryContainer
                        text: root.player?.isPlaying ? "pause" : "play_arrow"
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }

                ControlButton { // remember to take this out as global widgets, pC please
                    downAction: () => root.player?.next()
                    contentItem: MaterialSymbol {
                        iconSize: 25; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "skip_next"
                    }
                }
            }

            // ── Volume ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                VolumeButton { // remember to take this out as global widgets, pC please
                    downAction: () => root.player.volume = root.player.volume > 0 ? 0 : 1.0
                    contentItem: MaterialSymbol {
                        iconSize: 18; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: (root.player?.volume ?? 1) <= 0 ? "volume_off"
                            : (root.player?.volume ?? 1) < 0.5 ? "volume_down"
                            : "volume_up"
                    }
                }

                VolumeButton {
                    Layout.fillWidth: true
                    downAction: () => root.player.volume = Math.max(0, (root.player?.volume ?? 1) - 0.1)
                    contentItem: MaterialSymbol {
                        iconSize: 18; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "volume_down"
                    }
                }

                VolumeButton {
                    Layout.fillWidth: true
                    downAction: () => root.player.volume = Math.min(1.5, (root.player?.volume ?? 1) + 0.1)
                    contentItem: MaterialSymbol {
                        iconSize: 18; fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.blendedColors.colOnSecondaryContainer
                        text: "volume_up"
                    }
                }
            }
        }
    }
}