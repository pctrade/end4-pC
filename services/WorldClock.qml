pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property var cities: [
        { name: "Sydney",   baseOffset: 10, dstOffset: 11, dstRule: "AU" },
        { name: "Tokyo",    baseOffset: 9,  dstOffset: 9,  dstRule: "NONE" },
        { name: "London",   baseOffset: 0,  dstOffset: 1,  dstRule: "EU" },
        { name: "New York", baseOffset: -5, dstOffset: -4, dstRule: "US" }
    ]

    property bool use24h: Config.options?.time.format?.includes("HH") ?? true

    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function nthSunday(year, monthIndex, n) {
        let d = new Date(Date.UTC(year, monthIndex, 1));
        let day = d.getUTCDay();
        let firstSunday = 1 + ((7 - day) % 7);
        let date = firstSunday + (n - 1) * 7;
        return new Date(Date.UTC(year, monthIndex, date));
    }

    function lastSunday(year, monthIndex) {
        let lastDay = new Date(Date.UTC(year, monthIndex + 1, 0));
        let day = lastDay.getUTCDay();
        return new Date(Date.UTC(year, monthIndex, lastDay.getUTCDate() - day));
    }

    function isUSDST(date) {
        const year = date.getUTCFullYear();
        return date >= nthSunday(year, 2, 2) && date < nthSunday(year, 10, 1);
    }

    function isEUDST(date) {
        const year = date.getUTCFullYear();
        return date >= lastSunday(year, 2) && date < lastSunday(year, 9);
    }

    function isAUDST(date) {
        const year = date.getUTCFullYear();
        const aprFirst = nthSunday(year, 3, 1);
        const octFirst = nthSunday(year, 9, 1);
        return date < aprFirst || date >= octFirst;
    }

    function offsetHoursFor(city) {
        switch (city.dstRule) {
            case "US": return isUSDST(root.now) ? city.dstOffset : city.baseOffset;
            case "EU": return isEUDST(root.now) ? city.dstOffset : city.baseOffset;
            case "AU": return isAUDST(root.now) ? city.dstOffset : city.baseOffset;
            default:   return city.baseOffset;
        }
    }

    function cityDate(city) {
        const offset = offsetHoursFor(city);
        return new Date(root.now.getTime() + offset * 3600000);
    }

    function timeStringFor(cd) {
        let h = cd.getUTCHours();
        let m = cd.getUTCMinutes();
        if (!root.use24h) {
            let ampm = h >= 12 ? "PM" : "AM";
            let h12 = h % 12;
            if (h12 === 0) h12 = 12;
            return pad(h12) + ":" + pad(m) + " " + ampm;
        }
        return pad(h) + ":" + pad(m);
    }

    function offsetLabelFor(offset) {
        return "UTC" + (offset >= 0 ? "+" : "") + offset;
    }

    function isDaytimeFor(cd) {
        let h = cd.getUTCHours();
        return h >= 6 && h < 18;
    }

    property var entries: cities.map(c => {
        const cd = cityDate(c);
        const offset = offsetHoursFor(c);
        return {
            name: c.name,
            time: timeStringFor(cd),
            offset: offsetLabelFor(offset),
            isDay: isDaytimeFor(cd)
        };
    })
}