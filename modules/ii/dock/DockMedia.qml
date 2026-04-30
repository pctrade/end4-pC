pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.common.models
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    property real cardWidth:     240
    property real buttonPadding: 5
    property real artMargin:     5

    property var player: MprisController.activePlayer

    property var    artUrl:      player?.trackArtUrl ?? ""
    property string trackTitle:  player?.trackTitle  ?? ""
    property string trackArtist: player?.trackArtist ?? ""
    property bool   isPlaying:   player?.isPlaying   ?? false
    property bool   hasTrack:    trackTitle.length > 0

    property string artDownloadLocation: Directories.coverArt
    property string artFileName:         Qt.md5(artUrl)
    property string artFilePath:         `${artDownloadLocation}/${artFileName}`
    property bool   artDownloaded:       false
    property string displayedArtFilePath: artDownloaded ? Qt.resolvedUrl(artFilePath) : ""

    property color artDominantColor: ColorUtils.mix(
            colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
            Appearance.colors.colPrimaryContainer,
            0.8)

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            root.artDownloaded = false
            return
        }
        artDownloader.targetFile  = root.artUrl
        artDownloader.artFilePath = root.artFilePath
        root.artDownloaded = false
        artDownloader.running = true
    }

    Process {
        id: artDownloader
        property string targetFile:  root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c",
            `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: { root.artDownloaded = true }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    visible:        root.hasTrack
    implicitWidth:  root.hasTrack ? root.cardWidth : 0
    implicitHeight: parent?.height ?? 46

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.topMargin:    Appearance.sizes.hyprlandGapsOut
        anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
        anchors.leftMargin:   Appearance.sizes.hyprlandGapsOut
        anchors.rightMargin:  Appearance.sizes.hyprlandGapsOut
        radius: Appearance.rounding.normal
        color:  "transparent"

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width:  card.width
                height: card.height
                radius: card.radius
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 1)
            z: 0
        }

        // Blur art
        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true
            z: 1
            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }
        }

        // Overlay 
        Rectangle {
            anchors.fill: parent
            color: ColorUtils.transparentize(root.blendedColors.colLayer0, 0.3)
            z: 2
        }

        RowLayout {
            anchors.fill: parent
            clip: true
            spacing: 8
            z: 3

            // Art
            Rectangle {
                id: artRect
                Layout.alignment:  Qt.AlignVCenter
                Layout.leftMargin: root.artMargin + 2
                implicitWidth:     36
                implicitHeight:    36
                color:  ColorUtils.transparentize(root.blendedColors.colLayer1, 0.5)
                radius: Appearance.rounding.small

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width:  artRect.width
                        height: artRect.height
                        radius: artRect.radius
                    }
                }

                StyledImage {
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width:  artRect.width
                    sourceSize.height: artRect.height
                }
            }

            ColumnLayout {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                spacing: -2

                Item { Layout.fillHeight: true }

                StyledText {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    font.pixelSize: Appearance.font.pixelSize.small - 2
                    color: root.blendedColors.colSubtext
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.trackTitle) || "Untitled"
                    font.pixelSize: Appearance.font.pixelSize.normal -4
                    color: root.blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    opacity: 0.7
                }

                Item { Layout.fillHeight: true }
            }

            RowLayout {
                Layout.rightMargin: 4
                Layout.alignment:   Qt.AlignVCenter
                spacing: 3

                RippleButton {
                    implicitWidth:  26
                    implicitHeight: 26
                    buttonRadius: root.isPlaying
                        ? Appearance.rounding.normal
                        : implicitWidth / 2
                    colBackground: root.isPlaying
                        ? root.blendedColors.colPrimary
                        : root.blendedColors.colSecondaryContainer
                    colBackgroundHover: root.isPlaying
                        ? root.blendedColors.colPrimaryHover
                        : root.blendedColors.colSecondaryContainerHover
                    colRipple: root.isPlaying
                        ? root.blendedColors.colPrimaryActive
                        : root.blendedColors.colSecondaryContainerActive
                    downAction: () => root.player?.togglePlaying()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: root.isPlaying ? "pause" : "play_arrow"
                        iconSize: Appearance.font.pixelSize.large
                        fill: 1
                        color: root.isPlaying
                            ? root.blendedColors.colOnPrimary
                            : root.blendedColors.colOnSecondaryContainer
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                }

                RippleButton {
                    implicitWidth:  28
                    implicitHeight: 28
                    colBackground:      ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 1)
                    colBackgroundHover: root.blendedColors.colSecondaryContainerHover
                    colRipple:          root.blendedColors.colSecondaryContainerActive
                    downAction: () => root.player?.next()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "skip_next"
                        iconSize: Appearance.font.pixelSize.large
                        fill: 1
                        color: root.blendedColors.colOnSecondaryContainer
                    }
                }
            }
        }
    }
}
