import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: xw
    required property Item di
    spacing: 16
    implicitWidth: 320
    readonly property real wantedWidth: 320

    readonly property int group: Math.floor((Weather.data?.wCode ?? 800) / 100)

    MaterialSymbol {
        text: {
            switch (xw.group) {
                case 2: return "thunderstorm"
                case 3: return "rainy_light"
                case 5: return "rainy"
                case 6: return "weather_snowy"
                case 7: return "foggy"
                default: return (Weather.data?.wCode ?? 800) === 800 ? "clear_day" : "cloud"
            }
        }
        iconSize: 52
        fill: 1
        color: Appearance.colors.colPrimary
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: Weather.data?.temp ?? ""
            font.pixelSize: 30
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            Layout.fillWidth: true
            text: `${Weather.data?.description ?? ""} · ${Weather.data?.city ?? ""}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.8
            elide: Text.ElideRight
        }
        StyledText {
            text: `${Translation.tr("Feels like")} ${Weather.data?.tempFeelsLike ?? ""} · 💧 ${Weather.data?.humidity ?? ""} · ${Weather.data?.wind ?? ""}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
        }
    }
}
