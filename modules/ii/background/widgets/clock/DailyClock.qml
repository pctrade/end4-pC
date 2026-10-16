pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color colText: Appearance.colors.colOnSurface
    readonly property string variant: Config.options.background.widgets.clock.daily.variant
    readonly property date now: DateTime.clock.date
    readonly property string greeting: {
        const h = DateTime.hour24;
        if (h < 6) return Translation.tr("Good night");
        if (h < 12) return Translation.tr("Good morning");
        if (h < 19) return Translation.tr("Good afternoon");
        return Translation.tr("Good evening");
    }
    readonly property string weatherLine: {
        const d = Weather.data;
        if (!d?.temp) return "";
        return Translation.tr("Currently %1 with humidity %2 and wind %3.").arg(d.temp).arg(d.humidity ?? "").arg(d.wind ?? "");
    }
    readonly property string batteryLine: Battery.available ? Translation.tr("Battery %1% left").arg(Math.round(Battery.percentage * 100)) : ""
    readonly property string weatherIcon: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"

    implicitWidth: loader.item?.implicitWidth ?? 0
    implicitHeight: loader.item?.implicitHeight ?? 0

    Loader {
        id: loader
        sourceComponent: {
            switch (root.variant) {
            case "morning": return morning;
            case "script": return script;
            case "bold": return bold;
            default: return badge;
            }
        }
    }

    component Txt: ClockText {
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignVCenter
        color: root.colText
    }

    component Badge: MaterialShapeWrappedMaterialSymbol {
        shape: MaterialShape.Shape.Cookie12Sided
        color: Appearance.colors.colSecondaryContainer
        colSymbol: Appearance.colors.colOnSecondaryContainer
        text: root.weatherIcon
        fill: 1
        padding: 10
    }

    component TimePill: Rectangle {
        implicitWidth: timeLabel.implicitWidth + 56
        implicitHeight: 52
        radius: height / 2
        color: Appearance.colors.colSecondaryContainer
        StyledText {
            id: timeLabel
            anchors.centerIn: parent
            text: DateTime.time
            color: Appearance.colors.colOnSecondaryContainer
            font {
                pixelSize: Appearance.font.pixelSize.larger
                weight: 600
            }
        }
    }

    component Rule: Rectangle {
        implicitWidth: 90
        implicitHeight: 2
        color: root.colText
        opacity: 0.6
    }

    Component {
        id: badge
        ColumnLayout {
            spacing: 14
            Badge {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130
                iconSize: 64
                padding: 20
                implicitWidth: 130
                implicitHeight: 130
            }
            RowLayout {
                spacing: 10
                Txt {
                    text: Qt.locale().toString(root.now, "dd")
                    font {
                        pixelSize: 64
                        weight: 500
                    }
                }
                ColumnLayout {
                    spacing: -4
                    Txt {
                        text: Qt.locale().toString(root.now, "ddd")
                        font.pixelSize: 20
                    }
                    Txt {
                        text: Qt.locale().toString(root.now, "MMMM")
                        font.pixelSize: 20
                    }
                }
            }
            Txt {
                text: root.greeting
                font {
                    pixelSize: 38
                    weight: 300
                }
            }
            ColumnLayout {
                Layout.maximumWidth: 320
                spacing: 4
                visible: root.weatherLine.length > 0
                Txt {
                    text: Weather.data?.description ?? ""
                    font {
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: 500
                    }
                }
                Txt {
                    Layout.preferredWidth: 320
                    text: root.weatherLine
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
            RowLayout {
                spacing: 10
                Badge {
                    shape: MaterialShape.Shape.Cookie9Sided
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colOnPrimaryContainer
                    iconSize: 22
                    padding: 10
                    implicitWidth: 52
                    implicitHeight: 52
                }
                TimePill {}
            }
        }
    }

    Component {
        id: morning
        ColumnLayout {
            spacing: 10
            Txt {
                text: root.greeting
                font {
                    pixelSize: 56
                    weight: 300
                    italic: true
                    family: "cursive"
                }
            }
            Txt {
                Layout.preferredWidth: 300
                Layout.fillWidth: false
                wrapMode: Text.WordWrap
                text: Translation.tr("Today, it's %1 %2 of %3 with %4").arg(Qt.locale().toString(root.now, "dddd")).arg(Qt.locale().toString(root.now, "d")).arg(Qt.locale().toString(root.now, "MMMM")).arg(Weather.data?.description ?? "").toUpperCase()
                font {
                    pixelSize: 26
                    weight: 700
                }
            }
            Rule {}
            Txt {
                visible: root.batteryLine.length > 0
                text: root.batteryLine
                font.pixelSize: Appearance.font.pixelSize.small
            }
            RowLayout {
                spacing: 10
                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    shape: MaterialShape.Shape.Cookie9Sided
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colOnPrimaryContainer
                    text: "schedule"
                    iconSize: 16
                    padding: 6
                    implicitWidth: 28
                    implicitHeight: 28
                }
                Txt {
                    text: DateTime.time.split("").join(" ").toUpperCase()
                    font {
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: 600
                        letterSpacing: 3
                    }
                }
            }
        }
    }

    Component {
        id: script
        ColumnLayout {
            spacing: 12
            RowLayout {
                spacing: 10
                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    shape: MaterialShape.Shape.Cookie9Sided
                    color: Appearance.colors.colSecondaryContainer
                    colSymbol: Appearance.colors.colOnSecondaryContainer
                    text: "schedule"
                    iconSize: 22
                    padding: 8
                    implicitWidth: 40
                    implicitHeight: 40
                }
                Txt {
                    text: DateTime.time
                    font {
                        pixelSize: 28
                        weight: 600
                    }
                }
            }
            Txt {
                text: Qt.locale().toString(root.now, "dddd") + "."
                color: Appearance.colors.colPrimary
                font {
                    pixelSize: 84
                    italic: true
                    weight: 400
                    family: "cursive"
                }
            }
            Rectangle {
                implicitWidth: dateLabel.implicitWidth + 28
                implicitHeight: 32
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                StyledText {
                    id: dateLabel
                    anchors.centerIn: parent
                    text: Qt.locale().toString(root.now, "MMM. dd, yyyy")
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
            Txt {
                Layout.preferredWidth: 300
                Layout.fillWidth: false
                visible: root.weatherLine.length > 0
                wrapMode: Text.WordWrap
                text: root.weatherLine
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }
    }

    Component {
        id: bold
        Rectangle {
            implicitWidth: 300
            implicitHeight: boldColumn.implicitHeight + 48
            radius: Appearance.rounding.verylarge
            color: Appearance.colors.colPrimary
            ColumnLayout {
                id: boldColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 24
                }
                spacing: 0
                StyledText {
                    text: Qt.locale().toString(root.now, "dd")
                    color: Appearance.colors.colOnPrimary
                    font {
                        pixelSize: Appearance.font.pixelSize.normal
                        weight: 700
                    }
                }
                StyledText {
                    text: Qt.locale().toString(root.now, "MMM") + "."
                    color: Appearance.colors.colOnPrimary
                    font {
                        pixelSize: 96
                        weight: 900
                    }
                }
                StyledText {
                    text: Translation.tr("Today's %1").arg(Qt.locale().toString(root.now, "dddd"))
                    color: Appearance.colors.colOnPrimary
                    font {
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: 700
                    }
                }
                StyledText {
                    text: (Weather.data?.temp ?? "") + " " + (Weather.data?.description ?? "")
                    color: Appearance.colors.colOnPrimary
                    opacity: 0.8
                }
                RowLayout {
                    spacing: 12
                    StyledText {
                        text: DateTime.time
                        color: Appearance.colors.colOnPrimary
                        opacity: 0.8
                    }
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 2
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }
}
