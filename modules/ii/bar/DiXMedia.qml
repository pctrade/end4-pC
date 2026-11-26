import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Now playing: tonal palette from the album art, wavy progress, lyrics card on the right.
Item {
    id: xm
    required property Item di
    implicitWidth: xm.wantedWidth
    readonly property bool lyricsOn: (xm.di.cfg.lyrics ?? true) && (xm.di.cfg.lyricsCard ?? true)
    readonly property real wantedWidth: xm.lyricsOn ? 532 : 372
    implicitHeight: layout.implicitHeight

    readonly property MprisPlayer player: xm.di.activePlayer
    readonly property real length: xm.player?.length ?? 0
    readonly property real position: xm.player?.position ?? 0
    readonly property real progress: xm.length > 0 ? Math.min(1, xm.position / xm.length) : 0
    readonly property bool playing: xm.player?.isPlaying ?? false
    readonly property bool showLyrics: (xm.di.cfg.lyrics ?? true) && LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    readonly property var hero: (xm.player?.trackArtUrl ?? "") !== "" ? { key: "media-art", item: bigArt } : null

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property color seed: xm.di.mediaArtColor
    function tone(lightness, alpha) {
        const c = Qt.color(xm.seed)
        const sat = Math.max(0.28, Math.min(0.72, c.hslSaturation))
        return Qt.hsla(c.hslHue, sat, lightness, alpha ?? 1)
    }
    readonly property color primary: xm.tone(xm.dark ? 0.80 : 0.36)
    readonly property color onPrimary: xm.tone(xm.dark ? 0.15 : 0.97)
    readonly property color container: xm.tone(xm.dark ? 0.26 : 0.86, 0.72)
    readonly property color onSurface: xm.tone(xm.dark ? 0.95 : 0.12)
    readonly property color onSurfaceVariant: xm.tone(xm.dark ? 0.78 : 0.32)

    readonly property bool albumColors: (xm.di.cfg.albumColors ?? true) && (xm.di.cfg.albumTint ?? true)
    readonly property color tint: xm.albumColors ? xm.tone(xm.dark ? 0.12 : 0.93, 0.72) : "transparent"
    readonly property string backdrop: xm.albumColors ? (xm.player?.trackArtUrl ?? "") : ""

    Component.onCompleted: {
        xm.player?.positionChanged()
        Qt.callLater(LyricsService.syncNow)
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`
    }

    component TonalButton: Rectangle {
        id: tb
        property string icon
        property bool enabledState: true
        property bool filled: false
        property color iconColor: xm.onSurface
        signal clicked()
        implicitWidth: 40
        implicitHeight: 40
        radius: tbMouse.pressed ? 12 : 20
        color: tbMouse.containsMouse ? xm.tone(xm.dark ? 0.32 : 0.80, 0.85) : xm.container
        opacity: tb.enabledState ? 1 : 0.4

        Behavior on radius { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: IslandMotion.micro } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: tb.icon
            iconSize: 22
            fill: tb.filled ? 1 : 0
            color: tb.iconColor
            Behavior on color { ColorAnimation { duration: IslandMotion.short } }
        }
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: tb.enabledState
            onClicked: tb.clicked()
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 14

        ColumnLayout {
            id: leftCol
            Layout.fillWidth: !xm.lyricsOn
            Layout.preferredWidth: xm.lyricsOn ? 262 : 372
            Layout.maximumWidth: xm.lyricsOn ? 262 : 100000
            Layout.alignment: Qt.AlignTop
            spacing: 10

            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: 12
                DiCascade { target: header; index: 0 }

                Rectangle {
                    id: bigArt
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 92
                    radius: 24
                    color: xm.container
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: bigArt.width
                            height: bigArt.height
                            radius: bigArt.radius
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: "music_note"
                        iconSize: 34
                        fill: 1
                        color: xm.onSurfaceVariant
                    }

                    StyledImage {
                        id: artImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: xm.player?.trackArtUrl ?? ""
                        sourceSize.width: 184
                        sourceSize.height: 184

                        Drag.active: artDrag.drag.active
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: ({ "text/uri-list": xm.player?.trackArtUrl ?? "" })

                        Binding {
                            target: xm.di
                            property: "dragging"
                            value: true
                            when: artDrag.drag.active
                            restoreMode: Binding.RestoreValue
                        }
                    }

                    MouseArea {
                        id: artDrag
                        anchors.fill: parent
                        enabled: (xm.player?.trackArtUrl ?? "").startsWith("file://")
                        cursorShape: enabled ? Qt.OpenHandCursor : Qt.ArrowCursor
                        drag.target: artImage
                        onReleased: artImage.Drag.drop()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Rectangle {
                        implicitWidth: sourceRow.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: xm.container
                        visible: (xm.player?.identity ?? "") !== ""

                        RowLayout {
                            id: sourceRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: xm.playing ? "graphic_eq" : "pause_circle"
                                iconSize: 12
                                fill: 1
                                color: xm.primary
                            }
                            StyledText {
                                text: xm.player?.identity ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: xm.onSurfaceVariant
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        text: xm.player?.trackTitle || Translation.tr("Unknown Title")
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        color: xm.onSurface
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        lineHeight: 0.95
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: [xm.player?.trackArtist ?? "", xm.player?.trackAlbum ?? ""].filter(t => t !== "").join(" · ")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: xm.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                id: seekBlock
                Layout.fillWidth: true
                spacing: 0
                visible: xm.length > 0
                DiCascade { target: seekBlock; index: 1 }

                Item {
                    id: seekBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    readonly property real shown: seekMouse.pressed ? seekMouse.dragValue : xm.progress
                    property real phase: 0
                    property real amplitude: xm.playing && !seekMouse.pressed ? 3 : 0
                    Behavior on amplitude { NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic } }
                    onShownChanged: wave.requestPaint()
                    onAmplitudeChanged: wave.requestPaint()

                    // Only ticks while the wave is actually moving and the card is on screen
                    FrameAnimation {
                        running: seekBar.amplitude > 0.05 && xm.visible
                        onTriggered: {
                            seekBar.phase = (seekBar.phase + frameTime * 6) % (Math.PI * 2)
                            wave.requestPaint()
                        }
                    }

                    Canvas {
                        id: wave
                        anchors.fill: parent
                        readonly property color played: xm.primary
                        readonly property color rest: xm.tone(xm.dark ? 0.40 : 0.75, 0.6)
                        onPlayedChanged: requestPaint()
                        onRestChanged: requestPaint()
                        onWidthChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const mid = height / 2
                            const x = Math.max(0, Math.min(width, seekBar.shown * width))
                            const gap = 6
                            ctx.lineCap = "round"
                            ctx.lineWidth = 3.5

                            if (x + gap < width - 2) {
                                ctx.strokeStyle = rest
                                ctx.beginPath()
                                ctx.moveTo(x + gap, mid)
                                ctx.lineTo(width - 2, mid)
                                ctx.stroke()
                            }

                            if (x > 3) {
                                ctx.strokeStyle = played
                                ctx.beginPath()
                                const wavelength = 22
                                for (let px = 2; px <= x - gap / 2; px += 1.5) {
                                    const y = mid + Math.sin(px / wavelength * Math.PI * 2 - seekBar.phase) * seekBar.amplitude
                                    if (px === 2) ctx.moveTo(px, y)
                                    else ctx.lineTo(px, y)
                                }
                                ctx.stroke()
                            }

                            ctx.fillStyle = played
                            const tw = 4, th = 16
                            ctx.beginPath()
                            ctx.roundedRect(x - tw / 2, mid - th / 2, tw, th, 2, 2)
                            ctx.fill()
                        }
                    }

                    MouseArea {
                        id: seekMouse
                        property real dragValue: 0
                        anchors.fill: parent
                        anchors.topMargin: -4
                        anchors.bottomMargin: -4
                        hoverEnabled: true
                        enabled: xm.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => dragValue = Math.max(0, Math.min(1, mouse.x / width))
                        onPositionChanged: mouse => { if (pressed) dragValue = Math.max(0, Math.min(1, mouse.x / width)) }
                        onReleased: if (xm.player) xm.player.position = dragValue * xm.length
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: xm.formatTime(seekMouse.pressed ? seekMouse.dragValue * xm.length : xm.position)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: xm.onSurfaceVariant
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: `-${xm.formatTime(xm.length - xm.position)}`
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: xm.onSurfaceVariant
                    }
                }
            }

            RowLayout {
                id: controls
                Layout.fillWidth: true
                spacing: 8
                DiCascade { target: controls; index: 2 }

                Item {
                    visible: !xm.lyricsOn && likeButton.visible
                    implicitWidth: likeButton.implicitWidth
                }
                Item {
                    visible: !xm.lyricsOn
                    Layout.fillWidth: true
                }

                TonalButton {
                    icon: "skip_previous"
                    enabledState: xm.player?.canGoPrevious ?? false
                    onClicked: xm.player?.previous()
                }

                Rectangle {
                    id: playButton
                    implicitWidth: 64
                    implicitHeight: 44
                    radius: playMouse.pressed ? 10 : (xm.playing ? 14 : 22)
                    color: xm.primary
                    scale: playMouse.pressed ? 0.94 : 1
                    opacity: (xm.player?.canTogglePlaying ?? false) ? 1 : 0.4

                    Behavior on radius { NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    Behavior on scale { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: IslandMotion.long } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: xm.playing ? "pause" : "play_arrow"
                        iconSize: 26
                        fill: 1
                        color: xm.onPrimary
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: xm.player?.canTogglePlaying ?? false
                        onClicked: xm.player?.togglePlaying()
                    }
                }

                TonalButton {
                    icon: "skip_next"
                    enabledState: xm.player?.canGoNext ?? false
                    onClicked: xm.player?.next()
                }

                Item { Layout.fillWidth: true }

                TonalButton {
                    id: likeButton
                    property bool justLiked: false
                    visible: /spotify/i.test(`${xm.player?.identity ?? ""} ${xm.player?.desktopEntry ?? ""}`)
                    icon: "favorite"
                    filled: likeButton.justLiked
                    iconColor: likeButton.justLiked ? xm.primary : xm.onSurface
                    onClicked: {
                        IslandEvents.likeSpotifyTrack()
                        likeButton.justLiked = true
                        likeReset.restart()
                    }

                    Timer {
                        id: likeReset
                        interval: 2500
                        onTriggered: likeButton.justLiked = false
                    }
                }
            }
        }

        Rectangle {
            id: lyricsCard
            visible: xm.lyricsOn
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: xm.container
            DiCascade { target: lyricsCard; index: 3 }

            Item {
                id: lyricsView
                anchors.fill: parent
                anchors.margins: 10
                visible: xm.showLyrics
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: lyricsView.width
                        height: lyricsView.height
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.18; color: "white" }
                            GradientStop { position: 0.82; color: "white" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }

                ListView {
                    id: lyricsList
                    anchors.fill: parent
                    model: LyricsService.lyricsLines
                    currentIndex: Math.max(0, LyricsService.activeIndex)
                    interactive: false
                    spacing: 8
                    preferredHighlightBegin: height / 2 - 16
                    preferredHighlightEnd: height / 2 + 16
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 560
                    highlightMoveVelocity: -1

                    delegate: StyledText {
                        id: lyricLine
                        required property var modelData
                        required property int index
                        readonly property int distance: Math.abs(lyricLine.index - Math.max(0, LyricsService.activeIndex))
                        width: lyricsList.width
                        horizontalAlignment: Text.AlignHCenter
                        text: lyricLine.modelData.text || "♪"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: lyricLine.distance === 0 ? Font.DemiBold : Font.Normal
                        color: lyricLine.distance === 0 ? xm.onSurface : xm.onSurfaceVariant
                        opacity: lyricLine.distance === 0 ? 1 : lyricLine.distance === 1 ? 0.55 : 0.3
                        scale: lyricLine.distance === 0 ? 1.05 : 0.95
                        wrapMode: Text.Wrap
                        maximumLineCount: 2

                        Behavior on opacity { NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic } }

                        MouseArea {
                            anchors.fill: parent
                            enabled: xm.player?.canSeek ?? false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: xm.player.position = lyricLine.modelData.time
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 6
                visible: !xm.showLyrics

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    wrappedShape: MaterialShape.Shape.Cookie9Sided
                    color: xm.tone(xm.dark ? 0.34 : 0.78)
                    colSymbol: xm.primary
                    text: LyricsService.status === "loading" ? "manage_search" : "lyrics"
                    iconSize: 22
                    fill: 1
                    padding: 9

                    RotationAnimation on rotation {
                        running: LyricsService.status === "loading" && xm.visible
                        from: 0
                        to: 360
                        duration: 6000
                        loops: Animation.Infinite
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: !(xm.di.cfg.lyrics ?? true) ? Translation.tr("Lyrics are off")
                        : LyricsService.status === "loading" ? Translation.tr("Looking for lyrics…")
                        : Translation.tr("No synced lyrics for this song")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: xm.onSurfaceVariant
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
