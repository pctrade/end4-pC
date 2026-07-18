import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 200
            implicitHeight: 200

            ClockPicker {
                anchors.fill: parent
                value: Math.round(TimerService.focusTime / 60)
                running: TimerService.pomodoroRunning
                onDragFinished: val => {
                    if (!TimerService.pomodoroRunning) {
                        Config.options.time.pomodoro.focus = val * 60;
                        TimerService.pomodoroSecondsLeft = val * 60; 
                    }
                }
            }

            Rectangle {
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                implicitWidth: 36
                implicitHeight: implicitWidth

                StyledText {
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnLayer2
                    text: TimerService.pomodoroCycle + 1
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.normal

            RippleButton {
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: TimerService.pomodoroRunning ? Translation.tr("Pause") : (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume")
                    color: TimerService.pomodoroRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                onClicked: TimerService.togglePomodoro()
                colBackground: TimerService.pomodoroRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.pomodoroRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90
                onClicked: TimerService.resetPomodoro()
                enabled: (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration) || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak
                font.pixelSize: Appearance.font.pixelSize.larger
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}