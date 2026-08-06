import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcher {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.time.showDate
    property var today: new Date()
    readonly property string dateTimeString: DateTime.time
    readonly property bool hasAmPm: dateTimeString.toLowerCase().includes("am") || dateTimeString.toLowerCase().includes("pm")

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    colDefault: Component {
        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: root.hasAmPm ? 1 : 0

            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -4

                Repeater {
                    model: root.dateTimeString.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
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

    colMaterial: Component {
        ColumnLayout {
            id: clockWidget
            spacing: 2
            Layout.alignment: Qt.AlignHCenter

            Column {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: -4

                Repeater {
                    model: DateTime.time.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
                        font.pixelSize: modelData.match(/am|pm/i)
                            ? Appearance.font.pixelSize.smallest - 2
                            : Appearance.font.pixelSize.small
                        color: Appearance.colors.colPrimary
                        text: modelData.padStart(2, "0")
                    }
                }
            }

            Rectangle {
                width: 25
                height: 25
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignHCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 0
                    text: "calendar_clock"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    rowDefault: Component {
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

    rowMaterial: Component {
        RowLayout {
            spacing: 4
            id: pill

            property var timeParts: DateTime.time.split(/[: ]/)
            property string ampm: timeParts.find(part => /^(am|pm)$/i.test(part)) ?? ""
            property string time: timeParts.filter(part => !/^(am|pm)$/i.test(part)).join(":")

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
                    text: pill.time
                    font.features: { "tnum": 1 }
                    font.letterSpacing: -0.4
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
                Layout.leftMargin: -10
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
