import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The playing track with its cover, its progress and the playback buttons
BentoTile {
    id: root
    required property MprisPlayer player
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property bool hasProgress: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0

    // Position read every frame while playing, so the bar glides instead of jumping each second
    property real position: 0
    function readPosition() {
        root.position = root.player?.position ?? 0;
    }
    onPlayerChanged: root.readPosition()
    onPlayingChanged: root.readPosition()
    FrameAnimation {
        running: root.playing && root.visible && root.hasProgress
        onTriggered: root.readPosition()
    }
    Connections {
        target: root.player
        function onPostTrackChanged() { root.readPosition(); }
        function onPositionChanged() { if (!root.playing) root.readPosition(); }
    }

    // Cover art, cached like the media widget does: a remote cover is downloaded once
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property string artFilePath: `${Directories.coverArt}/${Qt.md5(root.artUrl)}`
    property bool coverDownloaded: false
    readonly property string coverUrl: {
        if (root.artUrl.length === 0) return "";
        if (root.artUrl.startsWith("file://")) return root.artUrl;
        return root.coverDownloaded ? Qt.resolvedUrl(root.artFilePath) : "";
    }
    onArtFilePathChanged: {
        root.coverDownloaded = false;
        if (root.artUrl.length === 0 || root.artUrl.startsWith("file://")) return;
        coverDownloader.command = ["bash", "-c", '[ -f "$1" ] || curl -sSL "$2" -o "$1"', "_", root.artFilePath, root.artUrl];
        coverDownloader.running = true;
    }
    Process {
        id: coverDownloader
        onExited: root.coverDownloaded = true
    }

    component ControlButton: RippleButton {
        id: control
        property string iconName
        property real size: 32
        implicitWidth: control.size
        implicitHeight: control.size
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive
        MaterialSymbol {
            anchors.centerIn: parent
            text: control.iconName
            fill: 1
            iconSize: control.size * 0.6
            color: Appearance.colors.colOnSecondaryContainer
        }
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    implicitHeight: content.implicitHeight + 24
    color: Appearance.colors.colSecondaryContainer

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
            rightMargin: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Item {
                implicitWidth: 48
                implicitHeight: 48
                MaterialShapeWrappedMaterialSymbol {
                    anchors.fill: parent
                    visible: cover.status !== Image.Ready
                    shape: MaterialShape.Shape.Cookie9Sided
                    color: Appearance.colors.colSecondary
                    colSymbol: Appearance.colors.colOnSecondary
                    text: "music_note"
                    fill: 1
                    iconSize: 22
                    padding: 10
                }
                ClippingRectangle {
                    anchors.fill: parent
                    visible: cover.status === Image.Ready
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    StyledImage {
                        id: cover
                        anchors.fill: parent
                        source: root.coverUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(96, 96)
                        asynchronous: true
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? ""
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnSecondaryContainer
                    font {
                        family: "Google Sans Flex"
                        pixelSize: Appearance.font.pixelSize.normal
                        weight: 800
                        variableAxes: ({ "wght": 800 })
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnSecondaryContainer
                    opacity: 0.8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
            ControlButton {
                visible: root.player?.canGoPrevious ?? false
                iconName: "skip_previous"
                onClicked: MprisController.previous()
            }
            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondary
                colBackgroundHover: Appearance.colors.colSecondaryHover
                colRipple: Appearance.colors.colSecondaryActive
                onClicked: MprisController.togglePlaying()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.playing ? "pause" : "play_arrow"
                    fill: 1
                    iconSize: 22
                    color: Appearance.colors.colOnSecondary
                }
            }
            ControlButton {
                visible: root.player?.canGoNext ?? false
                iconName: "skip_next"
                onClicked: MprisController.next()
            }
        }

        RowLayout {
            visible: root.hasProgress
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 10
            StyledText {
                text: root.formatTime(root.position)
                color: Appearance.colors.colOnSecondaryContainer
                font {
                    pixelSize: Appearance.font.pixelSize.smallest
                    features: { "tnum": 1 }
                }
            }
            StyledProgressBar {
                Layout.fillWidth: true
                value: root.hasProgress ? Math.min(1, root.position / root.player.length) : 0
                animateValue: false
                valueBarHeight: 6
                // Waves while playing, flat when paused
                wavy: root.playing
                animateWave: root.playing && root.visible
                highlightColor: Appearance.colors.colOnSecondaryContainer
                trackColor: Appearance.colors.colSecondaryContainerActive
            }
            StyledText {
                text: root.formatTime(root.player?.length ?? 0)
                color: Appearance.colors.colOnSecondaryContainer
                font {
                    pixelSize: Appearance.font.pixelSize.smallest
                    features: { "tnum": 1 }
                }
            }
        }
    }
}
