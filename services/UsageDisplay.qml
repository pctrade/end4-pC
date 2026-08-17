pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    function usageText(available, loading, remainingPercent) {
        if (available)
            return `${remainingPercent}%`
        return loading ? "..." : "--"
    }

    function colorForRemaining(remainingPercent, accentColor, unavailableColor) {
        const remaining = Number(remainingPercent)
        if (!Number.isFinite(remaining) || remaining < 0)
            return unavailableColor
        if (remaining <= 10)
            return Appearance.m3colors.m3error
        if (remaining <= 25)
            return Appearance.colors.colTertiary
        return accentColor
    }

    function windowEntries(windows, available, remainingPercent, resetAt) {
        if (Array.isArray(windows) && windows.length > 0)
            return windows
        if (available) {
            return [{
                id: "usage",
                label: Translation.tr("Usage"),
                remainingPercent: remainingPercent,
                resetAt: resetAt,
            }]
        }
        return []
    }

    function resetText(service, resetAt, clockSeconds) {
        if (!resetAt || !service?.formatReset)
            return Translation.tr("Reset unavailable")
        return service.formatReset(Number(resetAt), Number(clockSeconds))
    }
}
