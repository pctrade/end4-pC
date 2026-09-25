import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: media
    required property Item di
    anchors.fill: parent

    readonly property MprisPlayer player: media.di.activePlayer
    readonly property real progress: (media.player?.length ?? 0) > 0 ? Math.min(1, media.player.position / media.player.length) : 0
    readonly property bool showLyric: !media.di.mediaTrackInfoVisible && media.di.lyricLine !== ""
    readonly property bool hasArt: (media.player?.trackArtUrl ?? "") !== ""
    // Shared with the full view: the album art travels into the big cover
    readonly property var hero: media.hasArt ? { key: "media-art", item: artMask } : null

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        visible: media.di.cfg.albumColors ?? true
        color: ColorUtils.transparentize(media.di.mediaArtColor, 0.84)

        Behavior on color {
            ColorAnimation { duration: 600 }
        }
    }

    Item {
        id: artBox
        x: media.di.isMaterial ? 1 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30

        CircularProgress {
            anchors.fill: parent
            implicitSize: 30
            lineWidth: 2
            value: media.progress
            colPrimary: media.di.mediaArtColor
            colSecondary: ColorUtils.transparentize(media.di.mediaArtColor, 0.8)
            enableAnimation: false
        }

        Rectangle {
            id: artMask
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: Appearance.colors.colLayer1
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: artMask.width
                    height: artMask.height
                    radius: artMask.radius
                }
            }

            StyledImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: media.player?.trackArtUrl ?? ""
                sourceSize.width: 48
                sourceSize.height: 48
                visible: media.hasArt
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 13
                color: Appearance.colors.colOnLayer1
                visible: !media.hasArt
            }
        }

        SequentialAnimation {
            id: swapArt
            ParallelAnimation {
                NumberAnimation { target: artMask; property: "scale"; to: 0.3; duration: IslandMotion.micro; easing.type: Easing.InQuad }
                NumberAnimation { target: artMask; property: "rotation"; to: -90; duration: IslandMotion.micro; easing.type: Easing.InQuad }
            }
            PropertyAction { target: artMask; property: "rotation"; value: 90 }
            ParallelAnimation {
                NumberAnimation { target: artMask; property: "scale"; to: 1; duration: IslandMotion.long; easing.type: Easing.OutBack; easing.overshoot: 2 }
                NumberAnimation { target: artMask; property: "rotation"; to: 0; duration: IslandMotion.long; easing.type: Easing.OutBack }
            }
        }

        Connections {
            target: media.player
            function onTrackTitleChanged() {}
        }
    }

    StyledText {
        id: trackTitleMetrics
        visible: false
        text: media.player?.trackTitle ?? ""
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
    }
    StyledText {
        id: trackArtistMetrics
        visible: false
        text: media.player?.trackArtist ?? ""
        font.pixelSize: Appearance.font.pixelSize.smallest
    }

    readonly property Item trailingItem: mediaControlsRow.visible ? mediaControlsRow
        : (visualizerCanvas.visible ? visualizerCanvas : (islandVisualizer.visible ? islandVisualizer : null))

    ColumnLayout {
        id: trackInfoColumn
        anchors {
            left: artBox.right
            leftMargin: 7
            verticalCenter: parent.verticalCenter
            right: media.trailingItem ? media.trailingItem.left : parent.right
            rightMargin: 8
        }
        spacing: media.di.isMaterial ? -2 : -4
        opacity: media.di.mediaTrackInfoVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
        }

        StyledText {
            Layout.fillWidth: true
            text: media.player?.trackTitle ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        StyledText {
            Layout.fillWidth: true
            text: media.player?.trackArtist ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        readonly property real computedContentWidth: artBox.width + (media.di.isMaterial ? 1 : 3) + 7
            + Math.max(trackTitleMetrics.implicitWidth, trackArtistMetrics.implicitWidth)
            + 10 + (media.trailingItem ? media.trailingItem.width : 0) + 10

        onComputedContentWidthChanged: media.di.mediaTextContentWidth = trackInfoColumn.computedContentWidth
        Component.onCompleted: media.di.mediaTextContentWidth = trackInfoColumn.computedContentWidth
    }

    StyledText {
        id: lyricText
        anchors {
            left: artBox.right
            leftMargin: 7
            verticalCenter: parent.verticalCenter
            right: media.trailingItem ? media.trailingItem.left : parent.right
            rightMargin: 8
        }
        text: media.di.lyricLine
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        font.italic: true
        color: Appearance.colors.colOnLayer0
        elide: Text.ElideRight
        opacity: media.showLyric ? 1 : 0
        visible: opacity > 0

        property real slide: 0
        transform: Translate { y: lyricText.slide }

        onTextChanged: lyricIn.restart()

        ParallelAnimation {
            id: lyricIn
            NumberAnimation { target: lyricText; property: "slide"; from: 7; to: 0; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
            NumberAnimation { target: lyricText; property: "opacity"; from: 0; to: media.showLyric ? 1 : 0; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
        }
    }

    WaveVisualizer {
        id: visualizerCanvas
        anchors {
            right: mediaControlsRow.visible ? mediaControlsRow.left : parent.right
            rightMargin: mediaControlsRow.visible ? 6 : 10
            verticalCenter: parent.verticalCenter
        }
        width: media.di.isMaterial ? 60 : 50
        height: media.di.isMaterial ? media.di.pillHeight * 1.5 : media.di.pillHeight * 0.85
        live: media.player?.isPlaying ?? false
        points: GlobalStates.visualizerPoints
        maxVisualizerValue: 1000
        smoothing: 2
        color: (media.di.cfg.albumColors ?? true) ? media.di.mediaArtColor : Appearance.colors.colOnLayer0
        visible: media.di.cfg.visualizerStyle === "wave"
    }

    Visualizer {
        id: islandVisualizer
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        height: media.di.isMaterial ? media.di.pillHeight * 1.5 : media.di.pillHeight * 0.85
        vertical: false
        isMaterial: false
        barCount: 5
        dotSize: 3
        dotSpacing: 3
        maxBarHeight: height
        barColor: (media.di.cfg.albumColors ?? true) ? media.di.mediaArtColor : Appearance.colors.colOnLayer0
        visible: !media.di.cfg.showMediaControls && media.di.cfg.visualizerStyle === "dots"
    }

    RowLayout {
        id: mediaControlsRow
        anchors {
            right: parent.right
            rightMargin: media.di.isMaterial ? 4 : 8
            verticalCenter: parent.verticalCenter
        }
        spacing: media.di.isMaterial ? -2 : -4
        visible: media.di.cfg.showMediaControls ?? false

        Repeater {
            model: [
                { icon: "skip_previous", size: 20, show: media.player?.canGoPrevious ?? false, action: () => media.player?.previous() },
                { icon: media.player?.isPlaying ? "pause" : "play_arrow", size: 22, show: true, action: () => media.player?.togglePlaying() },
                { icon: "skip_next", size: 20, show: media.player?.canGoNext ?? false, action: () => media.player?.next() }
            ]
            delegate: Item {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: modelData.size
                implicitHeight: modelData.size
                visible: modelData.show

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: modelData.icon
                    fill: 1
                    iconSize: media.di.isMaterial ? 20 : modelData.size - 3
                    color: Appearance.colors.colOnLayer0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.action()
                }
            }
        }
    }
}
