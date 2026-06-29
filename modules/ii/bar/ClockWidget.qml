import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property var today: new Date()
    readonly property string dateTimeString: DateTime.time
    readonly property bool hasAmPm: dateTimeString.toLowerCase().includes("am") || dateTimeString.toLowerCase().includes("pm")

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : root.isMaterial ? (rowLoader.item?.implicitWidth ?? 0) : (rowLoader.item?.implicitWidth ?? 0) + 12
    implicitHeight: vertical ? (colLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

    // Vertical
    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? colMaterial : colDefault

        Component {
            id: colDefault
            ColumnLayout {
                id: column
                anchors.centerIn: parent
                spacing: root.hasAmPm ? 6 : 0

                Column {
                    Layout.alignment: Qt.AlignHCenter  
                    spacing: -4

                    Repeater {
                        model: root.dateTimeString.split(/[: ]/)
                        delegate: StyledText {
                            required property string modelData
                            width: implicitWidth
                            horizontalAlignment: Text.AlignHCenter 
                            font.pixelSize: {
                                if (modelData.match(/am|pm/i))
                                    return Appearance.font.pixelSize.smaller;
                                else
                                    return Appearance.font.pixelSize.large;
                            }
                            color: Appearance.colors.colOnLayer1
                            text: modelData.padStart(2, "0")
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter  
                    Layout.bottomMargin: 5
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    text: DateTime.shortDate
                }
            }
        }

        Component {
            id: colMaterial
            ColumnLayout {
                spacing: -6
                property var timeParts: DateTime.time.split(/[: ]/)
                property string hours: timeParts[0] ?? "00"
                property string minutes: timeParts[1] ?? "00"
                property string ampm: timeParts[2] ?? ""

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colPrimary
                    radius: Appearance.rounding.full
                    implicitWidth: 32
                    implicitHeight: 32
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                        text: parent.parent.hours.padStart(2, "0")
                        font.features: { "tnum": 1 }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colPrimaryContainer
                    radius: Appearance.rounding.full
                    implicitWidth: 32
                    implicitHeight: 32
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colPrimary
                        text: parent.parent.minutes.padStart(2, "0")
                        font.features: { "tnum": 1 }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colSecondaryContainer
                    radius: Appearance.rounding.full
                    implicitWidth: 32
                    implicitHeight: 18
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.smallest - 1
                        color: Appearance.colors.colPrimary
                        text: DateTime.shortDate
                        font.features: { "tnum": 1 }
                    }
                }

                Rectangle {
                    visible: parent.ampm !== ""
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colTertiaryContainer
                    radius: Appearance.rounding.full
                    implicitWidth: 30
                    implicitHeight: 20
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                        text: parent.parent.ampm
                    }
                }
            }
        }
    }

    // Horizontal
    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? rowMaterial : rowDefault

        Component {
            id: rowDefault
            RowLayout {
                spacing: 4
                StyledText {
                    visible: root.showDate
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: DateTime.longDate
                }
                StyledText {
                    visible: root.showDate
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: "•"
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: DateTime.time
                    font.letterSpacing: -0.4
                    font.features: { "tnum": 1 }
                }
            }
        }

        Component {
            id: rowMaterial
            RowLayout {
                spacing: 4

                Rectangle {
                    id: pill
                    color: Appearance.colors.colPrimaryContainer
                    radius: Appearance.rounding.full
                    implicitHeight: 32
                    implicitWidth: pillRow.implicitWidth + 4 + 4

                    property var timeParts: DateTime.time.split(/[: ]/)
                    property string hours: timeParts[0] ?? "00"
                    property string minutes: timeParts[1] ?? "00"
                    property string ampm: timeParts[2] ?? ""

                    RowLayout {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 6

                        StyledText {
                            visible: root.showDate
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            text: DateTime.longDate
                            Layout.alignment: Qt.AlignVCenter
                            leftPadding: 5
                        }

                        Rectangle {
                            implicitWidth: timeText.implicitWidth + 16
                            implicitHeight: 24
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colPrimary

                            StyledText {
                                id: timeText
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colOnPrimary
                                font.weight: Font.Bold
                                text: pill.ampm !== "" ? pill.hours.padStart(2, "0") + ":" + pill.minutes.padStart(2, "0") : DateTime.time
                                font.features: { "tnum": 1 }
                                font.letterSpacing: -0.4
                            }
                        }
                    }
                }

                Rectangle {
                    visible: pill.ampm !== ""
                    z: 1
                    implicitWidth: ampmText.implicitWidth + 8
                    implicitHeight: 24
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colTertiaryContainer
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -13
                    StyledText {
                        id: ampmText
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                        text: pill.ampm
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        ClockWidgetPopup {
            hoverTarget: mouseArea
            today: root.today
        }
    }
}