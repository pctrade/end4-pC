import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects

ColumnLayout {
    id: xf
    required property Item di
    spacing: 8
    implicitWidth: xf.wantedWidth
    readonly property real wantedWidth: F1.sessionLive ? 480 : 532

    readonly property color flagColor: F1.flagColor(F1.flag)
    readonly property string hourFormat: DateTime.use12HourFormat ? "h AP" : "HH:mm"

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property color seed: "#E10600"
    function tone(lightness, alpha) {
        const c = Qt.color(xf.seed)
        return Qt.hsla(c.hslHue, 0.55, lightness, alpha ?? 1)
    }
    readonly property color primary: xf.tone(xf.dark ? 0.80 : 0.40)
    readonly property color onPrimary: xf.tone(xf.dark ? 0.16 : 0.97)
    readonly property color container: xf.tone(xf.dark ? 0.22 : 0.88, 0.75)
    readonly property color onSurface: xf.tone(xf.dark ? 0.95 : 0.12)
    readonly property color onSurfaceVariant: xf.tone(xf.dark ? 0.76 : 0.34)
    readonly property color tint: F1.sessionLive ? "transparent" : xf.tone(xf.dark ? 0.11 : 0.94, 0.78)

    Component.onCompleted: {
        if (!F1.sessionLive) {
            F1.requestWeekend()
            F1.requestStandings()
            F1.requestCalendar()
        }
    }
    Connections {
        target: F1
        function onSessionLiveChanged() {
            if (!F1.sessionLive) {
                F1.requestWeekend()
                F1.requestStandings()
                F1.requestCalendar()
            }
        }
    }

    // The island keeps this instance across close/reopen, so browsing state is reset when the view opens.
    Connections {
        target: xf.di
        function onExpandedChanged() {
            if (xf.di.expanded) xf.viewIndex = -1
        }
    }

    // -1 follows the next race; the pager steps through the season.
    property int viewIndex: -1
    readonly property var calendar: F1.calendar
    readonly property int autoIndex: {
        for (let i = 0; i < xf.calendar.length; i++)
            if (Date.parse(xf.calendar[i].raceDate) >= xf.localNow) return i
        return Math.max(0, xf.calendar.length - 1)
    }
    readonly property int effectiveIndex: xf.viewIndex >= 0 ? Math.min(xf.viewIndex, xf.calendar.length - 1) : xf.autoIndex
    readonly property var race: xf.calendar[xf.effectiveIndex] ?? null
    readonly property bool browsing: xf.viewIndex >= 0 && xf.viewIndex !== xf.autoIndex
    readonly property bool racePast: xf.race !== null && Date.parse(xf.race.raceDate) < xf.localNow
    property real localNow: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: xf.visible && !F1.sessionLive
        triggeredOnStart: true
        onTriggered: xf.localNow = Date.now()
    }

    function browseBy(delta) {
        if (xf.calendar.length === 0) return
        const base = xf.viewIndex >= 0 ? xf.viewIndex : xf.autoIndex
        xf.viewIndex = Math.max(0, Math.min(xf.calendar.length - 1, base + delta))
    }
    function browseToNext() { xf.viewIndex = -1 }

    // Checked from `race` directly: `racePast` may not have updated yet when this fires.
    function fetchResultsIfPast() {
        if (xf.race && Date.parse(xf.race.raceDate) < Date.now()) F1.requestResults(xf.race.round)
    }
    onRaceChanged: xf.fetchResultsIfPast()
    Timer {
        interval: 2500
        repeat: true
        running: xf.visible && xf.racePast && xf.race !== null && !F1.resultsByRound[xf.race.round]
        onTriggered: xf.fetchResultsIfPast()
    }

    function formatLongCountdown(seconds) {
        if (seconds < 0) return ""
        const d = Math.floor(seconds / 86400)
        const h = Math.floor((seconds % 86400) / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        if (d > 0) return `${d}d ${h}h`
        if (h > 0) return `${h}h ${m}min`
        return F1.formatCountdown(seconds)
    }

    function weekendShortLabel(name) {
        const practice = (name ?? "").match(/^Practice (\d)$/)
        if (practice) return Translation.tr("FP%1").arg(practice[1])
        switch (name) {
            case "Race": return Translation.tr("Race")
            case "Qualifying": return Translation.tr("Quali")
            case "Sprint": return "Sprint"
            case "Sprint Qualifying":
            case "Sprint Shootout": return Translation.tr("Sprint quali")
            default: return name ?? ""
        }
    }

    // OpenF1 circuit_short_name -> layout in julesr0y/f1-circuits-svg. Unlisted tracks fall back to a guessed slug; the watermark hides on 404.
    readonly property var trackSlugs: ({
        sakhir: "bahrain-1", bahrain: "bahrain-1",
        melbourne: "melbourne-2",
        shanghai: "shanghai-1",
        suzuka: "suzuka-2",
        jeddah: "jeddah-1",
        miami: "miami-1", miamigardens: "miami-1",
        montreal: "montreal-6",
        monaco: "monaco-6", montecarlo: "monaco-6",
        barcelona: "catalunya-6", catalunya: "catalunya-6",
        spielberg: "spielberg-3",
        silverstone: "silverstone-8",
        spafrancorchamps: "spa-francorchamps-4", spa: "spa-francorchamps-4",
        budapest: "hungaroring-3", hungaroring: "hungaroring-3",
        zandvoort: "zandvoort-5",
        monza: "monza-7",
        baku: "baku-1",
        kualalumpur: "sepang-1", sepang: "sepang-1",
        marinabay: "marina-bay-4", singapore: "marina-bay-4",
        austin: "austin-1",
        mexicocity: "mexico-city-3", mexico: "mexico-city-3",
        saopaulo: "interlagos-2", interlagos: "interlagos-2",
        lasvegas: "las-vegas-1",
        lusail: "lusail-1", losail: "lusail-1",
        yasmarina: "yas-marina-2", abudhabi: "yas-marina-2"
    })

    function trackSvgUrl(name) {
        const key = (name ?? "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/g, "")
        if (!key) return ""
        const layout = xf.trackSlugs[key] ?? `${key}-1`
        return `https://raw.githubusercontent.com/julesr0y/f1-circuits-svg/main/circuits/minimal/white-outline/${layout}.svg`
    }

    component PagerButton: Rectangle {
        id: pb
        property string icon
        property bool enabledState: true
        signal clicked()
        implicitWidth: 32
        implicitHeight: 32
        radius: pbMouse.pressed ? 10 : 16
        color: pbMouse.containsMouse ? xf.tone(xf.dark ? 0.34 : 0.80, 0.9) : xf.container
        opacity: pb.enabledState ? 1 : 0.35
        Behavior on radius { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: IslandMotion.micro } }
        MaterialSymbol {
            anchors.centerIn: parent
            text: pb.icon
            iconSize: 20
            color: xf.onSurface
        }
        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: pb.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: F1.sessionLive

        Rectangle {
            implicitWidth: 34
            implicitHeight: 22
            radius: 6
            color: F1.sessionLive ? xf.flagColor : Appearance.colors.colLayer2

            Behavior on color {
                ColorAnimation { duration: IslandMotion.medium }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: F1.sessionLive ? "flag" : "sports_score"
                iconSize: 15
                fill: 1
                color: F1.sessionLive ? "#111111" : Appearance.colors.colOnLayer1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2

            StyledText {
                Layout.fillWidth: true
                text: F1.sessionLive ? (F1.session?.meeting ?? "") : (F1.nextSession?.meeting ?? "Formula 1")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: F1.sessionLive
                    ? `${F1.sessionLabel(F1.session?.name ?? "")} · ${F1.flagLabel(F1.flag)}${F1.mode === "replay" ? " · replay" : ""}`
                    : (F1.nextSession ? F1.sessionLabel(F1.nextSession.name) : Translation.tr("No upcoming session"))
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: F1.sessionLive
            text: F1.totalLaps > 0 ? `${Translation.tr("Lap")} ${F1.lap}/${F1.totalLaps}` : F1.remaining
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
        }
    }

    Item {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: grid.perColumn * grid.rowH
        visible: F1.sessionLive && driversModel.count > 0

        readonly property int perColumn: 5
        readonly property real rowH: 26
        readonly property real colGap: 10
        readonly property real colW: (grid.width - grid.colGap) / 2

        Repeater {
            model: ListModel { id: driversModel }

            delegate: Item {
                id: row
                required property string num
                required property int slot
                required property string tla
                required property string teamColor
                required property string gap
                required property string interval
                required property string best
                required property bool inPit
                required property bool retired
                required property string tyre

                readonly property bool shown: row.slot < grid.perColumn * 2
                readonly property int column: Math.min(1, Math.floor(row.slot / grid.perColumn))
                readonly property int line: row.shown ? row.slot % grid.perColumn : grid.perColumn - 1
                property int lastSlot: row.slot
                property int trend: 0
                property real lift: 0

                width: grid.colW
                height: grid.rowH - 3
                x: row.column * (grid.colW + grid.colGap)
                y: row.line * grid.rowH + (row.shown ? 0 : grid.rowH)
                z: row.trend > 0 ? 10 : (row.trend < 0 ? 5 : 1)
                opacity: row.shown ? 1 : 0
                scale: 1

                Behavior on x {
                    NumberAnimation { duration: 760; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                }
                Behavior on y {
                    NumberAnimation { duration: 760; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                }
                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.medium }
                }

                onSlotChanged: {
                    if (row.slot === row.lastSlot) return
                    row.trend = row.slot < row.lastSlot ? 1 : -1
                    row.lastSlot = row.slot
                    trendTimer.restart()
                }

                SequentialAnimation {
                    id: liftAnim
                    NumberAnimation { target: row; property: "lift"; to: 1; duration: IslandMotion.short; easing.type: Easing.OutCubic }
                    PauseAnimation { duration: 320 }
                    NumberAnimation { target: row; property: "lift"; to: 0; duration: IslandMotion.long; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }

                Timer {
                    id: trendTimer
                    interval: 4500
                    onTriggered: row.trend = 0
                }

                StyledRectangularShadow {
                    target: rowBackground
                    opacity: row.lift
                    visible: row.lift > 0.01
                }

                Rectangle {
                    id: rowBackground
                    anchors.fill: parent
                    radius: 9
                    color: row.trend > 0 ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.m3colors.m3success, 0.72)
                        : row.trend < 0 ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colError, 0.82)
                        : row.tla === F1.favoriteDriver ? ColorUtils.mix(Appearance.colors.colLayer1, row.teamColor, 0.75)
                        : Appearance.colors.colLayer1
                    border.width: row.tla === F1.favoriteDriver ? 1 : 0
                    border.color: row.teamColor

                    Behavior on color {
                        ColorAnimation { duration: 600 }
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 6

                    StyledText {
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignRight
                        text: row.slot + 1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                    }

                    Item {
                        implicitWidth: 12
                        implicitHeight: 16

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: row.trend !== 0
                            text: row.trend > 0 ? "arrow_drop_up" : "arrow_drop_down"
                            iconSize: 20
                            fill: 1
                            color: row.trend > 0 ? Appearance.m3colors.m3success : Appearance.colors.colError
                            onVisibleChanged: if (visible) arrowIn.restart()

                            NumberAnimation on scale {
                                id: arrowIn
                                running: false
                                from: 0.2
                                to: 1
                                duration: IslandMotion.medium
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 4
                        implicitHeight: 16
                        radius: 2
                        color: row.teamColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.tla
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: row.tyre !== ""
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: "#1B1B1B"
                        border.width: 2
                        border.color: F1.tyreColor(row.tyre)

                        Behavior on border.color {
                            ColorAnimation { duration: IslandMotion.long }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: F1.tyreLetter(row.tyre)
                            font.pixelSize: 7
                            font.weight: Font.Black
                            color: F1.tyreColor(row.tyre)
                        }
                    }

                    Rectangle {
                        visible: row.inPit || row.retired
                        implicitWidth: pitText.implicitWidth + 8
                        implicitHeight: 15
                        radius: 4
                        color: row.retired ? Appearance.colors.colError : Appearance.colors.colSecondaryContainer
                        StyledText {
                            id: pitText
                            anchors.centerIn: parent
                            text: row.retired ? "OUT" : Translation.tr("PIT")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Bold
                            color: row.retired ? Appearance.colors.colOnError : Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    StyledText {
                        text: F1.isRace ? (row.slot === 0 ? (F1.totalLaps > 0 ? `L${F1.lap}` : "") : (row.interval || row.gap)) : row.best
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.8
                    }
                }

                Row {
                    id: streaks
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 26
                        rightMargin: 26
                    }
                    spacing: (row.width - 52) / 5
                    opacity: 0
                    layoutDirection: row.trend < 0 ? Qt.RightToLeft : Qt.LeftToRight

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 14 - index * 2
                            height: 2
                            radius: 1
                            color: row.trend > 0 ? Appearance.m3colors.m3success : Appearance.colors.colError
                            opacity: 0.85 - index * 0.18
                        }
                    }

                    SequentialAnimation {
                        id: streakAnim
                        ParallelAnimation {
                            NumberAnimation { target: streaks; property: "opacity"; from: 0; to: 1; duration: 90 }
                            NumberAnimation {
                                target: streaks; property: "x"; from: row.trend < 0 ? 20 : -20; to: 0
                                duration: 260; easing.type: Easing.OutCubic
                            }
                        }
                        PauseAnimation { duration: 90 }
                        NumberAnimation { target: streaks; property: "opacity"; to: 0; duration: 220 }
                    }
                }

                onTrendChanged: if (row.trend !== 0) streakAnim.restart()
            }
        }

        function sync() {
            const top = F1.drivers.slice(0, 12)
            const keep = new Set(top.map(d => d.num))
            for (let k = driversModel.count - 1; k >= 0; k--) {
                if (!keep.has(driversModel.get(k).num)) driversModel.remove(k)
            }
            top.forEach((d, i) => {
                const entry = {
                    num: d.num, slot: i, tla: d.tla, teamColor: d.color,
                    gap: d.gap ?? "", interval: d.interval ?? "", best: d.best ?? "",
                    inPit: d.inPit ?? false, retired: d.retired ?? false, tyre: d.tyre ?? ""
                }
                let found = -1
                for (let k = 0; k < driversModel.count; k++) {
                    if (driversModel.get(k).num === d.num) {
                        found = k
                        break
                    }
                }
                if (found === -1) driversModel.append(entry)
                else driversModel.set(found, entry)
            })
        }

        Component.onCompleted: grid.sync()

        Connections {
            target: F1
            function onDriversChanged() { grid.sync() }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: F1.sessionLive && (F1.weather?.air ?? "") !== ""
        spacing: 14

        Repeater {
            model: [
                { icon: "thermostat", text: `${Translation.tr("Air")} ${F1.weather?.air ?? ""}°` },
                { icon: "add_road", text: `${Translation.tr("Track")} ${F1.weather?.track ?? ""}°` },
                { icon: (F1.weather?.rain ?? false) ? "rainy" : "water_drop", text: (F1.weather?.rain ?? false) ? Translation.tr("Raining") : `${F1.weather?.humidity ?? ""}%` }
            ]
            delegate: RowLayout {
                required property var modelData
                spacing: 3

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 14
                    fill: 1
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: modelData.text
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.8
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: F1.sessionLive && F1.raceControl !== null
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            text: "campaign"
            iconSize: 16
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: F1.raceControl?.message ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.85
            wrapMode: Text.Wrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        id: offSession
        Layout.fillWidth: true
        visible: !F1.sessionLive
        spacing: 10

        RowLayout {
            id: pager
            Layout.fillWidth: true
            spacing: 8
            DiCascade { target: pager; index: 0 }


            PagerButton {
                icon: "chevron_left"
                enabledState: xf.effectiveIndex > 0
                onClicked: xf.browseBy(-1)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: xf.race ? `${Translation.tr("Round %1").arg(xf.race.round)} · ${xf.race.circuit}` : Translation.tr("Loading schedule…")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: xf.primary
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: xf.race?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: xf.onSurface
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: xf.browsing
                implicitWidth: backRow.implicitWidth + 16
                implicitHeight: 32
                radius: 16
                color: xf.primary
                RowLayout {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 3
                    MaterialSymbol {
                        text: "fast_forward"
                        iconSize: 15
                        fill: 1
                        color: xf.onPrimary
                    }
                    StyledText {
                        text: Translation.tr("Next")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        color: xf.onPrimary
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xf.browseToNext()
                }
            }

            PagerButton {
                icon: "chevron_right"
                enabledState: xf.effectiveIndex < xf.calendar.length - 1
                onClicked: xf.browseBy(1)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                id: leftCol
                Layout.fillWidth: false
                Layout.preferredWidth: 254
                Layout.maximumWidth: 254
                Layout.alignment: Qt.AlignTop
                spacing: 10

                readonly property var upcomingSessions: xf.race ? xf.race.sessions.filter(s => Date.parse(s.start) > xf.localNow) : []
                readonly property var results: xf.race ? (F1.resultsByRound[xf.race.round] ?? null) : null

                Rectangle {
                    id: hero
                    Layout.fillWidth: true
                    implicitHeight: 104
                    radius: 24
                    color: xf.container
                    clip: true
                    DiCascade { target: hero; index: 1 }

                    Image {
                        id: trackImage
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        width: 84
                        height: 84
                        source: xf.trackSvgUrl(xf.race?.circuit ?? "")
                        visible: false
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 168
                        sourceSize.height: 168
                    }
                    ColorOverlay {
                        anchors.fill: trackImage
                        source: trackImage
                        color: xf.primary
                        opacity: trackImage.status === Image.Ready ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: IslandMotion.long } }
                    }
                    MaterialSymbol {
                        anchors.centerIn: trackImage
                        visible: trackImage.status !== Image.Ready
                        text: "sports_score"
                        iconSize: 36
                        color: xf.onSurfaceVariant
                        opacity: 0.4
                    }

                    ColumnLayout {
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            right: trackImage.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: xf.racePast ? Translation.tr("Winner")
                                : (leftCol.upcomingSessions.length > 0 ? Translation.tr("until %1").arg(xf.weekendShortLabel(leftCol.upcomingSessions[0].name)) : "")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: xf.onSurfaceVariant
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: xf.racePast
                                ? (leftCol.results === null ? "…" : (leftCol.results[0]?.code ?? "–"))
                                : (leftCol.upcomingSessions.length > 0
                                    ? xf.formatLongCountdown(Math.round((Date.parse(leftCol.upcomingSessions[0].start) - xf.localNow) / 1000)) : "–")
                            font.pixelSize: 38
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: xf.primary
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: xf.racePast
                                ? `${leftCol.results?.[0]?.team ?? ""} · ${Qt.locale().toString(new Date(xf.race?.raceDate ?? Date.now()), "dd/MM")}`
                                : (leftCol.upcomingSessions.length > 0 ? Qt.locale().toString(new Date(leftCol.upcomingSessions[0].start), "ddd, dd/MM · " + xf.hourFormat) : "")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: xf.onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                ColumnLayout {
                    id: champ
                    Layout.fillWidth: true
                    spacing: 5
                    visible: F1.standings.length > 0
                    DiCascade { target: champ; index: 2 }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Championship")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: xf.onSurfaceVariant
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: F1.standings.length > 1
                                ? Translation.tr("%1 leads by %2 pts").arg(F1.standings[0].code).arg(Math.max(0, F1.standings[0].points - F1.standings[1].points))
                                : (F1.standings.length > 0 ? Translation.tr("%1 leads").arg(F1.standings[0].code) : "")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: xf.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: F1.standings

                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 36
                                radius: chip.index === 0 ? 18 : 12
                                color: chip.index === 0 ? xf.primary : xf.container

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: -2
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: chip.modelData.code
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: Font.DemiBold
                                        color: chip.index === 0 ? xf.onPrimary : xf.onSurface
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: chip.modelData.points
                                        font.pixelSize: 9
                                        font.features: { "tnum": 1 }
                                        color: chip.index === 0 ? xf.onPrimary : xf.onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: listCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 24
                color: xf.container
                DiCascade { target: listCard; index: 3 }

                readonly property var rows: xf.racePast ? (leftCol.results ?? []) : (xf.race?.sessions ?? [])

                StyledText {
                    id: listTitle
                    anchors {
                        left: parent.left
                        top: parent.top
                        leftMargin: 14
                        topMargin: 10
                    }
                    text: xf.racePast ? Translation.tr("Classification") : Translation.tr("Weekend")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: xf.onSurfaceVariant
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: listCard.rows.length === 0
                    text: xf.racePast ? Translation.tr("Loading results…") : Translation.tr("Loading schedule…")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: xf.onSurfaceVariant
                }

                ListView {
                    id: list
                    anchors {
                        fill: parent
                        topMargin: 28
                        leftMargin: 6
                        rightMargin: 6
                        bottomMargin: 6
                    }
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: listCard.rows

                    delegate: Rectangle {
                        id: listRow
                        required property var modelData
                        required property int index
                        readonly property bool isNext: !xf.racePast && listRow.modelData.start === (leftCol.upcomingSessions[0]?.start ?? "")
                        readonly property bool isPast: !xf.racePast && Date.parse(listRow.modelData.start) < xf.localNow
                        readonly property bool highlight: xf.racePast ? (listRow.modelData.winner ?? false) : listRow.isNext
                        width: list.width
                        height: 24
                        radius: 12
                        color: listRow.highlight ? xf.primary : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 6

                            MaterialSymbol {
                                visible: !xf.racePast
                                text: listRow.isPast ? "check" : (listRow.isNext ? "timer" : "schedule")
                                iconSize: 14
                                color: listRow.highlight ? xf.onPrimary : xf.onSurfaceVariant
                                opacity: listRow.isPast ? 0.5 : 1
                            }
                            StyledText {
                                visible: !xf.racePast
                                Layout.preferredWidth: 40
                                text: xf.weekendShortLabel(listRow.modelData.name)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: listRow.highlight ? Font.DemiBold : Font.Medium
                                color: listRow.highlight ? xf.onPrimary : xf.onSurface
                                opacity: listRow.isPast ? 0.5 : 1
                            }
                            StyledText {
                                visible: !xf.racePast
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: listRow.modelData.start ? Qt.locale().toString(new Date(listRow.modelData.start), "ddd · " + xf.hourFormat) : ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: listRow.highlight ? xf.onPrimary : xf.onSurfaceVariant
                                opacity: listRow.isPast ? 0.5 : 1
                            }

                            StyledText {
                                visible: xf.racePast
                                Layout.preferredWidth: 22
                                text: `${listRow.modelData.pos ?? ""}`
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: listRow.highlight ? xf.onPrimary : xf.onSurfaceVariant
                            }
                            StyledText {
                                visible: xf.racePast
                                Layout.preferredWidth: 34
                                text: listRow.modelData.code ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                color: listRow.highlight ? xf.onPrimary : xf.onSurface
                            }
                            StyledText {
                                visible: xf.racePast
                                Layout.fillWidth: true
                                text: listRow.modelData.team ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: listRow.highlight ? xf.onPrimary : xf.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                            StyledText {
                                visible: xf.racePast
                                text: `${listRow.modelData.points ?? ""} ${Translation.tr("pts")}`
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: listRow.highlight ? xf.onPrimary : xf.onSurfaceVariant
                            }
                        }
                    }

                    Rectangle {
                        visible: list.contentHeight > list.height
                        anchors.right: parent.right
                        width: 3
                        radius: 1.5
                        color: xf.onSurfaceVariant
                        opacity: 0.4
                        height: Math.max(16, list.height * list.height / Math.max(1, list.contentHeight))
                        y: list.contentY / Math.max(1, list.contentHeight - list.height) * (list.height - height)
                    }
                }
            }
        }
    }
}
