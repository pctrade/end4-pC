import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Compact face of the IMDb rating: the yellow IMDb mark, the show and episode, and the rating counting up to
// its value. The best episode of the season gets a crown and one sweep of light across the pill.
Item {
    id: watch
    required property Item di
    anchors.fill: parent

    readonly property var now: WatchRating.now
    readonly property bool hasEpisode: (watch.now?.season ?? 0) > 0
    readonly property real target: watch.hasEpisode && WatchRating.episodeRating >= 0 ? WatchRating.episodeRating : WatchRating.seriesRating
    property real shown: 0

    NumberAnimation on shown {
        id: countUp
        from: 0
        to: watch.target
        duration: 900
        easing.type: Easing.OutCubic
    }
    onTargetChanged: countUp.restart()

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 12
        }
        spacing: 9

        Rectangle {
            implicitWidth: imdbText.implicitWidth + 10
            implicitHeight: 18
            radius: 4
            color: "#F5C518"

            StyledText {
                id: imdbText
                anchors.centerIn: parent
                text: "IMDb"
                font.pixelSize: 10
                font.weight: Font.Black
                color: "#000000"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: watch.now?.series ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: watch.hasEpisode
                    ? `T${watch.now.season} · E${watch.now.episode}${watch.now.episodeTitle ? " · " + watch.now.episodeTitle : ""}`
                    : (WatchRating.info?.Year ?? "")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: WatchRating.isBest
            implicitWidth: 20
            implicitHeight: 20
            radius: 10
            color: Qt.rgba(0.96, 0.77, 0.09, 0.18)
            scale: 0

            NumberAnimation on scale {
                running: WatchRating.isBest
                from: 0
                to: 1
                duration: 520
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "crown"
                iconSize: 13
                fill: 1
                color: "#F5C518"
            }
        }

        RowLayout {
            spacing: 2
            MaterialSymbol {
                text: "star"
                iconSize: 15
                fill: 1
                color: "#F5C518"
            }
            StyledText {
                // An episode IMDb hasn't rated yet says so, instead of passing the series' rating off as its own
                text: watch.hasEpisode && WatchRating.episodeRating < 0 ? "–" : watch.shown.toFixed(1)
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
        }
    }

    // One sweep of light for the best episode of the season
    Item {
        anchors.fill: parent
        clip: true
        visible: WatchRating.isBest

        Rectangle {
            id: sweep
            width: 70
            height: parent.height * 2
            y: -parent.height / 2
            rotation: 18
            x: -100
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.86, 0.3, 0.16) }
                GradientStop { position: 1; color: "transparent" }
            }

            SequentialAnimation on x {
                running: WatchRating.isBest
                PauseAnimation { duration: 450 }
                NumberAnimation { from: -100; to: watch.width + 40; duration: 1100; easing.type: Easing.InOutCubic }
            }
        }
    }
}
