import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "timers"
    hoverEnabled: true

    property real widgetWidth: 420
    property real cardSpacing: 12
    property real cardHeight: 120
    property real cardWidth: (widgetWidth - cardSpacing * 2) / 3
    property bool isVertical: root.configEntry.vertical ?? false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    component TimerCard: Rectangle {
        id: timerCard
        property string icon: ""
        property string value: ""
        property string label: ""
        property bool running: false
        property int shape: MaterialShape.Shape.Cookie12Sided
        property color bgColor: Appearance.colors.colPrimaryContainer
        property color shapeColor: Appearance.colors.colPrimary
        property var onToggle: () => {}
        property var onReset: () => {}
        default property alias extraContent: extraSlot.data

        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: timerCard.bgColor

        StyledRectangularShadow {
            target: timerCard
            z: -2
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: timerCard.onReset()
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: -4

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Item { Layout.fillWidth: true }

                MaterialShapeWrappedMaterialSymbol {
                    shape: timerCard.shape
                    color: timerCard.shapeColor
                    colSymbol: Appearance.colors.colOnPrimary
                    text: timerCard.running ? "pause" : timerCard.icon
                    iconSize: 18
                    fill: 1
                    padding: 6
                    implicitWidth: 34
                    implicitHeight: 34

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: timerCard.onToggle()
                    }
                }
            }

            Item { Layout.fillHeight: true }

            ColumnLayout {
                Layout.leftMargin: 2
                Layout.topMargin: -40
                spacing: -4
                StyledText {
                    text: timerCard.value
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: timerCard.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                }
            }

            Item {
                id: extraSlot
                Layout.fillWidth: true
                Layout.preferredHeight: children.length > 0 ? 22 : 0
                Layout.topMargin: children.length > 0 ? 6 : 0
            }
        }
    }

    Grid {
        id: row
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        spacing: root.cardSpacing

        Behavior on columns {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        // Pomodoro
        TimerCard {
            icon: TimerService.pomodoroBreak ? "coffee" : "visibility"
            value: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            label: TimerService.pomodoroBreak ? "Break" : "Focus"
            running: TimerService.pomodoroRunning
            bgColor: Appearance.colors.colTertiaryContainer
            shapeColor: Appearance.colors.colTertiary
            shape: MaterialShape.Shape.Flower
            onToggle: () => TimerService.togglePomodoro()
            onReset: () => TimerService.resetPomodoro()
        }

        // Stopwatch
        TimerCard {
            icon: "timer"
            value: TimerService.formatSeconds(TimerService.stopwatchTime / 100)
            label: "Stopwatch"
            running: TimerService.stopwatchRunning
            shape: MaterialShape.Shape.Sunny
            bgColor: Appearance.colors.colSecondaryContainer
            shapeColor: Appearance.colors.colSecondary
            onToggle: () => TimerService.toggleStopwatch()
            onReset: () => TimerService.stopwatchReset()
        }

        // Countdown
        TimerCard {
            icon: "hourglass_top"
            value: TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            label: "Countdown"
            running: TimerService.countdownRunning
            shape: MaterialShape.Shape.Bun
            onToggle: () => TimerService.toggleCountdown()
            onReset: () => TimerService.resetCountdown()

            RowLayout {
                anchors.fill: parent
                spacing: 4

                Repeater {
                    model: [1, 5]
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnTertiaryContainer, 0.85)

                        StyledText {
                            anchors.centerIn: parent
                            text: "+" + modelData + "m"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TimerService.addCountdownMinutes(modelData)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toggleHandle
        width: 16
        height: 16
        radius: 6
        color: Appearance.colors.colOnPrimaryContainer
        anchors {
            left: parent.right
            bottom: parent.bottom
            margins: -6
        }
        opacity: root.containsMouse || toggleArea.containsMouse ? 0.7 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "rotate_right"
            iconSize: 11
            color: Appearance.colors.colPrimaryContainer

            RotationAnimation on rotation {
                running: toggleArea.containsMouse
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isVertical = !root.isVertical
                root.configEntry.vertical = root.isVertical
            }
        }
    }
}