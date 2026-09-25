import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: weather
    required property Item di
    anchors {
        fill: parent
        leftMargin: 8
        rightMargin: 12
    }
    spacing: 8

    // An alert when the weather turns; otherwise the current conditions (pinned island)
    readonly property bool alert: IslandEvents.weather.active
    readonly property var payload: IslandEvents.weather.payload ?? ({})
    readonly property int code: weather.alert ? (weather.payload.code ?? 500) : (Weather.data?.wCode ?? 800)
    readonly property int group: Math.floor(weather.code / 100)
    readonly property bool precipitation: [2, 3, 5, 6].includes(weather.group)

    function iconFor(code) {
        switch (Math.floor(code / 100)) {
            case 2: return "thunderstorm"
            case 3: return "rainy_light"
            case 5: return "rainy"
            case 6: return "weather_snowy"
            case 7: return "foggy"
            default:
                if (code !== 800) return "cloud"
                const hour = new Date().getHours()
                return hour >= 18 || hour < 6 ? "clear_night" : "clear_day"
        }
    }

    function alertText(g) {
        switch (g) {
            case 2: return Translation.tr("Storm starting")
            case 3: return Translation.tr("Drizzle starting")
            case 6: return Translation.tr("Snow starting")
            default: return Translation.tr("Rain starting")
        }
    }

    Item {
        implicitWidth: 24
        implicitHeight: 28
        clip: true

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            y: 0
            text: weather.iconFor(weather.code)
            iconSize: 18
            fill: 1
            color: Appearance.colors.colPrimary
        }

        Repeater {
            model: 0
            delegate: Rectangle {
                id: drop
                required property int index
                x: 6 + index * 5
                width: weather.group === 6 ? 3 : 1.5
                height: weather.group === 6 ? 3 : 5
                radius: width / 2
                color: Appearance.colors.colPrimary

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    PauseAnimation { duration: drop.index * 230 }
                    NumberAnimation { from: 16; to: 30; duration: weather.group === 6 ? 1300 : 650; easing.type: Easing.InQuad }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: {
            if (weather.alert) return weather.alertText(weather.group)
            const description = Weather.data?.description ?? ""
            return description !== "" ? description.charAt(0).toUpperCase() + description.slice(1) : (Weather.data?.city ?? "")
        }
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        elide: Text.ElideRight
    }

    StyledText {
        text: weather.alert ? (weather.payload.temp ?? "") : (Weather.data?.temp ?? "")
        font.pixelSize: Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}
