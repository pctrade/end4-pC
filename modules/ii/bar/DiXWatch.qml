import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Expanded face of the IMDb rating: the show, this episode's rating and where it ranks, and the whole season
// as a bar chart that grows in one bar after another. The current episode is lit, the best one is gold, and
// hovering a bar says which episode it is.
ColumnLayout {
    id: xw
    required property Item di
    spacing: 12
    implicitWidth: 400

    readonly property var now: WatchRating.now
    readonly property bool hasEpisode: (xw.now?.season ?? 0) > 0
    readonly property var episodes: WatchRating.seasonEpisodes
    readonly property var rated: xw.episodes.map(e => WatchRating.ratingOf(e)).filter(r => r >= 0)
    readonly property real low: xw.rated.length ? Math.min(...xw.rated) : 0
    readonly property real high: xw.rated.length ? Math.max(...xw.rated) : 10
    property int hovered: -1
    readonly property var focusEpisode: xw.hovered >= 0 ? xw.episodes[xw.hovered] : WatchRating.currentEpisode

    // Header: IMDb mark, the show, its overall rating
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 44
            implicitHeight: 22
            radius: 5
            color: "#F5C518"
            StyledText {
                anchors.centerIn: parent
                text: "IMDb"
                font.pixelSize: 12
                font.weight: Font.Black
                color: "#000000"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -2
            StyledText {
                Layout.fillWidth: true
                text: WatchRating.info?.Title ?? xw.now?.series ?? ""
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                text: [WatchRating.info?.Year, WatchRating.info?.Genre].filter(Boolean).join(" · ")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
        }

        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: "star"
                iconSize: 16
                fill: 1
                color: "#F5C518"
            }
            StyledText {
                text: WatchRating.seriesRating >= 0 ? WatchRating.seriesRating.toFixed(1) : "–"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
        }
    }

    // This episode (or the hovered one)
    Rectangle {
        Layout.fillWidth: true
        visible: xw.hasEpisode && xw.focusEpisode !== null
        implicitHeight: 52
        radius: 14
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: `T${xw.now?.season ?? ""} · E${xw.focusEpisode?.Episode ?? ""} · ${xw.focusEpisode?.Title ?? ""}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    text: {
                        if (xw.hovered >= 0) return xw.focusEpisode?.Released ?? ""
                        if (WatchRating.isBest) return Translation.tr("Best of the season")
                        if (WatchRating.rank > 0) return Translation.tr("#%1 of %2 this season").arg(WatchRating.rank).arg(WatchRating.ratedCount)
                        return ""
                    }
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: WatchRating.isBest && xw.hovered < 0 ? "#F5C518" : Appearance.colors.colOnLayer1
                    opacity: 0.8
                }
            }

            StyledText {
                text: WatchRating.ratingOf(xw.focusEpisode) >= 0 ? WatchRating.ratingOf(xw.focusEpisode).toFixed(1) : "–"
                font.pixelSize: 22
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    // The season, one bar per episode
    Item {
        Layout.fillWidth: true
        visible: xw.hasEpisode && xw.episodes.length > 0
        implicitHeight: 86

        Row {
            id: bars
            anchors.fill: parent
            anchors.bottomMargin: 14
            spacing: 3
            readonly property real barWidth: Math.max(4, (bars.width - (xw.episodes.length - 1) * bars.spacing) / Math.max(1, xw.episodes.length))

            Repeater {
                model: xw.episodes
                delegate: Item {
                    id: barSlot
                    required property var modelData
                    required property int index
                    readonly property real rating: WatchRating.ratingOf(barSlot.modelData)
                    readonly property bool current: Number(barSlot.modelData.Episode) === (xw.now?.episode ?? -1)
                    readonly property bool best: WatchRating.bestEpisode === barSlot.modelData
                    // Spread the season's own range over the bar, keeping a floor so the worst one still shows
                    readonly property real level: barSlot.rating < 0 ? 0.08
                        : 0.18 + 0.82 * (xw.high > xw.low ? (barSlot.rating - xw.low) / (xw.high - xw.low) : 1)
                    property real grow: 0
                    width: bars.barWidth
                    height: bars.height

                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: 80 + barSlot.index * 22 }
                        NumberAnimation { target: barSlot; property: "grow"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(3, parent.height * barSlot.level * barSlot.grow)
                        radius: Math.min(width / 2, 4)
                        color: barSlot.best ? "#F5C518"
                            : barSlot.current ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, xw.hovered === barSlot.index ? 0.45 : 0.78)

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                            if (containsMouse) xw.hovered = barSlot.index
                            else if (xw.hovered === barSlot.index) xw.hovered = -1
                        }
                    }
                }
            }
        }

        // Where "now" is, under its bar
        Rectangle {
            readonly property int currentIndex: xw.episodes.findIndex(e => Number(e.Episode) === (xw.now?.episode ?? -1))
            visible: currentIndex >= 0
            x: currentIndex * (bars.barWidth + bars.spacing) + bars.barWidth / 2 - width / 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 5
            height: 5
            radius: 2.5
            color: Appearance.colors.colPrimary
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: (xw.now?.source ?? "") === "page"
        text: Translation.tr("Install scripts/island/watch-rating.user.js in Tampermonkey to see each episode's rating")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.5
        wrapMode: Text.Wrap
    }
}
