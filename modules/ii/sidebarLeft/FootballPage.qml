import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    readonly property var fb: Config.options.sidebar.football
    readonly property var markets: ({
        result: root.fb.markets.indexOf("result") >= 0,
        goals: root.fb.markets.indexOf("goals") >= 0,
        corners: root.fb.markets.indexOf("corners") >= 0
    })
    readonly property var marketOptions: [
        { id: "result", icon: "emoji_events", label: Translation.tr("Result") },
        { id: "goals", icon: "sports_soccer", label: Translation.tr("Goals") },
        { id: "corners", icon: "flag", label: Translation.tr("Corners") }
    ]
    readonly property string todayKey: Football.dayKey(new Date())
    readonly property var days: Football.days
    property string selectedKey: ""
    property string leagueFilter: ""
    property var detailMatch: null
    property bool detailScrolled: false
    property var scrollTarget: null

    readonly property var detailGroups: root.detailMatch ? (Football.standingsByLeague[root.detailMatch.league.id] ?? null) : null
    readonly property color homeRowColor: ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1Base, 0.5)
    readonly property color awayRowColor: ColorUtils.mix(Appearance.colors.colTertiary, Appearance.colors.colLayer1Base, 0.5)

    readonly property var firstOpenDay: root.days.find(day => day.matches.some(match => match.state !== "post")) ?? root.days[0] ?? null
    readonly property var activeDay: root.days.find(day => day.key === root.selectedKey) ?? root.firstOpenDay
    readonly property bool hasToday: root.days.some(day => day.key === root.todayKey)
    readonly property bool todayOpen: root.days.some(day => day.key === root.todayKey && day.matches.some(match => match.state !== "post"))
    readonly property var dayMatches: root.activeDay ? root.activeDay.matches : []
    readonly property var dayLeagues: {
        const map = {};
        root.dayMatches.forEach(match => {
            if (!map[match.league.id]) map[match.league.id] = { id: match.league.id, name: match.league.name, count: 0 };
            map[match.league.id].count++;
        });
        return Object.values(map);
    }
    readonly property var visibleMatches: root.leagueFilter === "" ? root.dayMatches : root.dayMatches.filter(match => match.league.id === root.leagueFilter)
    readonly property var groups: {
        const map = {};
        const order = [];
        root.visibleMatches.forEach(match => {
            if (!map[match.league.id]) {
                map[match.league.id] = { league: match.league, matches: [] };
                order.push(match.league.id);
            }
            map[match.league.id].matches.push(match);
        });
        return order.map(id => map[id]);
    }
    readonly property int eligibleCount: root.visibleMatches.filter(match => match.state === "pre" && match.probs).length
    readonly property var legOptions: [3, 4, 5, 6, 7].filter(count => count <= root.eligibleCount)
    readonly property int activeLegs: root.legOptions.length === 0 ? 0 : Math.min(root.fb.legs, root.legOptions[root.legOptions.length - 1])
    readonly property var parlay: Football.buildParlay(root.visibleMatches, root.activeLegs > 0 ? root.activeLegs : root.fb.legs, root.markets)

    function dayLabel(day) {
        if (day.key === root.todayKey) return Translation.tr("Today");
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        if (day.key === Football.dayKey(tomorrow)) return Translation.tr("Tomorrow");
        return Qt.locale().toString(day.date, "ddd d MMM");
    }

    function longDayLabel(day) {
        return Qt.locale().toString(day.date, "dddd d MMMM");
    }

    function timeLabel(match) {
        return Qt.locale().toString(new Date(match.date), "HH:mm");
    }

    function percent(value) {
        return Math.round(value * 100) + "%";
    }

    function lineOf(pick) {
        return ({ o15: "1.5", o25: "2.5", c85: "8.5", c95: "9.5", c105: "10.5" })[pick] ?? "";
    }

    function toggleMarket(id) {
        const current = Array.from(root.fb.markets);
        const index = current.indexOf(id);
        if (index >= 0) {
            if (current.length === 1) return;
            current.splice(index, 1);
        } else {
            current.push(id);
        }
        root.fb.markets = current;
    }

    function marketColor(type) {
        if (type === "result") return { bg: Appearance.colors.colTertiary, fg: Appearance.colors.colOnTertiary };
        if (type === "corners") return { bg: Appearance.colors.colSecondary, fg: Appearance.colors.colOnSecondary };
        return { bg: Appearance.colors.colPrimary, fg: Appearance.colors.colOnPrimary };
    }

    function posText(position) {
        return position > 0 ? "#" + position + " · " : "";
    }

    function openMatch(match) {
        root.detailScrolled = false;
        root.scrollTarget = null;
        root.detailMatch = match;
        Football.loadStandings(match.league.id);
        Football.loadForm(match.league.id, [match.home.id, match.away.id]);
    }

    function closeMatch() {
        root.detailMatch = null;
    }

    function marketIcon(type) {
        return type === "result" ? "emoji_events" : type === "goals" ? "sports_soccer" : "flag";
    }

    function legTitle(leg) {
        if (leg.type === "result") {
            if (leg.pick === "draw") return Translation.tr("Draw");
            const team = leg.pick === "home" ? leg.match.home.name : leg.match.away.name;
            return Translation.tr("%1 to win").arg(team);
        }
        if (leg.type === "goals") return Translation.tr("Over %1 goals").arg(root.lineOf(leg.pick));
        return Translation.tr("Over %1 corners").arg(root.lineOf(leg.pick));
    }

    function updatedText() {
        if (Football.loading) return Translation.tr("Updating…");
        if (Football.generatedAt <= 0) return "";
        const minutes = Math.max(0, Math.round((Date.now() - Football.generatedAt) / 60000));
        if (minutes < 1) return Translation.tr("Updated just now");
        if (minutes < 60) return Translation.tr("Updated %1 min ago").arg(minutes);
        return Translation.tr("Updated %1 h ago").arg(Math.round(minutes / 60));
    }

    Component.onCompleted: Football.ensureFresh()
    onVisibleChanged: if (visible) Football.ensureFresh()
    onActiveDayChanged: if (root.leagueFilter !== "" && !root.dayLeagues.some(league => league.id === root.leagueFilter)) root.leagueFilter = ""

    component FilterChip: RippleButton {
        id: chip
        property string label: ""
        property string symbol: ""
        property string badge: ""

        implicitHeight: 36
        horizontalPadding: 14
        buttonRadius: 11
        border: !toggled
        colBorder: Appearance.colors.colOutlineVariant
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colLayer2Active
        colRippleToggled: Appearance.colors.colSecondaryContainerActive

        contentItem: RowLayout {
            spacing: 6

            MaterialSymbol {
                visible: chip.symbol !== ""
                text: chip.toggled && chip.symbol === "" ? "check" : chip.symbol
                iconSize: 18
                fill: chip.toggled ? 1 : 0
                color: chip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: chip.toggled ? Font.Medium : Font.Normal
                color: chip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }
            Rectangle {
                visible: chip.badge !== ""
                implicitWidth: Math.max(20, badgeText.implicitWidth + 10)
                implicitHeight: 20
                radius: 10
                color: chip.toggled ? Appearance.colors.colSecondary : Appearance.colors.colLayer3
                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: chip.badge
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: chip.toggled ? Appearance.colors.colOnSecondary : Appearance.colors.colOnLayer1
                }
            }
        }
    }

    component TeamBadge: Item {
        id: badge
        property var team: ({})
        property bool favorite: false
        implicitWidth: 48
        implicitHeight: 48

        MaterialShape {
            anchors.fill: parent
            shape: MaterialShape.Shape.Cookie9Sided
            implicitSize: badge.implicitWidth
            color: badge.favorite ? ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer2, 0.55) : Appearance.colors.colSecondaryContainer

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: logo.status !== Image.Ready
            text: (badge.team.abbr ?? "?").substring(0, 3)
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
            color: badge.favorite ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        }
        Image {
            id: logo
            anchors.fill: parent
            anchors.margins: 9
            source: badge.team.logo ?? ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            antialiasing: true
            sourceSize: Qt.size(256, 256)
        }
    }

    component ProbChip: Rectangle {
        id: pchip
        property string caption: ""
        property real value: 0
        readonly property bool strong: value >= 0.7
        readonly property bool medium: value >= 0.5 && value < 0.7

        Layout.fillWidth: true
        implicitHeight: 46
        radius: 13
        color: strong ? Appearance.colors.colPrimary : medium ? Appearance.colors.colSecondaryContainer : "transparent"
        border.width: (strong || medium) ? 0 : 1
        border.color: Appearance.colors.colOutlineVariant

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -1

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: pchip.caption
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: pchip.strong ? Appearance.colors.colOnPrimary : pchip.medium ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.percent(pchip.value)
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: pchip.strong ? Appearance.colors.colOnPrimary : pchip.medium ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }
        }
    }

    StyledFlickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 24
        clip: true

        ColumnLayout {
            id: content
            x: 12
            y: 12
            width: flick.width - 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Cookie9Sided
                    text: "sports_soccer"
                    iconSize: 24
                    fill: 1
                    padding: 10
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colOnPrimaryContainer
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: Translation.tr("Football")
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.family: Appearance.font.family.title
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        visible: text !== ""
                        text: root.updatedText()
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitWidth: 44
                    implicitHeight: 44
                    buttonRadius: 22
                    enabled: !Football.loading
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    downAction: () => Football.refresh()
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "refresh"
                        iconSize: 22
                        color: Appearance.colors.colOnSecondaryContainer
                        RotationAnimation on rotation {
                            running: Football.loading
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1100
                        }
                    }
                }
            }

            Item {
                visible: Football.matches.length === 0
                Layout.fillWidth: true
                implicitHeight: 220

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    MaterialLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        visible: Football.loading
                        loading: Football.loading
                    }
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !Football.loading
                        text: Football.failed ? "cloud_off" : "event_busy"
                        iconSize: 44
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Football.loading ? Translation.tr("Loading matches…") : Football.failed ? Translation.tr("Could not load matches") : Translation.tr("No matches in the next days")
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Rectangle {
                visible: Football.matches.length > 0 && !root.todayOpen && root.activeDay !== null && root.activeDay.key !== root.todayKey
                Layout.fillWidth: true
                implicitHeight: noToday.implicitHeight + 28
                radius: Appearance.rounding.normal
                color: Appearance.colors.colTertiaryContainer

                RowLayout {
                    id: noToday
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    MaterialSymbol {
                        text: "event_busy"
                        iconSize: 28
                        fill: 1
                        color: Appearance.colors.colOnTertiaryContainer
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.hasToday ? Translation.tr("No more matches today") : Translation.tr("No matches from your leagues today")
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnTertiaryContainer
                            wrapMode: Text.WordWrap
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.activeDay ? Translation.tr("Next matches: %1").arg(root.longDayLabel(root.activeDay)) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnTertiaryContainer
                            opacity: 0.8
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Flickable {
                visible: root.days.length > 0
                Layout.fillWidth: true
                implicitHeight: 38
                contentWidth: dayRow.implicitWidth
                contentHeight: 38
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: dayRow
                    spacing: 8

                    Repeater {
                        model: root.days

                        delegate: FilterChip {
                            required property var modelData
                            label: root.dayLabel(modelData)
                            badge: String(modelData.matches.length)
                            toggled: root.activeDay !== null && root.activeDay.key === modelData.key
                            downAction: () => { root.selectedKey = modelData.key; }
                        }
                    }
                }
            }

            Flickable {
                visible: root.dayLeagues.length > 1
                Layout.fillWidth: true
                implicitHeight: 38
                contentWidth: leagueRow.implicitWidth
                contentHeight: 38
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: leagueRow
                    spacing: 8

                    FilterChip {
                        label: Translation.tr("All")
                        toggled: root.leagueFilter === ""
                        downAction: () => { root.leagueFilter = ""; }
                    }
                    Repeater {
                        model: root.dayLeagues

                        delegate: FilterChip {
                            required property var modelData
                            label: modelData.name
                            badge: String(modelData.count)
                            toggled: root.leagueFilter === modelData.id
                            downAction: () => { root.leagueFilter = root.leagueFilter === modelData.id ? "" : modelData.id; }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.activeDay !== null
                Layout.fillWidth: true
                implicitHeight: parlayColumn.implicitHeight + 32
                radius: Appearance.rounding.large
                color: Appearance.colors.colPrimaryContainer

                ColumnLayout {
                    id: parlayColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: "layers"
                            iconSize: 26
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        ColumnLayout {
                            spacing: 0

                            StyledText {
                                text: Translation.tr("Parlay of the day")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: root.activeDay ? root.longDayLabel(root.activeDay) : ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.75
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            visible: root.legOptions.length > 0
                            spacing: 3

                            Repeater {
                                model: root.legOptions

                                delegate: RippleButton {
                                    required property int modelData
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    buttonRadius: root.activeLegs === modelData ? 17 : 10
                                    toggled: root.activeLegs === modelData
                                    colBackground: Qt.rgba(1, 1, 1, 0.1)
                                    colBackgroundHover: Qt.rgba(1, 1, 1, 0.18)
                                    colBackgroundToggled: Appearance.colors.colPrimary
                                    colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                    colRipple: Qt.rgba(1, 1, 1, 0.25)
                                    colRippleToggled: Appearance.colors.colPrimaryActive
                                    downAction: () => { root.fb.legs = modelData; }
                                    contentItem: StyledText {
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: String(modelData)
                                        font.weight: Font.Medium
                                        color: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                                    }
                                    Behavior on buttonRadius {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.marketOptions

                            delegate: RippleButton {
                                id: marketButton
                                required property var modelData
                                readonly property bool selected: root.fb.markets.indexOf(modelData.id) >= 0

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 42
                                buttonRadius: selected ? 21 : 12
                                toggled: selected
                                colBackground: Qt.rgba(1, 1, 1, 0.1)
                                colBackgroundHover: Qt.rgba(1, 1, 1, 0.18)
                                colBackgroundToggled: root.marketColor(modelData.id).bg
                                colBackgroundToggledHover: root.marketColor(modelData.id).bg
                                colRipple: Qt.rgba(1, 1, 1, 0.25)
                                colRippleToggled: root.marketColor(modelData.id).bg
                                downAction: () => root.toggleMarket(modelData.id)

                                contentItem: RowLayout {
                                    spacing: 6

                                    Item { Layout.fillWidth: true }
                                    MaterialSymbol {
                                        text: marketButton.modelData.icon
                                        iconSize: 18
                                        fill: marketButton.selected ? 1 : 0
                                        color: marketButton.selected ? root.marketColor(marketButton.modelData.id).fg : Appearance.colors.colOnPrimaryContainer
                                    }
                                    StyledText {
                                        text: marketButton.modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: marketButton.selected ? Font.Medium : Font.Normal
                                        color: marketButton.selected ? root.marketColor(marketButton.modelData.id).fg : Appearance.colors.colOnPrimaryContainer
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Behavior on buttonRadius {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: root.parlay.legs.length === 0
                        Layout.fillWidth: true
                        text: Translation.tr("No upcoming matches to build a parlay")
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                        wrapMode: Text.WordWrap
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.parlay.legs

                            delegate: Rectangle {
                                id: legRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: legLayout.implicitHeight + 20
                                radius: Appearance.rounding.small
                                color: Qt.rgba(1, 1, 1, 0.1)

                                RowLayout {
                                    id: legLayout
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Rectangle {
                                        implicitWidth: 34
                                        implicitHeight: 34
                                        radius: legRow.modelData.type === "result" ? 10 : legRow.modelData.type === "corners" ? 12 : 17
                                        color: root.marketColor(legRow.modelData.type).bg

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: root.marketIcon(legRow.modelData.type)
                                            iconSize: 18
                                            fill: 1
                                            color: root.marketColor(legRow.modelData.type).fg
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.legTitle(legRow.modelData)
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnPrimaryContainer
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: `${legRow.modelData.match.home.name} – ${legRow.modelData.match.away.name} · ${root.timeLabel(legRow.modelData.match)}`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnPrimaryContainer
                                            opacity: 0.7
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: 54
                                        implicitHeight: 30
                                        radius: 15
                                        color: root.marketColor(legRow.modelData.type).bg

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: root.percent(legRow.modelData.prob)
                                            font.weight: Font.DemiBold
                                            color: root.marketColor(legRow.modelData.type).fg
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.parlay.legs.length > 0
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.15
                    }

                    RowLayout {
                        visible: root.parlay.legs.length > 0
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            StyledText {
                                text: root.percent(root.parlay.combined)
                                font.pixelSize: 36
                                font.family: Appearance.font.family.title
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: Translation.tr("Combined probability")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.75
                            }
                        }

                        Rectangle {
                            implicitWidth: oddsColumn.implicitWidth + 28
                            implicitHeight: oddsColumn.implicitHeight + 16
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colTertiaryContainer

                            ColumnLayout {
                                id: oddsColumn
                                anchors.centerIn: parent
                                spacing: -2

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.parlay.odds.toFixed(2)
                                    font.pixelSize: Appearance.font.pixelSize.huge
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnTertiaryContainer
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Translation.tr("Fair odds")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnTertiaryContainer
                                    opacity: 0.75
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Statistical estimate only. No guarantee: betting involves risk.")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Repeater {
                model: root.groups

                delegate: ColumnLayout {
                    id: group
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: group.modelData.league.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: String(group.modelData.matches.length)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Repeater {
                        model: group.modelData.matches

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property var match: modelData
                            readonly property var probs: modelData.state === "post" ? null : (modelData.probs ?? null)
                            readonly property string favoriteSide: modelData.probs ? (modelData.probs.home > modelData.probs.away ? "home" : modelData.probs.away > modelData.probs.home ? "away" : "") : ""

                            Layout.fillWidth: true
                            implicitHeight: cardColumn.implicitHeight + 28
                            radius: Appearance.rounding.normal
                            color: cardHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            HoverHandler {
                                id: cardHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: root.openMatch(card.match)
                            }

                            ColumnLayout {
                                id: cardColumn
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: kickoff.implicitWidth + 20
                                        implicitHeight: 26
                                        radius: 13
                                        color: card.match.state === "in" ? Appearance.colors.colTertiary : Appearance.colors.colSecondaryContainer

                                        StyledText {
                                            id: kickoff
                                            anchors.centerIn: parent
                                            text: card.match.state === "pre" ? root.timeLabel(card.match) : card.match.state === "in" ? Translation.tr("Live") + " · " + card.match.detail : Translation.tr("Final")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: card.match.state === "in" ? Appearance.colors.colOnTertiary : Appearance.colors.colOnSecondaryContainer
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialSymbol {
                                        text: "leaderboard"
                                        iconSize: 20
                                        color: Appearance.colors.colSubtext
                                    }

                                    Rectangle {
                                        visible: card.match.lowData
                                        implicitWidth: lowRow.implicitWidth + 16
                                        implicitHeight: 26
                                        radius: 13
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Appearance.colors.colOutlineVariant

                                        RowLayout {
                                            id: lowRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MaterialSymbol {
                                                text: "info"
                                                iconSize: 14
                                                color: Appearance.colors.colSubtext
                                            }
                                            StyledText {
                                                text: Translation.tr("Few data")
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: Appearance.colors.colSubtext
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 10

                                        TeamBadge { team: card.match.home; favorite: card.favoriteSide === "home" }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: card.match.home.name
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer2
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    StyledText {
                                        text: card.match.state === "pre" ? "vs" : `${card.match.home.score ?? "-"} – ${card.match.away.score ?? "-"}`
                                        font.pixelSize: card.match.state === "pre" ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.larger
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colSubtext
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 10

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: card.match.away.name
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer2
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                        }
                                        TeamBadge { team: card.match.away; favorite: card.favoriteSide === "away" }
                                    }
                                }

                                RowLayout {
                                    visible: card.probs !== null
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: Math.max(0.12, card.probs ? card.probs.home : 0.33) * 100
                                        implicitHeight: 28
                                        topLeftRadius: 14
                                        bottomLeftRadius: 14
                                        topRightRadius: 4
                                        bottomRightRadius: 4
                                        color: Appearance.colors.colPrimary

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: card.probs ? root.posText(Football.positionOf(card.match.league.id, card.match.home.id)) + root.percent(card.probs.home) : ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnPrimary
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: Math.max(0.12, card.probs ? card.probs.draw : 0.33) * 100
                                        implicitHeight: 28
                                        radius: 4
                                        color: Appearance.colors.colSurfaceContainerHighest

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: card.probs ? "X · " + root.percent(card.probs.draw) : ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer2
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: Math.max(0.12, card.probs ? card.probs.away : 0.33) * 100
                                        implicitHeight: 28
                                        topRightRadius: 14
                                        bottomRightRadius: 14
                                        topLeftRadius: 4
                                        bottomLeftRadius: 4
                                        color: Appearance.colors.colTertiary

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: card.probs ? root.posText(Football.positionOf(card.match.league.id, card.match.away.id)) + root.percent(card.probs.away) : ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnTertiary
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: card.probs !== null
                                    Layout.fillWidth: true
                                    spacing: 6

                                    ProbChip { caption: Translation.tr("+1.5 goals"); value: card.probs ? card.probs.o15 : 0 }
                                    ProbChip { caption: Translation.tr("+2.5 goals"); value: card.probs ? card.probs.o25 : 0 }
                                    ProbChip { caption: Translation.tr("+8.5 corners"); value: card.probs ? card.probs.c85 : 0 }
                                    ProbChip { caption: Translation.tr("+9.5 corners"); value: card.probs ? card.probs.c95 : 0 }
                                }

                                StyledText {
                                    visible: card.probs !== null && card.match.expected !== undefined
                                    Layout.fillWidth: true
                                    text: card.match.expected ? Translation.tr("Expected: %1 – %2 goals · %3 corners").arg(card.match.expected.home).arg(card.match.expected.away).arg(card.match.expected.corners) : ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: root.activeDay !== null
                Layout.fillWidth: true
                implicitHeight: disclaimerRow.implicitHeight + 28
                radius: Appearance.rounding.normal
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                RowLayout {
                    id: disclaimerRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        text: "info"
                        iconSize: 22
                        fill: 1
                        color: Appearance.colors.colSubtext
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Please read")
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("This page is for information and entertainment only. Probabilities are statistical estimates built from the current season's data and do not guarantee any result: football is unpredictable. Betting involves a real risk of losing money. Only bet what you can afford to lose, only if you are of legal age, and seek help if gambling stops being fun.")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: detailPage
        anchors.fill: parent
        color: Appearance.colors.colLayer1Base
        opacity: root.detailMatch !== null ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        Timer {
            id: scrollTimer
            interval: 220
            property int attempts: 0
            onTriggered: {
                if (!root.scrollTarget || root.detailScrolled) return;
                if (detailFlick.contentHeight < detailFlick.height + 200 && attempts < 8) {
                    attempts++;
                    restart();
                    return;
                }
                attempts = 0;
                const y = root.scrollTarget.mapToItem(detailFlick.contentItem, 0, 0).y;
                detailFlick.contentY = Math.max(0, Math.min(y - 170, Math.max(0, detailFlick.contentHeight - detailFlick.height)));
                root.detailScrolled = true;
            }
        }

        RowLayout {
            id: detailHeader
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }
            spacing: 12
                RippleButton {
                    implicitWidth: 44
                    implicitHeight: 44
                    buttonRadius: 22
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    downAction: () => root.closeMatch()
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "arrow_back"
                        iconSize: 22
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: root.detailMatch ? root.detailMatch.league.name : ""
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.family: Appearance.font.family.title
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Standings")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true }
        }

        StyledFlickable {
            id: detailFlick
            anchors {
                top: detailHeader.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            contentWidth: width
            contentHeight: detailColumn.implicitHeight + 24
            clip: true

            ColumnLayout {
                id: detailColumn
                x: 12
                y: 4
                width: detailFlick.width - 24
                spacing: 12

                Rectangle {
                    visible: root.detailMatch !== null
                    Layout.fillWidth: true
                    implicitHeight: detailTeams.implicitHeight + 28
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: detailTeams
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 10

                            TeamBadge {
                                team: root.detailMatch ? root.detailMatch.home : ({})
                                favorite: false
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.detailMatch ? root.detailMatch.home.name : ""
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                        }

                        ColumnLayout {
                            spacing: 0

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: !root.detailMatch ? "" : root.detailMatch.state === "pre" ? root.timeLabel(root.detailMatch) : `${root.detailMatch.home.score ?? "-"} – ${root.detailMatch.away.score ?? "-"}`
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.detailMatch !== null && root.detailMatch.state === "pre"
                                text: root.detailMatch ? Qt.locale().toString(new Date(root.detailMatch.date), "ddd d MMM") : ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 10

                            StyledText {
                                Layout.fillWidth: true
                                text: root.detailMatch ? root.detailMatch.away.name : ""
                                horizontalAlignment: Text.AlignRight
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                            TeamBadge {
                                team: root.detailMatch ? root.detailMatch.away : ({})
                                favorite: false
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.detailMatch !== null
                    Layout.fillWidth: true
                    implicitHeight: formRow.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: formRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        FootballFormStrip {
                            games: root.detailMatch ? (Football.formByTeam[root.detailMatch.home.id] ?? []) : []
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 0

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "show_chart"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("Form")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        FootballFormStrip {
                            alignRight: true
                            games: root.detailMatch ? (Football.formByTeam[root.detailMatch.away.id] ?? []) : []
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Row {
                        spacing: 6
                        Rectangle {
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 4
                            color: root.homeRowColor
                        }
                        StyledText {
                            text: Translation.tr("Home")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 4
                            color: root.awayRowColor
                        }
                        StyledText {
                            text: Translation.tr("Away")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                Item {
                    visible: root.detailGroups === null
                    Layout.fillWidth: true
                    implicitHeight: 160

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialLoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            visible: Football.standingsLoading
                            loading: Football.standingsLoading
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Football.standingsFailed ? Translation.tr("Could not load the standings") : Translation.tr("Loading standings…")
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Repeater {
                    model: root.detailGroups ?? []

                    delegate: ColumnLayout {
                        id: groupBlock
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            visible: (root.detailGroups?.length ?? 0) > 1
                            text: groupBlock.modelData.name
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                            Layout.topMargin: 6
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            spacing: 6

                            StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: "#"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            Item { Layout.preferredWidth: 24 }
                            StyledText { Layout.fillWidth: true; text: Translation.tr("Team"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("P"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("W"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("D"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("L"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("GD"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            StyledText { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter; text: Translation.tr("Pts"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        }

                        Repeater {
                            model: groupBlock.modelData.rows

                            delegate: Rectangle {
                                id: tableRow
                                required property var modelData
                                required property int index
                                readonly property bool isHome: root.detailMatch !== null && modelData.id === root.detailMatch.home.id
                                readonly property bool isAway: root.detailMatch !== null && modelData.id === root.detailMatch.away.id
                                readonly property bool highlighted: isHome || isAway
                                readonly property color textColor: Appearance.colors.colOnLayer1

                                Layout.fillWidth: true
                                implicitHeight: 42
                                radius: 12
                                color: isHome ? root.homeRowColor : isAway ? root.awayRowColor : (index % 2 === 0 ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                                Component.onCompleted: {
                                    if (highlighted && !root.scrollTarget) {
                                        root.scrollTarget = tableRow;
                                    }
                                    if (highlighted) scrollTimer.restart();
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    StyledText {
                                        Layout.preferredWidth: 26
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(tableRow.modelData.rank)
                                        font.weight: tableRow.highlighted ? Font.DemiBold : Font.Normal
                                        color: tableRow.textColor
                                    }
                                    Image {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        source: tableRow.modelData.logo
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        mipmap: true
                                        sourceSize: Qt.size(96, 96)
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: tableRow.modelData.name
                                        font.weight: tableRow.highlighted ? Font.DemiBold : Font.Normal
                                        color: tableRow.textColor
                                        elide: Text.ElideRight
                                    }
                                    StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: String(tableRow.modelData.p); color: tableRow.textColor }
                                    StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: String(tableRow.modelData.w); color: tableRow.textColor }
                                    StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: String(tableRow.modelData.d); color: tableRow.textColor }
                                    StyledText { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: String(tableRow.modelData.l); color: tableRow.textColor }
                                    StyledText {
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (tableRow.modelData.gd > 0 ? "+" : "") + tableRow.modelData.gd
                                        color: tableRow.textColor
                                    }
                                    StyledText {
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(tableRow.modelData.pts)
                                        font.weight: Font.DemiBold
                                        color: tableRow.textColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
