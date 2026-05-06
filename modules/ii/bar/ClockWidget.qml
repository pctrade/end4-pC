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
                spacing: 0
                Repeater {
                    model: DateTime.time.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: modelData.match(/am|pm/i) ?
                            Appearance.font.pixelSize.smaller :
                            Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                        text: modelData.padStart(2, "0")
                    }
                }
            }
        }

        Component {
            id: colMaterial
            ColumnLayout {
                spacing: -4
                property var timeParts: DateTime.time.split(/[: ]/)
                property string hours: timeParts[0] ?? "00"
                property string minutes: timeParts[1] ?? "00"
                property string ampm: timeParts[2] ?? ""

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colPrimary
                    radius: Appearance.rounding.small
                    implicitWidth: 36
                    implicitHeight: 30
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                        text: parent.parent.hours.padStart(2, "0")
                        font.features: { "tnum": 1 }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: ":"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.small
                    rotation: 90
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.colors.colSecondaryContainer
                    radius: Appearance.rounding.small
                    implicitWidth: 36
                    implicitHeight: 30
                    StyledText {
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colPrimary
                        text: parent.parent.minutes.padStart(2, "0")
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
                spacing: 2
                property var timeParts: DateTime.time.split(/[: ]/)
                property string hours: timeParts[0] ?? "00"
                property string minutes: timeParts[1] ?? "00"
                property string ampm: timeParts[2] ?? ""

                Rectangle {
                    color: Appearance.colors.colPrimary
                    radius: Appearance.rounding.full
                    implicitWidth: hoursText.implicitWidth + 34
                    implicitHeight: 30
                    StyledText {
                        id: hoursText
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimary
                        text: parent.parent.hours.padStart(2, "0")
                        font.features: { "tnum": 1 }
                        font.letterSpacing: -0.4
                    }
                }

                StyledText {
                    text: ":"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: -6
                }

                Rectangle {
                    color: Appearance.colors.colSecondaryContainer
                    radius: Appearance.rounding.full
                    implicitWidth: minutesText.implicitWidth + 34
                    implicitHeight: 30
                    StyledText {
                        id: minutesText
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colPrimary
                        text: parent.parent.minutes.padStart(2, "0")
                        font.features: { "tnum": 1 }
                        font.letterSpacing: -0.4
                    }
                }

                Rectangle {
                    visible: parent.ampm !== ""
                    color: Appearance.colors.colTertiaryContainer
                    radius: Appearance.rounding.full
                    implicitWidth: ampmText.implicitWidth + 12
                    implicitHeight: 30
                    StyledText {
                        id: ampmText
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                        text: parent.parent.ampm
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