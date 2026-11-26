import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../sidebarRight/calendar/calendar_layout.js" as CalendarLayout

// Calendar view: today, the month, and what else the shell knows about the day.
ColumnLayout {
    id: xc
    required property Item di
    spacing: 10
    implicitWidth: 500
    readonly property real wantedWidth: 500

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

    RowLayout {
        Layout.fillWidth: true
        spacing: 18

        ColumnLayout {
            Layout.preferredWidth: 160
            Layout.maximumWidth: 160
            Layout.fillHeight: true
            spacing: 2

            StyledText {
                text: DateTime.time
                font.family: xc.displayFont
                font.pixelSize: 40
                font.weight: Font.Medium
                font.letterSpacing: 0.5
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: DateTime.longDate
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: 8 }

            StyledText {
                text: Translation.tr("Week %1").arg(xc.weekNumber(new Date()))
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.8
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("%1 days left this year").arg(xc.daysLeftInYear())
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.55
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                visible: xc.upNext.length > 0
                implicitHeight: upNextColumn.implicitHeight + 14
                radius: 12
                color: Appearance.colors.colLayer1

                ColumnLayout {
                    id: upNextColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 10
                    }
                    spacing: 2

                    Repeater {
                        model: xc.upNext
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 14
                                fill: 1
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: modelData.text
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

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
                Layout.preferredWidth: grid.implicitWidth

                MouseArea {
                    anchors.fill: parent
                    onWheel: event => xc.monthShift += event.angleDelta.y > 0 ? -1 : 1
                }

                ColumnLayout {
                    id: grid
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2
                        Repeater {
                            model: CalendarLayout.weekDays
                            delegate: StyledText {
                                required property var modelData
                                Layout.preferredWidth: 40
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
                            spacing: 2

                            Repeater {
                                model: 7
                                delegate: Rectangle {
                                    id: dayCell
                                    required property int index
                                    readonly property var cell: xc.layoutRows[parent.row][index]
                                    readonly property bool today: dayCell.cell.today === 1
                                    readonly property bool outside: dayCell.cell.today === -1
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 28
                                    radius: 9
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
        }
    }

    readonly property var upNext: {
        const items = []
        if (xc.di.hasActiveTimer) items.push({ icon: "timer", text: `${Translation.tr("Timer")} ${xc.di.timerValueText()}` })
        if (F1.enabled && F1.nextSession !== null && F1.secondsToNext < 86400)
            items.push({ icon: "sports_motorsports", text: `${F1.sessionLabel(F1.nextSession.name)} ${Translation.tr("in %1").arg(F1.humanCountdown(F1.secondsToNext))}` })
        return items
    }

    function weekNumber(date) {
        const target = new Date(date.getFullYear(), date.getMonth(), date.getDate())
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
