pragma Singleton
// From https://github.com/caelestia-dots/shell (GPLv3)
import Quickshell
import QtQml

Singleton {
    id: root

    function getBluetoothDeviceMaterialSymbol(systemIconName: string): string {
        if (systemIconName.includes("headset") || systemIconName.includes("headphones"))
            return "headphones";
        if (systemIconName.includes("audio"))
            return "speaker";
        if (systemIconName.includes("phone"))
            return "smartphone";
        if (systemIconName.includes("mouse"))
            return "mouse";
        if (systemIconName.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }

    function isNight(): bool {
        const hour = new Date().getHours();
        return hour < 6 || hour >= 20;
    }

    readonly property var weatherIconMap: ({
        "113": { day: "clear_day",         night: "clear_night" },
        "116": { day: "partly_cloudy_day", night: "partly_cloudy_night" },
        "119": { day: "cloud",             night: "cloud" },
        "122": { day: "cloud",             night: "cloud" },
        "143": { day: "foggy",             night: "foggy" },
        "176": { day: "rainy",             night: "rainy" },
        "179": { day: "rainy",             night: "rainy" },
        "182": { day: "rainy",             night: "rainy" },
        "185": { day: "rainy",             night: "rainy" },
        "200": { day: "thunderstorm",      night: "thunderstorm" },
        "227": { day: "cloudy_snowing",    night: "cloudy_snowing" },
        "230": { day: "snowing_heavy",     night: "snowing_heavy" },
        "248": { day: "foggy",             night: "foggy" },
        "260": { day: "foggy",             night: "foggy" },
        "263": { day: "rainy",             night: "rainy" },
        "266": { day: "rainy",             night: "rainy" },
        "281": { day: "rainy",             night: "rainy" },
        "284": { day: "rainy",             night: "rainy" },
        "293": { day: "rainy",             night: "rainy" },
        "296": { day: "rainy",             night: "rainy" },
        "299": { day: "rainy",             night: "rainy" },
        "302": { day: "weather_hail",      night: "weather_hail" },
        "305": { day: "rainy",             night: "rainy" },
        "308": { day: "weather_hail",      night: "weather_hail" },
        "311": { day: "rainy",             night: "rainy" },
        "314": { day: "rainy",             night: "rainy" },
        "317": { day: "rainy",             night: "rainy" },
        "320": { day: "cloudy_snowing",    night: "cloudy_snowing" },
        "323": { day: "cloudy_snowing",    night: "cloudy_snowing" },
        "326": { day: "cloudy_snowing",    night: "cloudy_snowing" },
        "329": { day: "snowing_heavy",     night: "snowing_heavy" },
        "332": { day: "snowing_heavy",     night: "snowing_heavy" },
        "335": { day: "snowing",           night: "snowing" },
        "338": { day: "snowing_heavy",     night: "snowing_heavy" },
        "350": { day: "rainy",             night: "rainy" },
        "353": { day: "rainy",             night: "rainy" },
        "356": { day: "rainy",             night: "rainy" },
        "359": { day: "weather_hail",      night: "weather_hail" },
        "362": { day: "rainy",             night: "rainy" },
        "365": { day: "rainy",             night: "rainy" },
        "368": { day: "cloudy_snowing",    night: "cloudy_snowing" },
        "371": { day: "snowing",           night: "snowing" },
        "374": { day: "rainy",             night: "rainy" },
        "377": { day: "rainy",             night: "rainy" },
        "386": { day: "thunderstorm",      night: "thunderstorm" },
        "389": { day: "thunderstorm",      night: "thunderstorm" },
        "392": { day: "thunderstorm",      night: "thunderstorm" },
        "395": { day: "snowing",           night: "snowing" }
    })

    function getWeatherIcon(code): string {
        const key = String(code);
        if (weatherIconMap.hasOwnProperty(key)) {
            const icons = weatherIconMap[key];
            return isNight() ? icons.night : icons.day;
        }
        return isNight() ? "clear_night" : "clear_day";
    }
}