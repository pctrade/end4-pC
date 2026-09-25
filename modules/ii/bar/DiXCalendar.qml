import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../sidebarRight/calendar/calendar_layout.js" as CalendarLayout

// The calendar, opened from the anchor. The date is the one piece of information you look up rather than
// glance at, so it gets a whole view instead of a line — today in full, the month around it, and whatever
// the shell already knows about the rest of the day.
ColumnLayout {
    id: xc
    required property Item di
    spacing: 10
    implicitWidth: 360
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 360

    property int monthShift: 0
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(xc.monthShift)
    readonly property var layoutRows: CalendarLayout.getCalendarLayout(xc.viewingDate, xc.monthShift === 0)
    readonly property string displayFont: {
        switch (xc.di.cfg.anchorFont ?? "expressive") {
            case "numbers":   return Appearance.font.family.numbers
            case "monospace": return Appearance.font.family.monospace
            case "main":      return Appearance.font.family.main
            default:          return Appearance.font.family.expressive
        }
    }

    // Today, large: the answer to "what day is it" before the grid is even read
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            spacing: -6

            StyledText {
                text: DateTime.time
                font.family: xc.displayFont
                font.pixelSize: 34
                font.weight: Font.Medium
                font.letterSpacing: 0.5
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                text: DateTime.longDate
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
        }

        Item { Layout.fillWidth: true }

        // Week number and how much of the year is gone: the context a date has that a clock does not
        ColumnLayout {
            Layout.alignment: Qt.AlignRight
            spacing: -3

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: Translation.tr("Week %1").arg(xc.weekNumber(new Date()))
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.8
            }
            StyledText {
                Layout.alignment: Qt.AlignRight
                text: Translation.tr("%1 days left this year").arg(xc.daysLeftInYear())
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.55
            }
        }
    }

    // Month header with its own navigation; scrolling anywhere on the grid also moves months
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: xc.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            font.family: xc.displayFont
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: xc.monthShift === 0 ? Appearance.colors.colOnLayer0 : Appearance.colors.colPrimary
        }

        Repeater {
            model: [
                { icon: "chevron_left", step: -1 },
                { icon: "today", step: 0 },
                { icon: "chevron_right", step: 1 }
            ]
            delegate: Rectangle {
                id: navButton
                required property var modelData
                visible: modelData.step !== 0 || xc.monthShift !== 0
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: navMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: navButton.modelData.icon
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }

                MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (navButton.modelData.step === 0) xc.monthShift = 0
                        else xc.monthShift += navButton.modelData.step
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: grid.implicitHeight

        MouseArea {
            anchors.fill: parent
            onWheel: event => xc.monthShift += event.angleDelta.y > 0 ? -1 : 1
        }

        ColumnLayout {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                Repeater {
                    model: CalendarLayout.weekDays
                    delegate: StyledText {
                        required property var modelData
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr(modelData.day)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.5
                    }
                }
            }

            Repeater {
                model: 6
                delegate: RowLayout {
                    required property int index
                    readonly property int row: index
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 3

                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            id: dayCell
                            required property int index
                            readonly property var cell: xc.layoutRows[parent.row][index]
                            readonly property bool today: dayCell.cell.today === 1
                            readonly property bool outside: dayCell.cell.today === -1
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 34
                            radius: 10
                            color: dayCell.today ? Appearance.colors.colPrimary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: dayCell.cell.day
                                font.family: xc.displayFont
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: dayCell.today ? Font.DemiBold : Font.Normal
                                font.features: { "tnum": 1 }
                                color: dayCell.today ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                opacity: dayCell.outside ? 0.3 : 1
                            }
                        }
                    }
                }
            }
        }
    }

    // What the shell already knows is coming today
    StyledText {
        Layout.fillWidth: true
        visible: xc.di.hasActiveTimer || (F1.enabled && F1.nextSession !== null && F1.secondsToNext < 86400)
        text: {
            const parts = []
            if (xc.di.hasActiveTimer) parts.push(`${Translation.tr("Timer")} ${xc.di.timerValueText()}`)
            if (F1.enabled && F1.nextSession !== null && F1.secondsToNext < 86400)
                parts.push(`F1 · ${F1.sessionLabel(F1.nextSession.name)} ${Translation.tr("in %1").arg(F1.humanCountdown(F1.secondsToNext))}`)
            return parts.join("   ·   ")
        }
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.7
        elide: Text.ElideRight
    }

    function weekNumber(date) {
        const target = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        // ISO 8601: week 1 is the one holding the first Thursday of the year
        const day = (target.getDay() + 6) % 7
        target.setDate(target.getDate() - day + 3)
        const firstThursday = new Date(target.getFullYear(), 0, 4)
        const firstDay = (firstThursday.getDay() + 6) % 7
        firstThursday.setDate(firstThursday.getDate() - firstDay + 3)
        return 1 + Math.round((target - firstThursday) / (7 * 24 * 3600 * 1000))
    }

    function daysLeftInYear() {
        const now = new Date()
        const end = new Date(now.getFullYear(), 11, 31)
        return Math.max(0, Math.ceil((end - now) / (24 * 3600 * 1000)))
    }
}
