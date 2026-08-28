import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
;import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "calendar"
    hoverEnabled: true

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real cardHeight: 120

    readonly property real snapWidth1: singleWidth            
    readonly property real snapWidth2: singleWidth * 2 + cardSpacing  
    readonly property real snapWidth3: singleWidth * 3 + cardSpacing * 2

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return snapWidth1
            case "2x3": return snapWidth3
            default:    return snapWidth2
        }
    }

    function modeForWidth(value) {
        var mid1 = (snapWidth1 + snapWidth2) / 2
        if (value < mid1) return "1x1"
        return root.sizeMode === "1x2" ? "1x2" : "2x2"
    }

    readonly property real heightToggleFraction: 0.3
    readonly property real heightToggleDelta: (root.cardHeight * 2 + root.cardSpacing - root.cardHeight) * root.heightToggleFraction

    function modeForDrag(dx, dy, startWidth) {
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        var newWidth = startWidth + dx

        if (newWidth < mid1) return "1x1"
        if (newWidth >= mid2) return "2x3"

        if (root.sizeMode === "1x1") {
            return dy > root.heightToggleDelta ? "2x2" : "1x2"
        }
        if (dy > root.heightToggleDelta) return "2x2"
        if (dy < -root.heightToggleDelta) return "1x2"
        return root.sizeMode === "2x3" ? "2x2" : root.sizeMode
    }

    property int monthShift: 0
    readonly property var today: new Date()

    property var viewingDate: {
        let d = new Date()
        d.setDate(1)
        d.setMonth(d.getMonth() + monthShift)
        return d
    }

    function getMonthMatrix(date) {
        const year  = date.getFullYear()
        const month = date.getMonth()
        const firstOfMonth   = new Date(year, month, 1)
        const startOffset    = (firstOfMonth.getDay() + 6) % 7
        const daysInMonth    = new Date(year, month + 1, 0).getDate()
        const daysInPrevMonth = new Date(year, month, 0).getDate()

        let cells = []
        for (let i = 0; i < startOffset; i++)
            cells.push({ day: daysInPrevMonth - startOffset + i + 1, currentMonth: false, isToday: false })

        for (let d = 1; d <= daysInMonth; d++) {
            const isToday = monthShift === 0
                && d === today.getDate()
                && month === today.getMonth()
                && year  === today.getFullYear()
            cells.push({ day: d, currentMonth: true, isToday: isToday })
        }

        let nextDay = 1
        while (cells.length < 42) {
            cells.push({ day: nextDay++, currentMonth: false, isToday: false })
        }

        let weeks = []
        for (let i = 0; i < cells.length; i += 7)
            weeks.push(cells.slice(i, i + 7))
        return weeks
    }

    function getCurrentWeek() {
        const matrix = getMonthMatrix(viewingDate)
        for (let w = 0; w < matrix.length; w++) {
            if (matrix[w].some(c => c.isToday)) return matrix[w]
        }
        return matrix[0]
    }

    property var weeks: getMonthMatrix(viewingDate)

    implicitWidth:  card.implicitWidth
    implicitHeight: card.implicitHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    component DayCell: Rectangle {
        property int day: 0
        property bool currentMonth: true
        property bool isToday: false
        property bool bold: false

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: isToday ? Appearance.colors.colPrimary : "transparent"

        StyledText {
            anchors.centerIn: parent
            text: parent.day
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: parent.bold || parent.isToday ? Font.Bold : Font.Normal
            color: parent.isToday
                ? Appearance.colors.colOnPrimary
                : Appearance.colors.colOnLayer0
            opacity: parent.currentMonth ? 1.0 : 0.3
        }
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.sizeMode === "1x1" ? root.cardHeight
                      : root.sizeMode === "1x2" ? root.cardHeight
                      : root.cardHeight * 2 + root.cardSpacing
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                if (root.sizeMode === "2x3") return twoByThreeContent
                return twoByTwoContent
            }
        }

        // 1x1
        Component {
            id: oneByOneContent
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"

                ColumnLayout {
                    anchors { fill: parent; margins: 0 }
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: parent.height * 0.35
                        color: Appearance.colors.colPrimary
                        topLeftRadius: card.radius
                        topRightRadius: card.radius

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            StyledText {
                                text: root.today.toLocaleDateString(Qt.locale(), "MMM").toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                text: root.today.toLocaleDateString(Qt.locale(), "ddd").toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimary
                                opacity: 0.7
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            anchors.centerIn: parent
                            text: root.today.getDate()
                            font.pixelSize: 60
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 8

                Rectangle {
                    Layout.leftMargin: 3
                    implicitHeight: 28
                    implicitWidth: monthText.implicitWidth + 20
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary

                    StyledText {
                        id: monthText
                        anchors.centerIn: parent
                        text: root.today.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimary
                    }
                }

                Grid {
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: Item {
                            implicitWidth: (card.implicitWidth - 28) / 7
                            implicitHeight: 20
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.5
                            }
                        }
                    }

                    Repeater {
                        model: root.getCurrentWeek()
                        delegate: Item {
                            required property var modelData
                            implicitWidth: (card.implicitWidth - 28) / 7
                            implicitHeight: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28; height: 28
                                radius: 14
                                color: modelData.isToday ? Appearance.colors.colPrimary : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                    color: modelData.isToday
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnPrimaryContainer
                                    opacity: modelData.currentMonth ? 1.0 : 0.3
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // 2x2
        Component {
            id: twoByTwoContent
            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift--
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift++
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: StyledText {
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            text: modelData
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                    radius: (Appearance.rounding?.verylarge ?? 30) - 8

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -3

                        Repeater {
                            model: root.weeks
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 4
                                Repeater {
                                    model: parent.modelData
                                    delegate: DayCell {
                                        required property var modelData
                                        day: modelData.day
                                        currentMonth: modelData.currentMonth
                                        isToday: modelData.isToday
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2x3
        Component {
            id: twoByThreeContent
            RowLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 110
                    Layout.fillHeight: true
                    spacing: 2

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Gem
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: "calendar_month"
                        iconSize: 22
                        fill: 1
                        padding: 6
                        implicitWidth: 44
                        implicitHeight: 44
                    }

                    Item { Layout.fillHeight: true }

                    StyledText {
                        text: root.today.toLocaleDateString(Qt.locale(), "MMMM").toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    StyledText {
                        text: root.today.toLocaleDateString(Qt.locale(), "dddd")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }

                    StyledText {
                        text: root.today.getDate()
                        font.pixelSize: 66
                        font.weight: Font.Bold
                        color: Appearance.colors.colPrimary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                    radius: (Appearance.rounding?.verylarge ?? 30) - 8

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 4

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4
                            Repeater {
                                model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                delegate: StyledText {
                                    Layout.preferredWidth: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                    text: modelData
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: -3

                            Repeater {
                                model: root.getMonthMatrix(root.today)
                                delegate: RowLayout {
                                    required property var modelData
                                    spacing: 4
                                    Repeater {
                                        model: parent.modelData
                                        delegate: DayCell {
                                            required property var modelData
                                            day: modelData.day
                                            currentMonth: modelData.currentMonth
                                            isToday: modelData.currentMonth && modelData.day === root.today.getDate()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: {
                root.configEntry.sizeMode = root.sizeMode
            }
        }
    }
}
