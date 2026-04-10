import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    leftMarginOffset: {
        if (Config.options.bar.layouts.leftLayout.includes("clockWidget")) return 100
        if (Config.options.bar.layouts.middleLayout.includes("clockWidget")) return 0
        if (Config.options.bar.layouts.rightLayout.includes("clockWidget")) return -120
        return 0
    }

    function usageColor(value) {
        if (value > 0.9) return Appearance.colors.colError
        if (value > 0.6) return Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    ColumnLayout {
        spacing: 8
        width: 340

        Row {
            width: parent.width

            StyledText {
                text: Qt.locale().toString(DateTime.clock.date, " MMMM")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.bold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: " " + Qt.locale().toString(DateTime.clock.date, "yyyy")
                font.pixelSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        RowLayout {
            width: parent.width
            spacing: 4

            Repeater {
                model: 7
                delegate: Rectangle {
                    required property int index

                    readonly property var date: {
                        const today = DateTime.clock.date
                        const dow = today.getDay()
                        const d = new Date(today)
                        d.setDate(today.getDate() - dow + index)
                        return d
                    }
                    readonly property bool isToday: {
                        const t = DateTime.clock.date
                        return date.getDate()     === t.getDate() &&
                               date.getMonth()    === t.getMonth() &&
                               date.getFullYear() === t.getFullYear()
                    }

                    Layout.fillWidth: true
                    height: 56
                    radius: Appearance.rounding.normal
                    color: isToday
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSurfaceContainerHigh

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(date, "ddd").slice(0, 2)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnSurfaceVariant
                            font.weight: isToday ? Font.Bold : Font.Normal
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: date.getDate()
                            font.pixelSize: isToday
                                ? Appearance.font.pixelSize.normal
                                : Appearance.font.pixelSize.small
                            font.weight: isToday ? Font.Bold : Font.Normal
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Clover4Leaf
                    text: "checklist"
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 36
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colPrimary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Todo.list.filter(t => !t.done).length}`
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                }
            }

            Column {
                width: parent.width - 36 - 6
                spacing: 2

                Repeater {
                    id: todoRepeater
                    model: Math.min(3, Todo.list.filter(t => !t.done).length)

                    delegate: Rectangle {
                        required property int index
                        readonly property var filteredList: Todo.list.filter(t => !t.done)
                        readonly property var todo: filteredList[filteredList.length - 1 - index] // last first
                        readonly property int total: todoRepeater.count
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === total - 1
                        readonly property real bigRadius: Appearance.rounding.normal
                        readonly property real smallRadius: Appearance.rounding.unsharpenmore

                        width: parent.width
                        height: 32
                        topLeftRadius:     isFirst ? bigRadius : smallRadius
                        topRightRadius:    isFirst ? bigRadius : smallRadius
                        bottomLeftRadius:  isLast  ? bigRadius : smallRadius
                        bottomRightRadius: isLast  ? bigRadius : smallRadius
                        color: Appearance.colors.colSurfaceContainerHigh

                        StyledText {
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                                right: parent.right
                                rightMargin: 10
                            }
                            text: `    ${todo.content} `
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32 * 2 
                    visible: Todo.list.filter(t => !t.done).length === 0
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh

                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr("No pending tasks")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: Appearance.rounding.normal
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: "timelapse"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: "Sytem Uptime"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: DateTime.uptime
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }
    }
}