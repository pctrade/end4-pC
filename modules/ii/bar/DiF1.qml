import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: f1
    required property Item di
    anchors.fill: parent

    readonly property var driver: F1.focusDriver
    readonly property color flagColor: F1.flagColor(F1.flag)

    function shortFlag(flag) {
        switch (flag) {
            case "yellow": return "YEL"
            case "sc": return "SC"
            case "vsc":
            case "vscEnding": return "VSC"
            case "red": return "RED"
            default: return ""
        }
    }

    // Overtake tracking for the focused driver (favourite, or whoever leads)
    readonly property int focusPosition: f1.driver?.position ?? 0
    readonly property string focusTla: f1.driver?.tla ?? ""
    property int lastPosition: 0
    property string lastTla: ""
    property int trend: 0
    property string overtakeText: ""
    property int oldPositionShown: 0
    property real roll: 1

    function registerChange() {
        const pos = f1.focusPosition
        const tla = f1.focusTla
        const racing = F1.racing && !F1.initializing
        if (!racing || f1.lastPosition === 0 || pos === 0) {
            f1.lastPosition = pos
            f1.lastTla = tla
            return
        }
        if (tla !== f1.lastTla) {
            // Following the leader: a different car at the front is itself an overtake
            if (F1.favoriteDriver === "" && pos === 1) f1.celebrate(1, `▲ ${tla}`, f1.lastPosition)
            f1.lastTla = tla
            f1.lastPosition = pos
            return
        }
        if (pos === f1.lastPosition) return
        const gained = pos < f1.lastPosition
        const other = F1.drivers.find(d => d.position === (gained ? pos + 1 : pos - 1))
        f1.celebrate(gained ? 1 : -1, `${gained ? "▲" : "▼"} ${other?.tla ?? ""}`, f1.lastPosition)
        f1.lastPosition = pos
    }

    function celebrate(direction, text, previous) {
        f1.trend = direction
        f1.overtakeText = text
        f1.oldPositionShown = previous
        rollAnim.restart()
        washAnim.restart()
        overtakeTimer.restart()
        f1.di.peek(5000)
    }

    onFocusPositionChanged: f1.registerChange()
    onFocusTlaChanged: f1.registerChange()
    Component.onCompleted: {
        f1.lastPosition = f1.focusPosition
        f1.lastTla = f1.focusTla
    }

    Timer {
        id: overtakeTimer
        interval: 6000
        onTriggered: f1.trend = 0
    }

    NumberAnimation {
        id: rollAnim
        target: f1
        property: "roll"
        from: 0
        to: 1
        duration: 620
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
    }

    Rectangle {
        id: wash
        anchors.fill: parent
        radius: height / 2
        color: f1.trend >= 0 ? Appearance.m3colors.m3success : Appearance.colors.colError
        opacity: 0

        SequentialAnimation {
            id: washAnim
            NumberAnimation { target: wash; property: "opacity"; to: 0.2; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: wash; property: "opacity"; to: 0; duration: 1200; easing.type: Easing.InQuad }
        }
    }

    // Countdown to the next session
    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 12
        }
        visible: !F1.sessionLive
        spacing: 7

        MaterialSymbol {
            text: "sports_score"
            iconSize: 18
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: F1.sessionLabel(F1.nextSession?.name ?? "")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            text: F1.formatCountdown(F1.secondsToNext)
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colPrimary
        }
    }

    // Live session
    RowLayout {
        anchors {
            fill: parent
            leftMargin: 9
            rightMargin: 12
        }
        visible: F1.sessionLive
        spacing: 6

        Rectangle {
            implicitWidth: 9
            implicitHeight: 9
            radius: 4.5
            color: f1.flagColor

            Behavior on color {
                ColorAnimation { duration: 300 }
            }

        }

        // Position number rolls up when gaining places, down when losing them
        Item {
            implicitWidth: Math.max(positionMetrics.implicitWidth, 22)
            implicitHeight: 20
            clip: true

            StyledText {
                id: positionMetrics
                visible: false
                text: `P${f1.focusPosition || "-"}`
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: f1.roll < 1 ? (f1.trend >= 0 ? -f1.roll : f1.roll) * parent.height : parent.height * 2
                text: `P${f1.oldPositionShown}`
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 1 - f1.roll
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (f1.trend >= 0 ? (1 - f1.roll) : -(1 - f1.roll)) * parent.height
                text: `P${f1.focusPosition || "-"}`
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: f1.trend > 0 ? Appearance.m3colors.m3success : f1.trend < 0 ? Appearance.colors.colError : Appearance.colors.colOnLayer0

                Behavior on color {
                    ColorAnimation { duration: 400 }
                }
            }
        }

        Rectangle {
            implicitWidth: f1.trend !== 0 ? 5 : 3
            implicitHeight: 14
            radius: 2
            color: f1.driver?.color ?? Appearance.colors.colPrimary

            Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.OutBack }
            }
        }

        StyledText {
            text: f1.focusTla
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }

        Rectangle {
            visible: (f1.driver?.tyre ?? "") !== ""
            implicitWidth: 14
            implicitHeight: 14
            radius: 7
            color: "#1B1B1B"
            border.width: 2
            border.color: F1.tyreColor(f1.driver?.tyre ?? "")

            StyledText {
                anchors.centerIn: parent
                text: F1.tyreLetter(f1.driver?.tyre ?? "")
                font.pixelSize: 7
                font.weight: Font.Black
                color: F1.tyreColor(f1.driver?.tyre ?? "")
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: {
                const d = f1.driver
                if (!d) return ""
                if (d.inPit) return Translation.tr("PIT")
                if (d.position === 1) return F1.isRace ? Translation.tr("Leader") : (d.best ?? "")
                return F1.isRace ? (d.gap ?? "") : (d.best ?? "")
            }
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }

        StyledText {
            id: f1Extra
            visible: f1.di.hoverRevealed || f1.trend !== 0
            onVisibleChanged: if (visible) f1ExtraIn.restart()
            text: {
                if (f1.trend !== 0) return f1.overtakeText
                const d = f1.driver
                if (!F1.isRace) return F1.remaining.replace(/^00:/, "")
                if (d && d.position > 1) return `▲ ${d.interval}`
                const second = F1.drivers.length > 1 ? F1.drivers[1] : null
                return second ? `${second.tla} ${second.interval}` : ""
            }
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: f1.trend !== 0 ? Font.Bold : Font.Normal
            font.features: { "tnum": 1 }
            color: f1.trend > 0 ? Appearance.m3colors.m3success : f1.trend < 0 ? Appearance.colors.colError : Appearance.colors.colOnLayer0

            NumberAnimation {
                id: f1ExtraIn
                target: f1Extra
                property: "opacity"
                from: 0
                to: 0.9
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            visible: F1.flag !== "green"
            implicitWidth: flagText.implicitWidth + 8
            implicitHeight: 16
            radius: 4
            color: f1.flagColor

            StyledText {
                id: flagText
                anchors.centerIn: parent
                text: f1.shortFlag(F1.flag)
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                color: "#111111"
            }
        }

        StyledText {
            visible: F1.flag === "green"
            text: F1.totalLaps > 0 ? `${F1.lap}/${F1.totalLaps}` : F1.remaining.replace(/^00:/, "")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
        }
    }
}
