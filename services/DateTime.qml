pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: {
            if (Config.options.time.secondPrecision || GlobalStates.screenLocked)
            return SystemClock.Seconds;
            return SystemClock.Minutes;
        }
    }

    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time.shortDateFormat ?? "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time.dateWithYearFormat ?? "dd/MM/yyyy")
    property string longDate: Qt.locale().toString(clock.date, Config.options?.time.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dddd, MMMM dd")
    readonly property bool use12HourFormat: (Config.options?.time.format ?? "hh:mm").toLowerCase().indexOf("ap") !== -1
    readonly property int hour24: clock.date.getHours()
    readonly property int hour12: (hour24 % 12 === 0) ? 12 : hour24 % 12
    readonly property string hourStr: (use12HourFormat ? hour12 : hour24).toString().padStart(2, "0")
    readonly property string minuteStr: Qt.locale().toString(clock.date, "mm")
    readonly property string digitH0: hourStr.charAt(0)
    readonly property string digitH1: hourStr.charAt(1)
    readonly property string digitM0: minuteStr.charAt(0)
    readonly property string digitM1: minuteStr.charAt(1)
    property string uptime: "0h, 0m"

    Timer {
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            fileUptime.reload();
            const textUptime = fileUptime.text();
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0);

            // Convert seconds to days, hours, and minutes
            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);

            // Build the formatted uptime string
            let formatted = "";
            if (days > 0)
                formatted += `${days}d`;
            if (hours > 0)
            formatted += `${formatted ? ", " : ""}${hours}h`;
            if (minutes > 0 || !formatted)
                formatted += `${formatted ? ", " : ""}${minutes}m`;
                uptime = formatted;
                interval = Config.options?.resources?.updateInterval ?? 3000;
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}