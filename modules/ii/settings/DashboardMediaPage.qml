import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    required property var media
    required property var colors
    required property Item pager
    required property Item blurSource
    property int staggerMs: 45

    readonly property var player: media.player
    readonly property bool hasShuffle: (player?.shuffleSupported ?? false) && (player?.canControl ?? false)
    readonly property bool hasLoop: (player?.loopSupported ?? false) && (player?.canControl ?? false)
    readonly property bool canSeek: player?.canSeek ?? false

    function seekBy(seconds) {
        if (!player || !canSeek) return;
        const length = player.length > 0 ? player.length : Number.MAX_VALUE;
        player.position = Math.max(0, Math.min(length, player.position + seconds));
    }
    property list<real> visualizerPoints: []

    Process {
        id: cavaProc
        running: root.visible && root.media.playing
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        onRunningChanged: if (!running) root.visualizerPoints = []
        stdout: SplitParser {
            onRead: data => root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
        }
    }

    readonly property color fg: colors.colOnLayer0
    readonly property color fgDim: colors.colSubtext
    readonly property color hoverColor: colors.colSecondaryContainerHover
    readonly property color activeColor: colors.colSecondaryContainerActive

    property string shownTitle: ""
    property string shownArtist: ""
    readonly property string trackKey: (player?.trackTitle ?? "") + "|" + (player?.trackArtist ?? "")

    onTrackKeyChanged: trackSwap.restart()
    Component.onCompleted: {
        shownTitle = player?.trackTitle ?? "";
        shownArtist = player?.trackArtist ?? "";
    }

    SequentialAnimation {
        id: trackSwap
        ParallelAnimation {
            NumberAnimation { target: infoColumn; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InQuad }
            NumberAnimation { target: infoShift; property: "x"; to: -40; duration: 160; easing.type: Easing.InQuad }
            NumberAnimation { target: lyricsView; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                root.shownTitle = root.player?.trackTitle ?? "";
                root.shownArtist = root.player?.trackArtist ?? "";
                infoShift.x = 40;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: infoColumn; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: infoShift; property: "x"; to: 0; duration: 420; easing.type: Easing.OutBack }
            NumberAnimation { target: lyricsView; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: artPop
        ParallelAnimation {
            NumberAnimation { target: artImage; property: "scale"; to: 0.88; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: artImage; property: "opacity"; to: 0.2; duration: 140 }
        }
        ParallelAnimation {
            SpringAnimation { target: artImage; property: "scale"; to: 1; spring: 3; damping: 0.28 }
            NumberAnimation { target: artImage; property: "opacity"; to: 1; duration: 260 }
        }
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds || 0));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    WaveVisualizer {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: -16
        anchors.rightMargin: -16
        anchors.bottomMargin: -16
        height: parent.height * 0.4
        live: root.media.playing
        points: root.visualizerPoints
        color: root.colors.colPrimary
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: root.width * 0.46
            Layout.maximumWidth: root.width * 0.46
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                DashboardCard {
                    id: artCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width, parent.height)
                    height: width
                    tint: root.colors.colSecondaryContainer
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 0
                    travelX: -320
                    travelY: 0

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: root.media.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(artCard.width * 2, artCard.height * 2)
                        onSourceChanged: artPop.restart()
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artCard.width
                                height: artCard.height
                                radius: artCard.cardRadius
                            }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: "music_note"
                        fill: 1
                        iconSize: 96
                        color: root.colors.colPrimary
                    }
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.preferredHeight: infoColumn.implicitHeight
                tint: "transparent"
                pager: root.pager
                staggerMs: root.staggerMs
                animIndex: 1
                travelX: -300
                travelY: 100

                ColumnLayout {
                    id: infoColumn
                    transform: Translate { id: infoShift }
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.shownTitle || Translation.tr("Nothing playing")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 34
                        font.weight: Font.Bold
                        color: root.fg
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.shownArtist
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.larger
                        color: root.fgDim
                        elide: Text.ElideRight
                    }
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.preferredHeight: controlsLayout.implicitHeight + 28
                tint: root.colors.colSecondaryContainer
                tintOpacity: 0.45
                blurSource: root.blurSource
                pager: root.pager
                staggerMs: root.staggerMs
                animIndex: 2
                travelX: -200
                travelY: 260

                Rectangle {
                    anchors.fill: parent
                    radius: parent.cardRadius
                    color: Qt.rgba(0, 0, 0, 0.28)
                }

                ColumnLayout {
                    id: controlsLayout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            text: root.formatTime(root.player?.position)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.fg
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            configuration: StyledSlider.Configuration.Wavy
                            enabled: root.player?.canSeek ?? false
                            highlightColor: root.colors.colPrimary
                            trackColor: root.colors.colSecondaryContainer
                            handleColor: root.colors.colPrimary
                            value: (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1)
                            onMoved: root.player.position = value * root.player.length
                        }

                        StyledText {
                            text: "-" + root.formatTime((root.player?.length ?? 0) - (root.player?.position ?? 0))
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.fg
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        RippleButton {
                            implicitWidth: 40
                            implicitHeight: 40
                            buttonRadius: 20
                            toggled: root.hasShuffle && (root.player?.shuffle ?? false)
                            enabled: root.hasShuffle || root.canSeek
                            colBackground: "transparent"
                            colBackgroundHover: root.hoverColor
                            colBackgroundToggled: root.activeColor
                            colBackgroundToggledHover: root.activeColor
                            colRipple: root.activeColor
                            downAction: () => {
                                if (root.hasShuffle) root.player.shuffle = !root.player.shuffle;
                                else root.seekBy(-10);
                            }
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.hasShuffle ? "shuffle" : "replay_10"
                                    iconSize: 20
                                    color: root.fg
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: 48
                            implicitHeight: 48
                            buttonRadius: 24
                            colBackground: "transparent"
                            colBackgroundHover: root.hoverColor
                            colRipple: root.activeColor
                            downAction: () => root.player?.previous()
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "fast_rewind"
                                    iconSize: 26
                                    fill: 1
                                    color: root.fg
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 64
                            implicitHeight: 64
                            buttonRadius: root.media.playing ? Appearance.rounding.large : 32
                            colBackground: root.colors.colPrimary
                            colBackgroundHover: root.colors.colPrimaryHover
                            colRipple: root.colors.colPrimaryActive
                            downAction: () => root.player?.togglePlaying()
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.media.playing ? "pause" : "play_arrow"
                                    iconSize: 32
                                    fill: 1
                                    color: root.colors.colOnPrimary
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 48
                            implicitHeight: 48
                            buttonRadius: 24
                            colBackground: "transparent"
                            colBackgroundHover: root.hoverColor
                            colRipple: root.activeColor
                            downAction: () => root.player?.next()
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "fast_forward"
                                    iconSize: 26
                                    fill: 1
                                    color: root.fg
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: 40
                            implicitHeight: 40
                            buttonRadius: 20
                            toggled: root.hasLoop && (root.player?.loopState ?? 0) !== 0
                            enabled: root.hasLoop || root.canSeek
                            colBackground: "transparent"
                            colBackgroundHover: root.hoverColor
                            colBackgroundToggled: root.activeColor
                            colBackgroundToggledHover: root.activeColor
                            colRipple: root.activeColor
                            downAction: () => {
                                if (root.hasLoop) root.player.loopState = root.player.loopState === 0 ? 2 : 0;
                                else root.seekBy(10);
                            }
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.hasLoop ? "repeat" : "forward_10"
                                    iconSize: 20
                                    color: root.fg
                                }
                            }
                        }
                    }
                }
            }
        }

        DashboardCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            tint: "transparent"
            pager: root.pager
            staggerMs: root.staggerMs
            animIndex: 3
            travelX: 320
            travelY: -60

            Lyrics {
                id: lyricsView
                anchors.fill: parent
                fontScale: 1.8
                animateTransitions: true
                lineSpacing: 28
                textAlignment: Text.AlignHCenter
                textColor: root.fg
                activeColor: root.colors.colPrimary
                dimColor: root.fgDim
                indicatorColor: root.colors.colSecondaryContainer
                indicatorShapeColor: root.colors.colOnSecondaryContainer
            }

            StyledComboBoxSearch {
                id: playerSelector

                readonly property var players: Array.from(MprisController.players)
                readonly property int activeIndex: players.findIndex(p => p === MprisController.activePlayer)
                readonly property color solid: Qt.rgba(root.colors.colLayer1.r, root.colors.colLayer1.g, root.colors.colLayer1.b, 1)

                visible: players.length > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                width: Math.min(300, parent.width - 28)
                popupAbove: true
                splitIndicator: true
                textRole: "displayName"
                model: players.map(p => ({ displayName: `${p.identity ?? p.desktopEntry ?? Translation.tr("Unknown")} · ${p.trackTitle || "—"}`, icon: "music_note" }))
                onActivated: index => MprisController.manualPlayer = players[index]

                function syncIndex() {
                    playerSelector.currentIndex = playerSelector.activeIndex;
                }
                onActiveIndexChanged: Qt.callLater(syncIndex)
                onModelChanged: Qt.callLater(syncIndex)
                onCountChanged: Qt.callLater(syncIndex)
                Component.onCompleted: syncIndex()

                colBackground: root.colors.colSecondaryContainer
                colBackgroundHover: root.colors.colSecondaryContainerHover
                colBackgroundActive: root.colors.colSecondaryContainerActive
                colText: root.colors.colOnSecondaryContainer
                colAccent: root.colors.colPrimary
                colOnAccent: root.colors.colOnPrimary
                colPopup: playerSelector.solid
                colSelected: root.colors.colSecondaryContainer
                colSelectedHover: root.colors.colSecondaryContainerHover
                colSelectedActive: root.colors.colSecondaryContainerActive
                colOnSelected: root.colors.colOnSecondaryContainer
                colItemHover: root.colors.colSecondaryContainerHover
                colItemActive: root.colors.colSecondaryContainerActive
                colOnItem: root.colors.colOnLayer1
                colSearch: root.colors.colLayer0
                colOnSearch: root.colors.colOnLayer1
                colSearchHint: root.colors.colSubtext
            }
        }
    }
}
