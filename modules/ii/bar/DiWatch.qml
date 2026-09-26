import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The episode that just started, and its IMDb rating — the episode's, never the show's (you already know
// that one; it lives small in the expanded view). The rating arrives as a small motion piece: a ring draws
// itself from zero to the score while the number counts up with it, coloured by how good the episode is;
// once it lands, the season/episode line rises in under the show's name.
//
// Then one highlight, the rarest that applies (WatchRating.tier):
//   top3  — top 3 of the whole show: gold/silver/bronze medal, confetti bursting from the ring, gold sweep
//   top10 — top 10 of the show: violet trophy, violet sweep
//   best  — best of its season: crown, gold sweep
//   high  — 8.5 or more: the ring's halo pulses twice
Item {
    id: watch
    required property Item di
    anchors.fill: parent

    readonly property var now: WatchRating.now
    readonly property var next: IslandEvents.watchRating.payload?.next ?? null
    readonly property bool isFilm: !watch.next && (watch.now?.season ?? 0) <= 0
    readonly property real rating: watch.next ? watch.next.rating : watch.isFilm ? WatchRating.seriesRating : WatchRating.episodeRating
    readonly property string tier: watch.next ? watch.next.tier : watch.isFilm ? "" : WatchRating.tier
    readonly property int seriesRank: watch.next ? watch.next.seriesRank : WatchRating.seriesRank
    readonly property color tone: watch.rating >= 8.5 ? "#F5C518"
        : watch.rating >= 7.5 ? "#30D158"
        : watch.rating >= 6 ? "#FF9F0A" : "#FF453A"
    readonly property color medal: watch.seriesRank === 1 ? "#F5C518" : watch.seriesRank === 2 ? "#D7DDE5" : "#D08A4E"
    readonly property color accent: watch.tier === "top3" ? watch.medal
        : watch.tier === "top10" ? "#BF5AF2" : "#F5C518"
    readonly property string badgeIcon: watch.tier === "top3" ? "workspace_premium"
        : watch.tier === "top10" ? "military_tech" : watch.tier === "best" ? "crown" : ""
    readonly property string badgeText: watch.tier === "top3" ? Translation.tr("#%1 of the show").arg(watch.seriesRank)
        : watch.tier === "top10" ? Translation.tr("Top 10 of the show")
        : watch.tier === "best" ? Translation.tr("Best of the season") : ""

    property real t: 0
    SequentialAnimation {
        id: entrance
        running: true
        PauseAnimation { duration: 180 }
        NumberAnimation { target: watch; property: "t"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
        ScriptAction { script: if (watch.tier !== "") highlight.restart() }
    }
    onRatingChanged: entrance.restart()

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
            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: showName.bottom
                    topMargin: -2 + (1 - watch.landed) * 10
                }
                spacing: 4
                opacity: watch.landed

                StyledText {
                    visible: watch.badgeText !== ""
                    text: watch.badgeText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: watch.accent
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: watch.isFilm ? (WatchRating.info?.Year ?? "")
                        : watch.next ? `${watch.badgeText !== "" ? "· " : ""}${Translation.tr("Up next")} · T${watch.next.season} · E${watch.next.episode}${watch.next.title ? " · " + watch.next.title : ""}`
                        : `${watch.badgeText !== "" ? "· " : ""}T${watch.now?.season} · E${watch.now?.episode}${WatchRating.episodeTitle ? " · " + WatchRating.episodeTitle : ""}`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }

        MaterialSymbol {
            visible: watch.badgeIcon !== ""
            text: watch.badgeIcon
            iconSize: 16
            fill: 1
            color: watch.accent
            scale: watch.landed * (1 + 0.25 * badgePop.value)
            transform: Translate { y: (1 - watch.landed) * -10 }

            QtObject {
                id: badgePop
                property real value: 0
            }
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

        Item {
            id: score
            implicitWidth: 28
            implicitHeight: 28

            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: watch.tier === "high" ? watch.tone : watch.accent
                opacity: 0
            }

            CircularProgress {
                anchors.fill: parent
                implicitSize: 28
                lineWidth: 3
                value: Math.max(0, watch.rating) / 10 * watch.t
                colPrimary: watch.tier === "top3" || watch.tier === "top10" ? watch.accent : watch.tone
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

            Repeater {
                model: watch.tier === "top3" ? 12 : 0
                delegate: Rectangle {
                    id: bit
                    required property int index
                    readonly property real angle: bit.index / 12 * Math.PI * 2 + 0.3
                    readonly property real reach: 16 + (bit.index % 3) * 6
                    property real p: 0
                    x: score.width / 2 - width / 2 + Math.cos(bit.angle) * bit.reach * bit.p
                    y: score.height / 2 - height / 2 + Math.sin(bit.angle) * bit.reach * bit.p + 6 * bit.p * bit.p
                    width: bit.index % 2 ? 5 : 3
                    height: bit.index % 2 ? 3 : 5
                    radius: 1
                    rotation: bit.p * (bit.index % 2 ? 220 : -180)
                    color: [watch.medal, "#FFFFFF", watch.tone][bit.index % 3]
                    opacity: bit.p > 0 ? 1 - bit.p : 0

                    Connections {
                        target: highlight
                        function onStarted() { burst.restart() }
                    }
                    NumberAnimation {
                        id: burst
                        target: bit
                        property: "p"
                        from: 0
                        to: 1
                        duration: 900 + (bit.index % 4) * 120
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: watch.badgeIcon !== ""

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
                GradientStop { position: 0.5; color: Qt.rgba(watch.accent.r, watch.accent.g, watch.accent.b, 0.18) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    SequentialAnimation {
        id: highlight
        ParallelAnimation {
            SequentialAnimation {
                loops: 2
                NumberAnimation { target: halo; property: "opacity"; from: 0; to: 0.9; duration: 200; easing.type: Easing.OutQuad }
                ParallelAnimation {
                    NumberAnimation { target: halo; property: "opacity"; to: 0; duration: 520; easing.type: Easing.InQuad }
                    NumberAnimation { target: halo; property: "scale"; from: 1; to: 1.14; duration: 520; easing.type: Easing.OutCubic }
                }
                PropertyAction { target: halo; property: "scale"; value: 1 }
            }
            SequentialAnimation {
                NumberAnimation { target: badgePop; property: "value"; from: 0; to: 1; duration: 160; easing.type: Easing.OutQuad }
                NumberAnimation { target: badgePop; property: "value"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: sweep; property: "x"; from: -100; to: watch.width + 40; duration: 1100; easing.type: Easing.InOutCubic }
            }
        }
    }
}
