pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import QtQuick

/**
 * Token-based date/time formatter.  All tokens are matched greedily
 * (longest match first) so "EEEE" is consumed before "EEE" or "EE".
 *
 * Supported tokens (matching the custom-widget spec exactly):
 *   yyyy yy   year (4 / 2 digit)
 *   MMMM MMM MM M   month (full / short / padded / bare)
 *   dd d      day (padded / bare)
 *   EEEE EEE EE E   weekday (full / short)
 *   hh h      hour 12h (padded / bare)
 *   HH H      hour 24h (padded / bare)
 *   mm m      minute (padded / bare)
 *   ss s      second (padded / bare)
 *   a         AM/PM
 *
 * Anything else passes through literally.  Text wrapped in double quotes
 * is copied verbatim, so "HH" prints HH instead of the current hour.
 */
QtObject {
    id: root

    readonly property var _monthsFull: _monthNames(Locale.LongFormat)
    readonly property var _monthsShort: _monthNames(Locale.ShortFormat)
    readonly property var _daysFull: _dayNames(Locale.LongFormat)
    readonly property var _daysShort: _dayNames(Locale.ShortFormat)

    function _monthNames(format) {
        const locale = Qt.locale()
        const out = []
        for (let m = 0; m < 12; m++) out.push(locale.standaloneMonthName(m, format))
        return out
    }

    function _dayNames(format) {
        const locale = Qt.locale()
        // Jan 4 2026 is a Sunday; index the names by Date.getDay() (0=Sun).
        const out = []
        for (let d = 0; d < 7; d++) {
            const tmp = new Date(2026, 0, 4 + d)
            out.push(locale.standaloneDayName(tmp.getDay(), format))
        }
        return out
    }

    function format(date, pattern) {
        if (!date || !pattern) return pattern || ""
        if (isNaN(date.getTime())) return pattern

        const year = date.getFullYear()
        const month = date.getMonth()
        const day = date.getDate()
        const dow = date.getDay()
        const hours24 = date.getHours()
        const hours12 = hours24 % 12 === 0 ? 12 : hours24 % 12
        const minutes = date.getMinutes()
        const seconds = date.getSeconds()

        let result = ""
        let i = 0
        while (i < pattern.length) {
            // Double quotes escape their contents: "HH" -> HH, not the hour.
            if (pattern.charAt(i) === '"') {
                const close = pattern.indexOf('"', i + 1)
                if (close !== -1) {
                    result += pattern.substring(i + 1, close)
                    i = close + 1
                    continue
                }
            }
            let matched = false
            for (let len = 4; len >= 1; len--) {
                const token = pattern.substring(i, i + len)
                const replacement = root._resolveToken(token, year, month, day, dow, hours24, hours12, minutes, seconds)
                if (replacement !== null) {
                    result += replacement
                    i += len
                    matched = true
                    break
                }
            }
            if (!matched) {
                result += pattern.charAt(i)
                i++
            }
        }
        return result
    }

    function _resolveToken(token, year, month, day, dow, hours24, hours12, minutes, seconds) {
        switch (token) {
            case "yyyy": return String(year)
            case "yy":   return String(year).slice(-2)
            case "MMM":  return root._monthsShort[month]
            case "MMMM": return root._monthsFull[month]
            case "MM":   return root._pad(month + 1)
            case "M":    return String(month + 1)
            case "dd":   return root._pad(day)
            case "d":    return String(day)
            case "EEEE": return root._daysFull[dow]
            case "EEE":
            case "EE":
            case "E":    return root._daysShort[dow]
            case "hh":   return root._pad(hours12)
            case "h":    return String(hours12)
            case "HH":   return root._pad(hours24)
            case "H":    return String(hours24)
            case "mm":   return root._pad(minutes)
            case "m":    return String(minutes)
            case "ss":   return root._pad(seconds)
            case "s":    return String(seconds)
            case "a":    return hours24 >= 12 ? "PM" : "AM"
        }
        return null
    }

    function _pad(n) {
        return n < 10 ? "0" + n : String(n)
    }
}