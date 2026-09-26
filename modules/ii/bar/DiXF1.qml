import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xf
    required property Item di
    spacing: 10
    implicitWidth: 480
    readonly property real wantedWidth: 480

    readonly property color flagColor: F1.flagColor(F1.flag)

    function formatLongCountdown(seconds) {
        if (seconds < 0) return ""
        const d = Math.floor(seconds / 86400)
        const h = Math.floor((seconds % 86400) / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        if (d > 0) return `${d}d ${h}h`
        if (h > 0) return `${h}h ${m}min`
        return F1.formatCountdown(seconds)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

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
            text: F1.sessionLive
                ? (F1.totalLaps > 0 ? `${Translation.tr("Lap")} ${F1.lap}/${F1.totalLaps}` : F1.remaining)
                : xf.formatLongCountdown(F1.secondsToNext)
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: F1.sessionLive ? Appearance.colors.colOnLayer0 : Appearance.colors.colPrimary
        }
    }

    Item {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: grid.perColumn * grid.rowH
        visible: F1.sessionLive && driversModel.count > 0

        readonly property int perColumn: 5
        readonly property real rowH: 30
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
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !F1.sessionLive && F1.nextSession !== null
        text: F1.nextSession ? Qt.locale().toString(new Date(F1.nextSession.start), "dddd, dd/MM · hh:mm") : ""
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.8
    }
}
