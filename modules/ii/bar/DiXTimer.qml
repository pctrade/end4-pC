import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: xt
    required property Item di
    spacing: 18
    implicitWidth: 320
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 320

    readonly property string kind: xt.di.engagedTimerKind
    readonly property int secondsLeft: xt.di.timerSecondsLeft()
    readonly property bool finalCountdown: xt.di.timerRunning() && xt.secondsLeft >= 0 && xt.secondsLeft <= 10
    readonly property color accent: xt.finalCountdown ? Appearance.colors.colError : Appearance.colors.colPrimary

    component RoundButton: Rectangle {
        id: button
        property string icon
        property string label: ""
        property bool primary: false
        property var onTap
        implicitWidth: button.label === "" ? 40 : buttonRow.implicitWidth + 24
        implicitHeight: 40
        radius: 20
        color: button.primary ? xt.accent : (buttonMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)
        scale: buttonMouse.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                text: button.icon
                iconSize: 20
                fill: 1
                color: button.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
            StyledText {
                visible: button.label !== ""
                text: button.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.onTap()
        }
    }

    Item {
        implicitWidth: 92
        implicitHeight: 92

        CircularProgress {
            anchors.fill: parent
            implicitSize: 92
            lineWidth: 6
            value: xt.di.timerProgress()
            colPrimary: xt.accent
            colSecondary: ColorUtils.transparentize(xt.accent, 0.8)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -2
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: xt.di.timerValueText()
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: xt.finalCountdown ? Appearance.colors.colError : Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    switch (xt.kind) {
                        case "pomodoro": return TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                        case "countdown": return Translation.tr("Timer")
                        default: return Translation.tr("Stopwatch")
                    }
                }
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            spacing: 8
            RoundButton {
                primary: true
                icon: xt.di.timerRunning() ? "pause" : "play_arrow"
                onTap: () => xt.di.toggleActiveTimer()
            }
            RoundButton {
                icon: "stop"
                onTap: () => xt.di.resetActiveTimer()
            }
            RoundButton {
                visible: xt.kind === "stopwatch"
                icon: "flag"
                onTap: () => TimerService.stopwatchRecordLap()
            }
        }

        RoundButton {
            visible: xt.kind === "countdown"
            icon: "add"
            label: "1 min"
            onTap: () => TimerService.addCountdownMinutes(1)
        }

        StyledText {
            visible: xt.kind === "pomodoro"
            text: `${Translation.tr("Cycle")} ${TimerService.pomodoroCycle + 1}/${TimerService.cyclesBeforeLongBreak}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }

        StyledText {
            visible: xt.kind === "stopwatch" && (TimerService.stopwatchLaps?.length ?? 0) > 0
            text: `${TimerService.stopwatchLaps?.length ?? 0} ${Translation.tr("laps")}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }
    }
}
