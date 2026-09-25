import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: xm
    required property Item di
    implicitWidth: 400
    implicitHeight: column.implicitHeight

    readonly property MprisPlayer player: xm.di.activePlayer
    readonly property real length: xm.player?.length ?? 0
    readonly property real position: xm.player?.position ?? 0
    readonly property real progress: xm.length > 0 ? Math.min(1, xm.position / xm.length) : 0
    readonly property color accent: xm.di.mediaArtColor
    readonly property var hero: (xm.player?.trackArtUrl ?? "") !== "" ? { key: "media-art", item: bigArt } : null
    readonly property bool showLyrics: (xm.di.cfg.lyrics ?? true) && LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -14
        visible: xm.di.cfg.albumColors ?? true
        gradient: Gradient {
            GradientStop { position: 0; color: ColorUtils.transparentize(xm.accent, 0.72) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                id: bigArt
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                radius: 16
                color: Appearance.colors.colLayer2
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: bigArt.width
                        height: bigArt.height
                        radius: bigArt.radius
                    }
                }

                StyledImage {
                    id: artImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: xm.player?.trackArtUrl ?? ""
                    sourceSize.width: 176
                    sourceSize.height: 176

                    // The cover can be pulled out of the island: dropping it somewhere shares the image file
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

                Connections {
                    target: xm.player
                    function onTrackTitleChanged() {}
                }

                SequentialAnimation {
                    id: artSwap
                    NumberAnimation { target: bigArt; property: "scale"; to: 0.85; duration: IslandMotion.micro; easing.type: Easing.InQuad }
                    NumberAnimation { target: bigArt; property: "scale"; to: 1; duration: IslandMotion.long; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: xm.player?.trackTitle || Translation.tr("Unknown Title")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: xm.player?.trackArtist ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.8
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: xm.player?.trackAlbum ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.55
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.topMargin: 4
                    spacing: 10

                    Repeater {
                        model: [
                            { icon: "skip_previous", big: false, enabled: xm.player?.canGoPrevious ?? false, action: () => xm.player?.previous() },
                            { icon: xm.player?.isPlaying ? "pause" : "play_arrow", big: true, enabled: xm.player?.canTogglePlaying ?? false, action: () => xm.player?.togglePlaying() },
                            { icon: "skip_next", big: false, enabled: xm.player?.canGoNext ?? false, action: () => xm.player?.next() }
                        ]
                        delegate: Rectangle {
                            id: control
                            required property var modelData
                            implicitWidth: control.modelData.big ? 40 : 32
                            implicitHeight: implicitWidth
                            radius: control.modelData.big && !(xm.player?.isPlaying ?? false) ? 12 : implicitWidth / 2
                            color: control.modelData.big ? xm.accent : (controlMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent")
                            opacity: control.modelData.enabled ? 1 : 0.35
                            scale: controlMouse.pressed ? 0.88 : 1

                            Behavior on radius {
                                NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: control.modelData.icon
                                iconSize: control.modelData.big ? 24 : 22
                                fill: 1
                                color: control.modelData.big ? (ColorUtils.isDark(xm.accent) ? "white" : "black") : Appearance.colors.colOnLayer0
                            }

                            MouseArea {
                                id: controlMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: control.modelData.enabled
                                onClicked: control.modelData.action()
                            }
                        }
                    }

                    // Spotify: like the song (its Alt+Shift+B shortcut, sent to the Spotify window)
                    Rectangle {
                        id: likeButton
                        property bool justLiked: false
                        visible: /spotify/i.test(`${xm.player?.identity ?? ""} ${xm.player?.desktopEntry ?? ""}`)
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        color: likeMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"
                        scale: likeMouse.pressed ? 0.85 : 1

                        Behavior on scale {
                            NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "favorite"
                            iconSize: 20
                            fill: likeButton.justLiked ? 1 : 0
                            color: likeButton.justLiked ? "#1DB954" : Appearance.colors.colOnLayer0
                            scale: likeButton.justLiked ? 1.15 : 1

                            Behavior on scale {
                                NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 3 }
                            }
                        }

                        Timer {
                            id: likeReset
                            interval: 2500
                            onTriggered: likeButton.justLiked = false
                        }

                        MouseArea {
                            id: likeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                IslandEvents.likeSpotifyTrack()
                                likeButton.justLiked = true
                                likeReset.restart()
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: xm.length > 0

            Item {
                id: seekBar
                Layout.fillWidth: true
                Layout.preferredHeight: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekMouse.containsMouse ? 6 : 4
                    radius: height / 2
                    color: ColorUtils.transparentize(xm.accent, 0.75)

                    Behavior on height {
                        NumberAnimation { duration: IslandMotion.micro }
                    }

                    Rectangle {
                        width: parent.width * (seekMouse.pressed ? seekMouse.dragValue : xm.progress)
                        height: parent.height
                        radius: parent.radius
                        color: xm.accent
                    }
                }

                MouseArea {
                    id: seekMouse
                    property real dragValue: 0
                    anchors.fill: parent
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
                    text: xm.formatTime(xm.position)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: `-${xm.formatTime(xm.length - xm.position)}`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
            }
        }

        // Synced lyrics: the whole song scrolls smoothly with the current line centered; tap a line to jump there
        Item {
            id: lyricsView
            Layout.fillWidth: true
            Layout.preferredHeight: 136
            visible: xm.showLyrics
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: lyricsView.width
                    height: lyricsView.height
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.25; color: "white" }
                        GradientStop { position: 0.75; color: "white" }
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
                spacing: 6
                preferredHighlightBegin: height / 2 - 14
                preferredHighlightEnd: height / 2 + 14
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 560
                highlightMoveVelocity: -1

                delegate: StyledText {
                    id: lyricLine
                    required property var modelData
                    required property int index
                    readonly property int distance: Math.abs(lyricLine.index - LyricsService.activeIndex)
                    width: lyricsList.width
                    horizontalAlignment: Text.AlignHCenter
                    text: lyricLine.modelData.text || "♪"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: lyricLine.distance === 0 ? Font.DemiBold : Font.Normal
                    color: lyricLine.distance === 0 ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnLayer0
                    opacity: lyricLine.distance === 0 ? 1 : lyricLine.distance === 1 ? 0.5 : 0.25
                    scale: lyricLine.distance === 0 ? 1.06 : 0.94
                    wrapMode: Text.Wrap
                    maximumLineCount: 2

                    Behavior on opacity {
                        NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: xm.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xm.player.position = lyricLine.modelData.time
                    }
                }
            }
        }

        // No synced lyrics: say so instead of leaving a gap
        StyledText {
            Layout.fillWidth: true
            visible: (xm.di.cfg.lyrics ?? true) && !xm.showLyrics && xm.player !== null && (xm.player?.trackTitle ?? "") !== ""
            horizontalAlignment: Text.AlignHCenter
            text: LyricsService.status === "loading" ? Translation.tr("Looking for lyrics…") : Translation.tr("No synced lyrics for this song")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.5
        }
    }
}
