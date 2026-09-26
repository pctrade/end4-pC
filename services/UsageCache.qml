pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    property var pendingSnapshots: ({})
    signal snapshotUpdated(string providerId)

    function asArray(value) {
        if (Array.isArray(value))
            return value.slice()

        // JsonAdapter restores list<var> values as a list-like QML object,
        // rather than a JavaScript Array, after a shell restart.
        if (!value || typeof value !== "object")
            return []

        const length = Number(value.length)
        if (!Number.isInteger(length) || length < 0)
            return []

        const values = []
        for (let index = 0; index < length; index++)
            values.push(value[index])
        return values
    }

    function numberOr(value, fallback) {
        const number = Number(value)
        return Number.isFinite(number) ? number : fallback
    }

    function clampPercent(value) {
        const number = root.numberOr(value, -1)
        return number >= 0 && number <= 100 ? Math.round(number) : -1
    }

    function normalizeWindows(windows) {
        return root.asArray(windows).map(window => ({
            id: String(window?.id ?? "usage"),
            label: String(window?.label ?? "Usage"),
            remainingPercent: root.clampPercent(window?.remainingPercent),
            resetAt: Math.max(0, root.numberOr(window?.resetAt, 0)),
            windowDurationMins: Math.max(0, root.numberOr(window?.windowDurationMins, 0)),
        })).filter(window => window.remainingPercent >= 0)
    }

    function normalizeSnapshot(providerId, value) {
        if (!providerId || !value || typeof value !== "object")
            return null

        const windows = root.normalizeWindows(value.windows)
        const fallbackRemaining = root.clampPercent(value.remainingPercent)
        const remainingPercent = windows.length > 0
            ? Math.min(...windows.map(window => window.remainingPercent))
            : fallbackRemaining

        if (remainingPercent < 0)
            return null

        return {
            providerId: String(providerId),
            savedAt: Math.max(0, root.numberOr(value.savedAt, Math.floor(Date.now() / 1000))),
            planType: String(value.planType ?? ""),
            remainingPercent,
            resetAt: Math.max(0, root.numberOr(value.resetAt, 0)),
            windows,
        }
    }

    function storedSnapshots() {
        const snapshotsByProvider = ({})
        root.asArray(Persistent.states?.usage?.snapshots).forEach(entry => {
            const snapshot = root.normalizeSnapshot(String(entry?.providerId ?? ""), entry)
            if (snapshot)
                snapshotsByProvider[snapshot.providerId] = snapshot
        })
        return Object.keys(snapshotsByProvider).map(providerId => snapshotsByProvider[providerId])
    }

    function expireSnapshot(snapshot, now) {
        const normalized = root.normalizeSnapshot(snapshot?.providerId ?? "cached", snapshot)
        if (!normalized)
            return null

        const currentTime = root.numberOr(now, Math.floor(Date.now() / 1000))
        const windows = normalized.windows.map(window => {
            if (window.resetAt > 0 && window.resetAt <= currentTime) {
                return Object.assign({}, window, {
                    remainingPercent: 100,
                    resetAt: 0,
                })
            }
            return window
        })

        const remainingPercent = windows.length > 0
            ? Math.min(...windows.map(window => window.remainingPercent))
            : (normalized.resetAt > 0 && normalized.resetAt <= currentTime
                ? 100
                : normalized.remainingPercent)
        const futureResets = [normalized.resetAt]
            .concat(windows.map(window => window.resetAt))
            .filter(resetAt => resetAt > currentTime)

        return Object.assign({}, normalized, {
            remainingPercent,
            resetAt: futureResets.length > 0 ? Math.min(...futureResets) : 0,
            windows,
        })
    }

    function nextResetAt(snapshot, now) {
        const normalized = root.normalizeSnapshot(snapshot?.providerId ?? "cached", snapshot)
        if (!normalized)
            return 0

        const currentTime = root.numberOr(now, Math.floor(Date.now() / 1000))
        const futureResets = [normalized.resetAt]
            .concat(normalized.windows.map(window => window.resetAt))
            .filter(resetAt => resetAt > currentTime)
        return futureResets.length > 0 ? Math.min(...futureResets) : 0
    }

    function snapshotsMatch(left, right) {
        return JSON.stringify(left) === JSON.stringify(right)
    }

    function scheduleExpiry(snapshots, now) {
        const currentTime = root.numberOr(now, Math.floor(Date.now() / 1000))
        let nextReset = 0
        root.asArray(snapshots).forEach(snapshot => {
            const resetAt = root.nextResetAt(snapshot, currentTime)
            if (resetAt > 0 && (!nextReset || resetAt < nextReset))
                nextReset = resetAt
        })

        if (!nextReset) {
            resetTimer.stop()
            return
        }

        // A small delay ensures the provider's reset timestamp has passed
        // before the cached percentage is promoted to 100%.
        resetTimer.interval = Math.max(1, Math.min(2147483647,
            Math.ceil((nextReset - currentTime) * 1000) + 50))
        resetTimer.restart()
    }

    function expireStoredSnapshots(now) {
        const currentTime = root.numberOr(now, Math.floor(Date.now() / 1000))
        const current = root.storedSnapshots()
        const expired = current.map(snapshot => root.expireSnapshot(snapshot, currentTime))
        const changedProviderIds = expired
            .filter((snapshot, index) => !root.snapshotsMatch(snapshot, current[index]))
            .map(snapshot => snapshot.providerId)

        if (changedProviderIds.length > 0 && Persistent.ready) {
            Persistent.states.usage.snapshots = expired
            changedProviderIds.forEach(providerId => root.snapshotUpdated(providerId))
        }

        root.scheduleExpiry(expired, currentTime)
        return expired
    }

    function snapshot(providerId, now) {
        const stored = root.expireStoredSnapshots(now)
            .find(entry => entry?.providerId === providerId)
        return stored ?? null
    }

    function writeSnapshot(snapshot) {
        if (!Persistent.ready || !snapshot)
            return

        const next = root.storedSnapshots().filter(entry => entry?.providerId !== snapshot.providerId)
        next.push(snapshot)
        Persistent.states.usage.snapshots = next
        root.scheduleExpiry(next)
        root.snapshotUpdated(snapshot.providerId)
    }

    function save(providerId, value) {
        const normalized = root.normalizeSnapshot(providerId, Object.assign({}, value, {
            savedAt: Math.floor(Date.now() / 1000),
        }))
        const snapshot = root.expireSnapshot(normalized)
        if (!snapshot)
            return

        if (!Persistent.ready) {
            const pending = Object.assign({}, root.pendingSnapshots)
            pending[providerId] = snapshot
            root.pendingSnapshots = pending
            return
        }

        root.writeSnapshot(snapshot)
    }

    function flushPending() {
        if (!Persistent.ready)
            return

        const pending = root.pendingSnapshots
        root.pendingSnapshots = ({})
        Object.keys(pending).forEach(providerId => root.writeSnapshot(pending[providerId]))
    }

    Timer {
        id: resetTimer
        repeat: false
        onTriggered: root.expireStoredSnapshots()
    }

    Connections {
        target: Persistent

        function onReadyChanged() {
            if (Persistent.ready) {
                root.flushPending()
                root.expireStoredSnapshots()
            }
        }
    }

    Component.onCompleted: {
        if (Persistent.ready)
            Qt.callLater(root.expireStoredSnapshots)
    }
}
