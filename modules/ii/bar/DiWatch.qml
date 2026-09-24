import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The episode that just started, and its IMDb rating — the episode's, never the show's (you already know
// that one; it lives small in the expanded view). The rating arrives as a small motion piece: a ring draws
// itself from zero to the score while the number counts up with it, coloured by how good the episode is;
// once it lands, the season/episode line rises in under the show's name, and the best episode of the
// season gets a crown and one sweep of gold light.
Item {
    id: watch
    required property Item di
    anchors.fill: parent

    readonly property var now: WatchRating.now
    readonly property bool isFilm: (watch.now?.season ?? 0) <= 0
    readonly property real rating: watch.isFilm ? WatchRating.seriesRating : WatchRating.episodeRating
    readonly property color tone: watch.rating >= 8.5 ? "#F5C518"
        : watch.rating >= 7.5 ? "#30D158"
        : watch.rating >= 6 ? "#FF9F0A" : "#FF453A"

    // 0 → 1 drives the whole entrance
    property real t: 0
    SequentialAnimation {
        id: entrance
        running: true
        PauseAnimation { duration: 180 }
        NumberAnimation { target: watch; property: "t"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
    }
    onRatingChanged: entrance.restart()

    // The line under the name only rises once the score has landed
    readonly property real landed: Math.max(0, Math.min(1, (watch.t - 0.7) / 0.3))

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 9
            rightMargin: 6
        }
        spacing: 9

        DiServiceMark {
            service: WatchRating.service
            size: 18
            scale: Math.min(1, watch.t * 3)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            clip: true

            StyledText {
                id: showName
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -6 * watch.landed
                }
                text: watch.now?.series ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: showName.bottom
                    topMargin: -2 + (1 - watch.landed) * 10
                }
                text: watch.isFilm ? (WatchRating.info?.Year ?? "")
                    : `T${watch.now?.season} · E${watch.now?.episode}${WatchRating.episodeTitle ? " · " + WatchRating.episodeTitle : ""}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7 * watch.landed
                elide: Text.ElideRight
            }
        }

        // Best of the season: the crown drops in once the score has landed
        MaterialSymbol {
            visible: WatchRating.isBest
            text: "crown"
            iconSize: 15
            fill: 1
            color: "#F5C518"
            scale: watch.landed
            transform: Translate { y: (1 - watch.landed) * -10 }
        }

        Rectangle {
            implicitWidth: imdbText.implicitWidth + 7
            implicitHeight: 14
            radius: 3
            color: "#F5C518"
            opacity: Math.min(1, watch.t * 2)

            StyledText {
                id: imdbText
                anchors.centerIn: parent
                text: "IMDb"
                font.pixelSize: 8
                font.weight: Font.Black
                color: "#000000"
            }
        }

        // The score: a ring drawing itself to rating/10 with the number counting up inside it
        Item {
            implicitWidth: 28
            implicitHeight: 28

            CircularProgress {
                anchors.fill: parent
                implicitSize: 28
                lineWidth: 3
                value: Math.max(0, watch.rating) / 10 * watch.t
                colPrimary: watch.tone
                colSecondary: Qt.rgba(1, 1, 1, 0.08)
            }

            StyledText {
                anchors.centerIn: parent
                text: watch.rating < 0 ? "–" : (Math.max(0, watch.rating) * watch.t).toFixed(1)
                font.pixelSize: 10
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
        }
    }

    // One sweep of gold light for the best episode of the season
    Item {
        anchors.fill: parent
        clip: true
        visible: WatchRating.isBest

        Rectangle {
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
                PauseAnimation { duration: 1300 }
                NumberAnimation { from: -100; to: watch.width + 40; duration: 1100; easing.type: Easing.InOutCubic }
            }
        }
    }
}
