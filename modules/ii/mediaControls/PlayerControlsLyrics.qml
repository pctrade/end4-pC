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
    required property QtObject blendedColors
    required property string displayedArtFilePath
    required property real radius
    required property color artDominantColor
    signal toggleLyrics()

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24
        property var iconName
        colBackground: ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: root.blendedColors.colSecondaryContainerHover
        colRipple: root.blendedColors.colSecondaryContainerActive
        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: root.blendedColors.colOnSecondaryContainer
            text: iconName
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15

            Rectangle {
                id: artBackground
                implicitHeight: 150
                implicitWidth: 150
                radius: 16
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
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    width: size
                    height: size
                    sourceSize.width: size
                    sourceSize.height: size
                }
            }

            Lyrics {
                id: lyricsComp
                player: root.player
                Layout.fillWidth: true
                Layout.fillHeight: true
                textColor: root.blendedColors.colOnLayer0
                activeColor: root.blendedColors.colPrimary
                dimColor: root.blendedColors.colSubtext
                indicatorColor: {
                    let c = root.blendedColors.colPrimaryContainer
                    return (c && c != "#000000" && c != "transparent") ? c : root.artDominantColor
                }
                indicatorShapeColor: {
                    let c = root.blendedColors.colOnPrimaryContainer
                    if (c && c != "#000000" && c != "#ffffff" && c != "transparent") return c
                    return root.blendedColors.colPrimary || Appearance.colors.colPrimary
                }
            }
        }

        ColumnLayout {
            id: infoColumn
            Layout.fillWidth: true
            Layout.bottomMargin: 5

            StyledText {
                id: trackTitle
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.large
                color: root.blendedColors.colOnLayer0
                elide: Text.ElideRight
                text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
            }

            StyledText {
                id: trackArtist
                Layout.fillWidth: true
                Layout.topMargin: -6
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.blendedColors.colSubtext
                elide: Text.ElideRight
                text: root.player?.trackArtist
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                StyledText {
                    id: trackTime
                    anchors.bottom: sliderRow.top
                    anchors.bottomMargin: 0
                    anchors.left: parent.left
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.blendedColors.colSubtext
                    elide: Text.ElideRight
                    font.features: { "tnum": 1 }
                    text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                }

                RowLayout {
                    id: sliderRow
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }

                    TrackChangeButton {
                        iconName: "skip_previous"
                        downAction: () => root.player?.previous()
                    }

                    Item {
                        id: progressBarContainer
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
                                value: root.player?.position / root.player?.length
                                onMoved: {
                                    root.player.position = value * root.player.length
                                    lyricsComp.restartLyrics()
                                }
                            }
                        }

                        Loader {
                            id: progressBarLoader
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                right: parent.right
                            }
                            active: !(root.player?.canSeek ?? false)
                            sourceComponent: StyledProgressBar {
                                wavy: root.player?.isPlaying
                                highlightColor: root.blendedColors.colPrimary
                                trackColor: root.blendedColors.colSecondaryContainer
                                value: root.player?.position / root.player?.length
                            }
                        }
                    }

                    TrackChangeButton {
                        iconName: "skip_next"
                        downAction: () => root.player?.next()
                    }

                    TrackChangeButton {
                        iconName: "lyrics"
                        downAction: () => root.toggleLyrics()
                    }
                }

                RippleButton {
                    id: playPauseButton
                    anchors.right: parent.right
                    anchors.bottom: sliderRow.top
                    anchors.bottomMargin: 5
                    property real size: 44
                    implicitWidth: size
                    implicitHeight: size
                    downAction: () => root.player.togglePlaying()

                    buttonRadius: root.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                    colBackground: root.player?.isPlaying ? root.blendedColors.colPrimary : root.blendedColors.colSecondaryContainer
                    colBackgroundHover: root.player?.isPlaying ? root.blendedColors.colPrimaryHover : root.blendedColors.colSecondaryContainerHover
                    colRipple: root.player?.isPlaying ? root.blendedColors.colPrimaryActive : root.blendedColors.colSecondaryContainerActive

                    contentItem: MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.huge
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.player?.isPlaying ? root.blendedColors.colOnPrimary : root.blendedColors.colOnSecondaryContainer
                        text: root.player?.isPlaying ? "pause" : "play_arrow"
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                }
            }
        }
    }
}