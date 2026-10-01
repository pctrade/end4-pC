import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: timers
    required property Item di
    anchors.fill: parent

    readonly property int secondsLeft: timers.di.timerSecondsLeft()
    readonly property bool finalCountdown: timers.di.timerRunning() && timers.secondsLeft >= 0 && timers.secondsLeft <= 10
    readonly property color accent: timers.finalCountdown ? Appearance.colors.colError : Appearance.colors.colPrimary

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 12
            bottomMargin: 2
        }
        spacing: 6

        MaterialSymbol {
            text: timers.di.timerRunning() ? "pause" : "play_arrow"
            iconSize: 18
            fill: 1
            color: timers.accent

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: timers.di.toggleActiveTimer()
            }
        }

        MaterialSymbol {
            text: "stop"
            iconSize: 18
            fill: 1
            color: Appearance.colors.colOnLayer0
            opacity: 0.6

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: timers.di.resetActiveTimer()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: timers.di.hoverRevealed
            text: {
                switch (timers.di.engagedTimerKind) {
                    case "pomodoro": return TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                    case "countdown": return Translation.tr("Timer")
                    default: return Translation.tr("Stopwatch")
                }
            }
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }

        Item {
            Layout.fillWidth: true
            visible: !timers.di.hoverRevealed
        }

        StyledText {
            text: timers.di.timerValueText()
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: timers.finalCountdown ? Appearance.colors.colError : Appearance.colors.colOnLayer0
        }
    }

    Item {
        visible: timers.di.engagedTimerKind !== "stopwatch"
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 14
            rightMargin: 14
            bottomMargin: 3
        }
        height: 3

        Rectangle {
            anchors.fill: parent
            radius: 1.5
            color: ColorUtils.transparentize(timers.accent, 0.8)
        }

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, timers.di.timerProgress()))
            height: parent.height
            radius: 1.5
            color: timers.accent

            Behavior on width {
                NumberAnimation { duration: 1000; easing.type: Easing.Linear }
            }
        }
    }
}
