import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string style: "bar"
    property real percentage: 0.78
    property bool isCharging: false
    property bool isLow: false
    property bool showPercentage: true
    property bool showCharging: true
    property bool vertical: false
    property color contentColor: Appearance.colors.colOnSecondaryContainer

    readonly property bool showBolt: root.showCharging && root.isCharging && root.percentage < 1
    readonly property int percentValue: Math.round(root.percentage * 100)
    readonly property string numberText: root.showPercentage ? String(root.percentValue) : ""
    readonly property color accentColor: (root.isLow && !root.isCharging) ? Appearance.m3colors.m3error : root.contentColor
    readonly property string levelIcon: {
        const level = Math.min(6, Math.floor(root.percentage * 7));
        return root.percentage >= 0.97 ? "battery_android_full" : `battery_android_${level}`;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Loader {
        id: content
        anchors.centerIn: parent
        sourceComponent: root.style === "ios" ? iosComponent
            : root.style === "macos" ? macosComponent
            : root.style === "windows" ? windowsComponent
            : root.style === "ring" ? ringComponent
            : root.style === "icon" ? iconComponent
            : root.style === "number" ? numberComponent
            : barComponent
    }

    Component {
        id: barComponent

        Item {
            implicitWidth: root.vertical ? batteryProgress.valueBarHeight + 8 : batteryProgress.valueBarWidth
            implicitHeight: root.vertical ? batteryProgress.valueBarWidth : batteryProgress.valueBarHeight

            ClippedProgressBar {
                id: batteryProgress
                anchors.centerIn: parent
                value: root.percentage
                text: root.numberText
                rotation: root.vertical ? -90 : 0
                highlightColor: root.accentColor

                Item {
                    anchors.centerIn: parent
                    width: batteryProgress.valueBarWidth
                    height: batteryProgress.valueBarHeight

                    Loader {
                        active: !root.vertical
                        visible: active
                        anchors.centerIn: parent
                        sourceComponent: RowLayout {
                            spacing: 0
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.topMargin: 2
                                Layout.leftMargin: -2
                                Layout.rightMargin: -2
                                fill: 1
                                text: "bolt"
                                iconSize: Appearance.font.pixelSize.smaller
                                visible: root.showBolt
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.topMargin: 2
                                font: batteryProgress.font
                                text: root.numberText
                            }
                        }
                    }

                    Loader {
                        active: root.vertical
                        visible: active
                        anchors.centerIn: parent
                        sourceComponent: ColumnLayout {
                            rotation: 90
                            spacing: -7
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                fill: 1
                                text: "bolt"
                                Layout.topMargin: 4
                                iconSize: Appearance.font.pixelSize.smaller
                                visible: root.showBolt
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: root.showBolt ? 2 : 4
                                font: batteryProgress.font
                                text: root.numberText
                                visible: root.percentage < 1 && root.showPercentage
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ringComponent

        Item {
            implicitWidth: 30
            implicitHeight: 30

            CircularProgress {
                anchors.centerIn: parent
                implicitSize: 28
                lineWidth: 3
                value: root.percentage
                colPrimary: root.accentColor
                colSecondary: Qt.alpha(root.accentColor, 0.25)
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.showPercentage && !root.showBolt
                text: root.numberText
                font.pixelSize: root.percentValue > 99 ? 9 : 11
                font.weight: Font.DemiBold
                color: root.accentColor
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.showBolt || (!root.showPercentage && root.isCharging)
                text: "bolt"
                fill: 1
                iconSize: 16
                color: root.accentColor
            }
        }
    }

    Component {
        id: iconComponent

        GridLayout {
            columns: root.vertical ? 1 : 2
            rowSpacing: 0
            columnSpacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignCenter
                fill: 1
                text: root.showBolt ? "battery_android_bolt" : root.levelIcon
                iconSize: Appearance.font.pixelSize.huge
                color: root.accentColor
                rotation: root.vertical ? 0 : 0
            }
            StyledText {
                Layout.alignment: Qt.AlignCenter
                visible: root.showPercentage && !(root.vertical && root.percentage > 0.99)
                text: root.numberText
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: root.accentColor
            }
        }
    }

    Component {
        id: numberComponent

        RowLayout {
            spacing: 1

            MaterialSymbol {
                visible: root.showBolt
                fill: 1
                text: "bolt"
                iconSize: Appearance.font.pixelSize.small
                color: root.accentColor
            }
            StyledText {
                text: root.showPercentage ? String(root.percentValue) : (root.showBolt ? "" : String(root.percentValue))
                font.pixelSize: root.vertical && root.percentValue > 99 ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: root.accentColor
            }
        }
    }

    Component {
        id: iosComponent

        Item {
            implicitWidth: root.vertical ? 34 : 34
            implicitHeight: 18

            Rectangle {
                id: iosBody
                width: 30
                height: 16
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.contentColor, 0.28)

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.height, parent.width * root.percentage)
                    radius: parent.radius
                    color: root.isCharging ? Appearance.m3colors.m3success : (root.isLow ? "#E3C65A" : root.contentColor)
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.showPercentage && !root.showBolt
                    text: root.numberText
                    font.pixelSize: root.percentValue > 99 ? 9 : 11
                    font.weight: Font.Bold
                    color: Appearance.m3colors.m3surface
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: root.showBolt
                    text: "bolt"
                    fill: 1
                    iconSize: 13
                    color: Appearance.m3colors.m3surface
                }
            }
            Rectangle {
                anchors.left: iosBody.right
                anchors.leftMargin: 1
                anchors.verticalCenter: iosBody.verticalCenter
                width: 2
                height: 6
                radius: 1
                color: Qt.alpha(root.contentColor, 0.45)
            }
        }
    }

    Component {
        id: macosComponent

        RowLayout {
            spacing: 4

            StyledText {
                visible: root.showPercentage
                text: root.numberText
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.contentColor
            }

            Item {
                implicitWidth: 27
                implicitHeight: 14

                Rectangle {
                    id: macBody
                    width: 24
                    height: 12
                    radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(root.contentColor, 0.6)

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                        width: Math.max(3, (parent.width - 3) * root.percentage)
                        radius: 2
                        color: root.isCharging ? Appearance.m3colors.m3success : root.accentColor
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: root.showBolt
                        text: "bolt"
                        fill: 1
                        iconSize: 11
                        color: Appearance.m3colors.m3surface
                    }
                }
                Rectangle {
                    anchors.left: macBody.right
                    anchors.leftMargin: 1
                    anchors.verticalCenter: macBody.verticalCenter
                    width: 2
                    height: 5
                    radius: 1
                    color: Qt.alpha(root.contentColor, 0.6)
                }
            }
        }
    }

    Component {
        id: windowsComponent

        RowLayout {
            spacing: 4

            Item {
                implicitWidth: 28
                implicitHeight: 16

                Rectangle {
                    id: winBody
                    width: 25
                    height: 14
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.contentColor

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 2 }
                        width: Math.max(2, (parent.width - 4) * root.percentage)
                        radius: 1
                        color: root.isCharging ? Appearance.m3colors.m3success : (root.isLow ? Appearance.m3colors.m3error : root.contentColor)
                    }
                }
                Rectangle {
                    anchors.left: winBody.right
                    anchors.verticalCenter: winBody.verticalCenter
                    width: 2.5
                    height: 6
                    radius: 1
                    color: root.contentColor
                }
            }

            MaterialSymbol {
                visible: root.showBolt
                text: "bolt"
                fill: 1
                iconSize: Appearance.font.pixelSize.small
                color: root.contentColor
            }
            StyledText {
                visible: root.showPercentage
                text: root.numberText
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.contentColor
            }
        }
    }
}
