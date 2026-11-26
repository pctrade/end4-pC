pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root
    required property MprisPlayer player
    required property QtObject blendedColors
    required property string displayedArtFilePath
    required property color artDominantColor
    property bool lyricsMode: false
    property bool lyricsAllowed: true
    signal toggleLyrics()

    readonly property real pad: 13
    readonly property real gap: 15
    property real t: root.lyricsMode ? 1 : 0

    readonly property real artSize: lerp(114, 150)
    readonly property real textX: lerp(pad + 114 + gap, pad)
    readonly property real textWidth: Math.max(0, width - textX - pad)
    readonly property real bottomPad: lerp(13, 12)
    readonly property real rowSpacing: 5
    readonly property real rowHeight: Math.max(24, progressBarContainer.implicitHeight)
    readonly property real rowY: root.height - root.bottomPad - root.rowHeight
    readonly property real lyricsTitleY: root.height - 12 - root.rowHeight - trackTime.implicitHeight - 2 - (trackArtist.implicitHeight - 2) - trackTitle.implicitHeight

    Behavior on t {
        enabled: root.lyricsAllowed
        SpringAnimation {
            spring: 3.2
            damping: 0.3
            epsilon: 0.002
        }
    }

    function lerp(a, b) {
        return a + (b - a) * root.t
    }

    function restartLyrics() {
        if (lyricsLoader.item) lyricsLoader.item.restartLyrics()
    }

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

    Rectangle {
        id: artBackground
        x: root.pad
        y: root.pad
        width: root.artSize
        height: root.artSize
        radius: root.lerp(Appearance.rounding.verysmall, 16)
        color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.5)

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: artBackground.width
                height: artBackground.height
                radius: artBackground.radius + 6 * (1 - root.t)
            }
        }

        StyledImage {
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            sourceSize.width: 150
            sourceSize.height: 150
        }

        HoverHandler {
            id: artHover
            enabled: root.t < 0.5
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: artHover.hovered && root.t < 0.5 ? 0.6 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animationCurves.expressiveFastSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standard
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: Appearance.font.pixelSize.normal
            color: root.blendedColors.colOnLayer0
            text: (root.player?.volume ?? 0) === 0 ? "volume_off" : ((root.player?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up")
            opacity: artHover.hovered && root.t < 0.5 ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animationCurves.expressiveFastSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standard
                }
            }
        }

        MaterialDial {
            anchors.fill: parent
            anchors.margins: 14
            enabled: root.t < 0.5
            colPrimary: root.blendedColors.colPrimary
            colSecondary: root.blendedColors.colSecondaryContainer
            value: root.player?.volume ?? 0
            waveAmplitude: 3.2 * (root.player?.volume ?? 0)
            opacity: artHover.hovered && root.t < 0.5 ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animationCurves.expressiveFastSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standard
                }
            }

            onMoved: {
                if (root.player)
                    root.player.volume = value;
            }
        }
    }

    Loader {
        id: lyricsLoader
        active: root.lyricsAllowed
        x: root.pad + root.artSize + root.gap
        y: root.pad
        width: Math.max(0, root.width - x - root.pad)
        height: 150
        opacity: Math.max(0, Math.min(1, (root.t - 0.35) / 0.65))
        visible: opacity > 0.01

        sourceComponent: Lyrics {
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

    StyledText {
        id: trackTitle
        x: root.textX
        y: root.lerp(root.pad, root.lyricsTitleY)
        width: root.textWidth
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
        x: root.textX
        y: trackTitle.y + trackTitle.implicitHeight + root.lerp(2, -2)
        width: root.textWidth
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: root.blendedColors.colSubtext
        elide: Text.ElideRight
        text: root.player?.trackArtist
        animateChange: true
        animationDistanceX: 6
        animationDistanceY: 0
    }

    StyledText {
        id: trackTime
        x: root.textX
        y: root.rowY - height - root.lerp(5, 0)
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.blendedColors.colSubtext
        elide: Text.ElideRight
        font.features: { "tnum": 1 }
        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
    }

    TrackChangeButton {
        id: prevButton
        x: root.textX
        y: root.rowY + (root.rowHeight - height) / 2
        iconName: "skip_previous"
        downAction: () => root.player?.previous()
    }

    Item {
        id: progressBarContainer
        x: prevButton.x + prevButton.width + root.rowSpacing
        y: root.rowY
        width: Math.max(0, rightButtons.x - root.rowSpacing - x)
        implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)
        height: root.rowHeight

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
                    root.restartLyrics()
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

    Row {
        id: rightButtons
        x: root.width - root.pad - width
        y: root.rowY + (root.rowHeight - height) / 2
        spacing: root.rowSpacing

        TrackChangeButton {
            iconName: "skip_next"
            downAction: () => root.player?.next()
        }

        TrackChangeButton {
            iconName: "lyrics"
            visible: root.lyricsAllowed && (root.lyricsMode || !GlobalStates.sidebarRightOpen)
            downAction: () => root.toggleLyrics()
        }

        TrackChangeButton {
            iconName: "equalizer"
            downAction: () => GlobalStates.equalizerOpen = !GlobalStates.equalizerOpen
        }
    }

    RippleButton {
        id: playPauseButton
        x: root.width - root.pad - width
        y: root.rowY - height - 5
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
