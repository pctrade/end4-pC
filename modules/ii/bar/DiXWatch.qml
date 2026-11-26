import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Expanded IMDb rating: poster and season bars when a show plays, setup/status otherwise.
Item {
    id: xw
    required property Item di
    readonly property real wantedWidth: 532
    implicitWidth: xw.wantedWidth
    implicitHeight: body.implicitHeight

    Component.onCompleted: WatchRating.lookup()

    readonly property color gold: "#F5C518"
    readonly property var now: WatchRating.now
    readonly property var info: WatchRating.info
    readonly property bool hasShow: !!xw.info
    readonly property bool hasEpisode: (xw.now?.season ?? 0) > 0 && xw.episodes.length > 0
    readonly property var episodes: WatchRating.seasonEpisodes
    readonly property var rated: xw.episodes.map(e => WatchRating.ratingOf(e)).filter(r => r >= 0)
    readonly property real low: xw.rated.length ? Math.min(...xw.rated) : 0
    readonly property real high: xw.rated.length ? Math.max(...xw.rated) : 10
    property int hovered: -1
    readonly property var focusEpisode: xw.hovered >= 0 ? (xw.episodes[xw.hovered] ?? null) : WatchRating.currentEpisode

    readonly property bool switchedOff: Config.ready && Config.options.bar.dynamicIsland.watchRatings === false
    readonly property bool keyMissing: WatchRating.apiKey === ""
    readonly property string seriesName: xw.now?.series ?? ""
    readonly property var lookupResult: {
        WatchRating.revision
        return xw.seriesName !== "" ? WatchRating.titleCache[xw.seriesName.toLowerCase()] : undefined
    }
    readonly property var recent: {
        WatchRating.revision
        return Object.values(WatchRating.titleCache).filter(v => v && typeof v === "object").reverse().slice(0, 2)
    }

    function posterOf(title) {
        const url = title?.Poster ?? ""
        return url.startsWith("http") ? url : ""
    }
    function genres(title) {
        return (title?.Genre ?? "").split(", ").filter(Boolean).slice(0, 2).join(", ")
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component Poster: Rectangle {
        id: poster
        property var title: null
        property real corner: 12
        radius: poster.corner
        color: Appearance.colors.colLayer1
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: poster.width
                height: poster.height
                radius: poster.corner
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: posterImage.status !== Image.Ready
            text: "movie"
            iconSize: Math.min(28, poster.width * 0.5)
            fill: 1
            color: Appearance.colors.colOnLayer1
            opacity: 0.35
        }

        Image {
            id: posterImage
            anchors.fill: parent
            source: xw.posterOf(poster.title)
            sourceSize.width: poster.width * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.short }
            }
        }
    }

    component SetupRow: Rectangle {
        id: row
        property string icon
        property string label
        property string hint
        property bool ok: false
        property bool warn: false
        property var onTap: null
        property int order: 0
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 12
        color: rowMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }
        DiCascade { target: row; index: row.order; pressed: rowMouse.pressed }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 10
            }
            spacing: 10

            MaterialSymbol {
                text: row.icon
                iconSize: 17
                fill: 1
                color: row.warn ? Appearance.colors.colError : Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: row.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.hint
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.6
                    elide: Text.ElideMiddle
                }
            }
            MaterialSymbol {
                text: row.ok ? "check_circle" : row.warn ? "error" : "open_in_new"
                iconSize: 16
                fill: 1
                color: row.ok ? Appearance.colors.colPrimary : row.warn ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                opacity: row.ok || row.warn ? 1 : 0.5
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.onTap) row.onTap()
        }
    }

    Loader {
        id: body
        width: parent.width
        sourceComponent: xw.hasShow ? showView : emptyView
    }

    Component {
        id: showView

        RowLayout {
            spacing: 16

            Item {
                id: posterSlot
                Layout.fillWidth: false
                Layout.preferredWidth: 128
                Layout.preferredHeight: 190
                Layout.alignment: Qt.AlignTop
                DiCascade { target: posterSlot; index: 0 }

                Poster {
                    anchors.fill: parent
                    title: xw.info
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        margins: 8
                    }
                    visible: WatchRating.seriesRating >= 0
                    implicitWidth: seriesChip.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: ColorUtils.transparentize("#000000", 0.25)
                    RowLayout {
                        id: seriesChip
                        anchors.centerIn: parent
                        spacing: 3
                        MaterialSymbol {
                            text: "star"
                            iconSize: 14
                            fill: 1
                            color: xw.gold
                        }
                        StyledText {
                            text: WatchRating.seriesRating.toFixed(1)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: "#FFFFFF"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 10

                Item {
                    id: header
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight
                    DiCascade { target: header; index: 1 }

                    RowLayout {
                        id: headerRow
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: -2
                            StyledText {
                                Layout.fillWidth: true
                                text: xw.info?.Title ?? xw.seriesName
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: [xw.info?.Year, xw.genres(xw.info)].filter(Boolean).join(" · ")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }
                        DiServiceMark {
                            Layout.alignment: Qt.AlignTop
                            service: WatchRating.service
                            size: 18
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 38
                            implicitHeight: 18
                            radius: 4
                            color: xw.gold
                            StyledText {
                                anchors.centerIn: parent
                                text: "IMDb"
                                font.pixelSize: 11
                                font.weight: Font.Black
                                color: "#000000"
                            }
                        }
                    }
                }

                Rectangle {
                    id: episodeCard
                    Layout.fillWidth: true
                    visible: xw.hasEpisode && xw.focusEpisode !== null
                    implicitHeight: 62
                    radius: 12
                    color: Appearance.colors.colLayer1
                    DiCascade { target: episodeCard; index: 2 }

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
                            spacing: 0
                            StyledText {
                                text: Translation.tr("S%1 · E%2").arg(xw.now?.season ?? "").arg(xw.focusEpisode?.Episode ?? "")
                                    + (xw.hovered >= 0 && (xw.focusEpisode?.Released ?? "") !== "" ? ` · ${xw.focusEpisode.Released}` : "")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.6
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: (xw.hovered < 0 ? WatchRating.episodeTitle : "") || (xw.focusEpisode?.Title ?? "")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (xw.hovered >= 0) {
                                        const stats = WatchRating.statsFor(xw.focusEpisode)
                                        return stats ? Translation.tr("#%1 of the series").arg(stats.seriesRank) : ""
                                    }
                                    if (WatchRating.isTop3 || WatchRating.isTop10) return Translation.tr("#%1 of the series").arg(WatchRating.seriesRank)
                                    if (WatchRating.isBest) return Translation.tr("Best of the season")
                                    if (WatchRating.rank > 0) return Translation.tr("#%1 of %2 this season").arg(WatchRating.rank).arg(WatchRating.ratedCount)
                                    return ""
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: xw.hovered < 0 && (WatchRating.isBest || WatchRating.isTop3 || WatchRating.isTop10) ? xw.gold : Appearance.colors.colOnLayer1
                                opacity: 0.8
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            spacing: 2
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: "star"
                                iconSize: 18
                                fill: 1
                                color: xw.gold
                            }
                            StyledText {
                                text: WatchRating.ratingOf(xw.focusEpisode) >= 0 ? WatchRating.ratingOf(xw.focusEpisode).toFixed(1) : "–"
                                font.pixelSize: 32
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: chart
                    Layout.fillWidth: true
                    visible: xw.hasEpisode
                    spacing: 4
                    DiCascade { target: chart; index: 3 }

                    DiSpring {
                        id: chartReveal
                        stiffness: 50
                        dampingRatio: 1
                        epsilon: 0.002
                    }
                    Timer {
                        interval: 260
                        running: true
                        onTriggered: chartReveal.target = 1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        SectionLabel {
                            Layout.fillWidth: true
                            text: Translation.tr("Season %1").arg(xw.now?.season ?? "")
                        }
                        StyledText {
                            visible: xw.rated.length > 1
                            text: `${xw.low.toFixed(1)} – ${xw.high.toFixed(1)}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.55
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 64

                        Row {
                            id: bars
                            anchors.fill: parent
                            anchors.bottomMargin: 9
                            spacing: 3
                            readonly property int count: xw.episodes.length
                            readonly property real barWidth: Math.max(3, (bars.width - (bars.count - 1) * bars.spacing) / Math.max(1, bars.count))

                            Repeater {
                                model: bars.count
                                delegate: Item {
                                    id: barSlot
                                    required property int index
                                    readonly property var d: xw.episodes[barSlot.index] ?? null
                                    readonly property real rating: WatchRating.ratingOf(barSlot.d)
                                    readonly property bool current: Number(barSlot.d?.Episode ?? -1) === (xw.now?.episode ?? -2)
                                    readonly property bool best: barSlot.d !== null && WatchRating.bestEpisode === barSlot.d
                                    readonly property real level: barSlot.rating < 0 ? 0.08
                                        : 0.18 + 0.82 * (xw.high > xw.low ? (barSlot.rating - xw.low) / (xw.high - xw.low) : 1)
                                    readonly property real grow: Math.max(0, Math.min(1,
                                        chartReveal.value * 1.8 - 0.8 * barSlot.index / Math.max(1, bars.count)))
                                    width: bars.barWidth
                                    height: bars.height

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(3, parent.height * barSlot.level * barSlot.grow)
                                        radius: Math.min(width / 2, 4)
                                        color: barSlot.best ? xw.gold
                                            : barSlot.current ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, xw.hovered === barSlot.index ? 0.45 : 0.8)
                                        Behavior on color {
                                            ColorAnimation { duration: IslandMotion.micro }
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

                        Rectangle {
                            readonly property int currentIndex: xw.episodes.findIndex(e => Number(e.Episode) === (xw.now?.episode ?? -1))
                            visible: currentIndex >= 0
                            x: currentIndex * (bars.barWidth + bars.spacing) + bars.barWidth / 2 - width / 2
                            anchors.bottom: parent.bottom
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                RowLayout {
                    id: bigRating
                    Layout.fillWidth: true
                    visible: !xw.hasEpisode
                    spacing: 4
                    DiCascade { target: bigRating; index: 2 }

                    MaterialSymbol {
                        text: "star"
                        iconSize: 24
                        fill: 1
                        color: xw.gold
                    }
                    StyledText {
                        text: WatchRating.seriesRating >= 0 ? WatchRating.seriesRating.toFixed(1) : "–"
                        font.pixelSize: 40
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 8
                        text: [(xw.info?.imdbVotes ?? "N/A") !== "N/A" ? Translation.tr("%1 votes").arg(xw.info.imdbVotes) : "",
                            (xw.info?.totalSeasons ?? "N/A") !== "N/A" ? Translation.tr("%1 seasons").arg(xw.info.totalSeasons)
                                : (xw.info?.Runtime ?? "N/A") !== "N/A" ? xw.info.Runtime : ""].filter(Boolean).join(" · ")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    id: plot
                    Layout.fillWidth: true
                    visible: !xw.hasEpisode && (xw.info?.Plot ?? "N/A") !== "N/A"
                    text: xw.info?.Plot ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.8
                    wrapMode: Text.Wrap
                    maximumLineCount: (xw.now?.source ?? "") === "page" ? 3 : 5
                    elide: Text.ElideRight
                    DiCascade { target: plot; index: 3 }
                }

                Item {
                    id: scriptTip
                    Layout.fillWidth: true
                    visible: !xw.hasEpisode && (xw.now?.source ?? "") === "page"
                    implicitHeight: 32
                    DiCascade { target: scriptTip; index: 4 }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: tipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                        Behavior on color {
                            ColorAnimation { duration: IslandMotion.micro }
                        }
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 10
                            }
                            spacing: 8
                            MaterialSymbol {
                                text: "extension"
                                iconSize: 16
                                fill: 1
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Add the episode script for each episode's rating")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            MaterialSymbol {
                                text: "open_in_new"
                                iconSize: 14
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.5
                            }
                        }
                        MouseArea {
                            id: tipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(`file://${Quickshell.shellPath("scripts/island")}`)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: emptyView

        RowLayout {
            spacing: 18

            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 196
                Layout.maximumWidth: 196
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                MaterialSymbol {
                    id: heroIcon
                    Layout.alignment: Qt.AlignHCenter
                    text: xw.switchedOff ? "visibility_off" : xw.keyMissing ? "key_off"
                        : xw.seriesName !== "" ? (xw.lookupResult === false ? "search_off" : "travel_explore") : "live_tv"
                    iconSize: 30
                    fill: 1
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.35
                    DiCascade { target: heroIcon; index: 0 }
                }
                StyledText {
                    id: heroTitle
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    horizontalAlignment: Text.AlignHCenter
                    text: xw.switchedOff ? Translation.tr("IMDb ratings are off")
                        : xw.keyMissing ? Translation.tr("OMDb key missing")
                        : xw.seriesName !== "" ? (xw.lookupResult === false ? Translation.tr("Not found on IMDb") : Translation.tr("Looking it up on IMDb…"))
                        : Translation.tr("Nothing playing in the browser")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    wrapMode: Text.Wrap
                    DiCascade { target: heroTitle; index: 1 }
                }
                StyledText {
                    id: heroHint
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: xw.switchedOff ? Translation.tr("Turn on Watch ratings in the Dynamic Island settings")
                        : xw.keyMissing ? Translation.tr("Save a free OMDb key to see the rating of what you watch")
                        : xw.seriesName !== "" ? xw.seriesName
                        : Translation.tr("Play a series or film and its IMDb rating shows up here")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    DiCascade { target: heroHint; index: 2 }
                }

                Item {
                    id: services
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    implicitWidth: serviceRow.implicitWidth
                    implicitHeight: serviceRow.implicitHeight
                    DiCascade { target: services; index: 3 }

                    Row {
                        id: serviceRow
                        spacing: 10
                        opacity: 0.8
                        Repeater {
                            model: ["netflix", "disneyplus", "primevideo", "max", "crunchyroll"]
                            delegate: DiServiceMark {
                                required property string modelData
                                anchors.verticalCenter: parent.verticalCenter
                                service: modelData
                                size: 15
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 6

                SectionLabel {
                    id: setupLabel
                    text: Translation.tr("Setup")
                    DiCascade { target: setupLabel; index: 1 }
                }

                SetupRow {
                    order: 2
                    icon: "key"
                    label: Translation.tr("OMDb key")
                    hint: xw.keyMissing ? Translation.tr("Get a free one at omdbapi.com, save in %1").arg("~/.config/illogical-impulse/omdb.key")
                        : "~/.config/illogical-impulse/omdb.key"
                    ok: !xw.keyMissing
                    warn: xw.keyMissing
                    onTap: () => xw.keyMissing
                        ? Qt.openUrlExternally("https://www.omdbapi.com/apikey.aspx")
                        : Qt.openUrlExternally(`file://${Quickshell.env("HOME")}/.config/illogical-impulse`)
                }

                SetupRow {
                    order: 3
                    icon: "extension"
                    label: Translation.tr("Episode script (Tampermonkey)")
                    hint: (xw.now?.source ?? "") === "script" ? Translation.tr("Sending episodes from the browser")
                        : Translation.tr("scripts/island/watch-rating.user.js · Netflix and Disney+")
                    ok: (xw.now?.source ?? "") === "script"
                    onTap: () => Qt.openUrlExternally(`file://${Quickshell.shellPath("scripts/island")}`)
                }

                SectionLabel {
                    id: recentLabel
                    Layout.topMargin: 4
                    visible: xw.recent.length > 0
                    text: Translation.tr("Seen this session")
                    DiCascade { target: recentLabel; index: 4 }
                }

                Repeater {
                    model: xw.recent.length
                    delegate: Rectangle {
                        id: recentRow
                        required property int index
                        readonly property var d: xw.recent[recentRow.index] ?? null
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: recentMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                        Behavior on color {
                            ColorAnimation { duration: IslandMotion.micro }
                        }
                        DiCascade { target: recentRow; index: 5 + recentRow.index; pressed: recentMouse.pressed }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 6
                                rightMargin: 12
                            }
                            spacing: 10

                            Poster {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 30
                                corner: 5
                                title: recentRow.d
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: -2
                                StyledText {
                                    Layout.fillWidth: true
                                    text: recentRow.d?.Title ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: [recentRow.d?.Year, xw.genres(recentRow.d)].filter(Boolean).join(" · ")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            MaterialSymbol {
                                visible: WatchRating.ratingOf(recentRow.d) >= 0
                                text: "star"
                                iconSize: 15
                                fill: 1
                                color: xw.gold
                            }
                            StyledText {
                                visible: WatchRating.ratingOf(recentRow.d) >= 0
                                text: WatchRating.ratingOf(recentRow.d).toFixed(1)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        MouseArea {
                            id: recentMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (recentRow.d?.imdbID) Qt.openUrlExternally(`https://www.imdb.com/title/${recentRow.d.imdbID}/`)
                        }
                    }
                }
            }
        }
    }
}
