pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color colText: Appearance.colors.colOnSurface
    // The desktop widget, for the bento tiles' glass
    property Item widget: null
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

    readonly property real bentoWidth: 400
    readonly property real bentoGap: 8
    readonly property real bentoThird: (root.bentoWidth - root.bentoGap * 2) / 3

    // Weather formats sunrise and sunset in the system locale ("06:42" or "6:42 AM"); today's Date, or null
    function todayAt(timeText) {
        const m = /(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)?/i.exec(timeText ?? "");
        if (!m) return null;
        let hours = Number(m[1]);
        if (m[3]) hours = hours % 12 + (m[3].toUpperCase() === "PM" ? 12 : 0);
        const d = new Date(root.now);
        d.setHours(hours, Number(m[2]), 0, 0);
        return d;
    }

    implicitWidth: loader.item?.implicitWidth ?? 0
    implicitHeight: loader.item?.implicitHeight ?? 0

    Loader {
        id: loader
        sourceComponent: {
            switch (root.variant) {
            case "morning": return morning;
            case "script": return script;
            case "bold": return bold;
            case "bento": return bento;
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

    // Bento tiles
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

    // Material You tiles, in the spirit of the Pixel home screen widgets
    Component {
        id: bento
        ColumnLayout {
            id: bentoRoot
            readonly property real gap: root.bentoGap
            readonly property real third: root.bentoThird
            readonly property bool hasWeather: (Weather.data?.temp ?? "") !== ""
            readonly property var sunrise: root.todayAt(Weather.data?.sunrise)
            readonly property var sunset: root.todayAt(Weather.data?.sunset)
            readonly property bool hasSun: bentoRoot.sunrise !== null && bentoRoot.sunset !== null
            readonly property var pendingTodos: Todo.list.filter(item => !item.done)
            readonly property var player: MprisController.activePlayer
            readonly property bool hasMedia: (bentoRoot.player?.trackTitle ?? "") !== ""

            implicitWidth: root.bentoWidth
            spacing: bentoRoot.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: bentoRoot.gap

                // Time and date
                BentoTile {
                    widget: root.widget
                    Layout.preferredWidth: bentoRoot.third * 2 + bentoRoot.gap
                    implicitHeight: 156
                    color: Appearance.colors.colPrimaryContainer
                    ColumnLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 18
                        }
                        spacing: 0
                        StyledText {
                            text: root.greeting
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        // The pixel clock's overlapping digits, at the tile's size
                        PixelClock {
                            Layout.topMargin: 2
                            Layout.bottomMargin: 4
                            Layout.leftMargin: -6
                            implicitWidth: 230
                            implicitHeight: 82
                            isVertical: false
                            wallpaperItem: root.widget?.wallpaperItem ?? null
                            blurWidgets: false
                            tintSoft: Appearance.colors.colOnPrimaryContainer
                            tintBold: Appearance.colors.colTertiary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Qt.locale().toString(root.now, "dddd d MMMM")
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnPrimaryContainer
                            font {
                                pixelSize: Appearance.font.pixelSize.normal
                                weight: 500
                            }
                        }
                    }
                }

                // Weather now: the condition, a big temperature and where
                BentoTile {
                    widget: root.widget
                    visible: bentoRoot.hasWeather
                    Layout.preferredWidth: bentoRoot.third
                    implicitHeight: 156
                    color: Appearance.colors.colTertiaryContainer
                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: 14
                        }
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            MaterialShapeWrappedMaterialSymbol {
                                Layout.alignment: Qt.AlignTop
                                shape: MaterialShape.Shape.Cookie12Sided
                                color: Appearance.colors.colTertiary
                                colSymbol: Appearance.colors.colOnTertiary
                                text: root.weatherIcon
                                fill: 1
                                iconSize: 26
                                padding: 10
                                implicitWidth: 48
                                implicitHeight: 48
                            }
                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                horizontalAlignment: Text.AlignRight
                                text: Weather.data?.city ?? ""
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnTertiaryContainer
                                opacity: 0.7
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }
                        Item { Layout.fillHeight: true }
                        StyledText {
                            // "25°C" reads bigger as "25°"
                            text: (Weather.data?.temp ?? "").replace(/°[CF]$/, "°")
                            color: Appearance.colors.colOnTertiaryContainer
                            font {
                                family: "Google Sans Flex"
                                pixelSize: 46
                                weight: 900
                                variableAxes: ({ "wght": 900 })
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const d = Weather.data?.description ?? "";
                                return d.charAt(0).toUpperCase() + d.slice(1);
                            }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 0.9
                            color: Appearance.colors.colOnTertiaryContainer
                            opacity: 0.8
                            font.pixelSize: Appearance.font.pixelSize.smallest
                        }
                    }
                }
            }

            // Weather details, each with its own picture of the value
            RowLayout {
                id: details
                visible: bentoRoot.hasWeather
                Layout.fillWidth: true
                spacing: bentoRoot.gap

                readonly property real temp: parseFloat(Weather.data?.temp ?? "")
                readonly property real feels: parseFloat(Weather.data?.tempFeelsLike ?? "")
                readonly property real feelsDelta: isNaN(temp) || isNaN(feels) ? 0 : feels - temp
                function compass(degrees) {
                    const points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
                    return points[Math.round(((degrees % 360) + 360) % 360 / 45) % 8];
                }

                BentoStatTile {
                    widget: root.widget
                    Layout.preferredWidth: bentoRoot.third
                    icon: "water_drop"
                    value: Weather.data?.humidity ?? ""
                    label: Translation.tr("Humidity")
                    gauge: (parseFloat(Weather.data?.humidity ?? "") || 0) / 100
                }
                BentoStatTile {
                    widget: root.widget
                    Layout.preferredWidth: bentoRoot.third
                    readonly property bool calm: (parseFloat(Weather.data?.wind ?? "") || 0) === 0
                    // The arrow points where the wind blows to; no wind, no direction
                    icon: calm ? "air" : "navigation"
                    iconRotation: calm ? 0 : ((Weather.data?.windDir ?? 0) + 180) % 360
                    // "3.14 m/s" does not fit a third of the widget
                    value: (Weather.data?.wind ?? "").replace(/^(\d+\.\d)\d+/, "$1")
                    label: calm ? Translation.tr("Calm") : `${Translation.tr("Wind")} · ${details.compass(Weather.data?.windDir ?? 0)}`
                }
                BentoStatTile {
                    widget: root.widget
                    Layout.preferredWidth: bentoRoot.third
                    icon: "thermostat"
                    value: Weather.data?.tempFeelsLike ?? ""
                    label: details.feelsDelta >= 2 ? Translation.tr("Feels warmer")
                        : details.feelsDelta <= -2 ? Translation.tr("Feels colder")
                        : Translation.tr("Feels like")
                    colAccent: details.feelsDelta >= 2 ? Appearance.colors.colTertiaryContainer
                        : details.feelsDelta <= -2 ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSecondaryContainer
                    colOnAccent: details.feelsDelta >= 2 ? Appearance.colors.colOnTertiaryContainer
                        : details.feelsDelta <= -2 ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnSecondaryContainer
                }
            }

            // The day in steps
            BentoDayTile {
                widget: root.widget
                visible: bentoRoot.hasSun
                sunrise: bentoRoot.sunrise ?? new Date()
                sunset: bentoRoot.sunset ?? new Date()
                now: root.now
            }

            // The next thing to do
            BentoStatTile {
                widget: root.widget
                visible: bentoRoot.pendingTodos.length > 0
                icon: "checklist"
                value: bentoRoot.pendingTodos[0]?.content ?? ""
                label: bentoRoot.pendingTodos.length > 1
                    ? Translation.tr("%1 more to do").arg(bentoRoot.pendingTodos.length - 1)
                    : Translation.tr("To do")
                colAccent: Appearance.colors.colPrimaryContainer
                colOnAccent: Appearance.colors.colOnPrimaryContainer
            }

            // Now playing
            BentoMediaTile {
                widget: root.widget
                visible: bentoRoot.hasMedia
                player: bentoRoot.player
            }
        }
    }
}
