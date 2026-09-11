pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property real cardSpacing: 4
    property real minimumCardWidth: 160
    readonly property var providers: UsageProviders.sidebarProviders
    readonly property bool useTwoColumns: root.providers.length > 1
        && root.width >= root.minimumCardWidth * 2 + root.cardSpacing
    readonly property var providerRows: root.buildRows()

    function contentHeightKey(provider) {
        const service = provider?.service
        const windows = UsageDisplay.windowEntries(
            service?.windows ?? [],
            service?.available ?? false,
            service?.remainingPercent ?? -1,
            service?.resetAt ?? 0,
        )
        return windows.length > 0 ? `limits-${windows.length}` : "status"
    }

    function buildRows() {
        const remaining = root.providers.map(provider => ({
            provider,
            heightKey: root.contentHeightKey(provider),
        }))
        if (!root.useTwoColumns)
            return remaining.map(entry => [entry.provider])

        const rows = []
        while (remaining.length > 0) {
            const first = remaining.shift()
            let matchingIndex = -1
            for (let index = 0; index < remaining.length; index++) {
                if (remaining[index].heightKey === first.heightKey) {
                    matchingIndex = index
                    break
                }
            }

            if (matchingIndex >= 0)
                rows.push([first.provider, remaining.splice(matchingIndex, 1)[0].provider])
            else
                rows.push([first.provider])
        }
        return rows
    }

    visible: root.providers.length > 0
    implicitHeight: usageGrid.implicitHeight

    component UsageRow: Item {
        id: row

        required property var rowProviders
        property real cardSpacing: root.cardSpacing
        readonly property int providerCount: row.rowProviders.length
        readonly property bool isFullWidth: row.providerCount === 1
        readonly property real cardWidth: row.isFullWidth
            ? row.width
            : Math.floor((row.width - row.cardSpacing) / 2)
        readonly property real contentHeight: {
            let tallest = 0
            for (let index = 0; index < cards.count; index++) {
                const card = cards.itemAt(index)
                if (card)
                    tallest = Math.max(tallest, card.implicitHeight)
            }
            return tallest
        }

        implicitHeight: row.contentHeight
        height: row.contentHeight

        Repeater {
            id: cards
            model: row.rowProviders

            delegate: UsageProviderCard {
                required property var modelData
                required property int index

                x: index * (row.cardWidth + row.cardSpacing)
                width: row.cardWidth
                height: Math.max(row.contentHeight, implicitHeight)
                provider: modelData
                accentColor: Appearance.colors.colPrimary
                horizontalTwoWindows: row.isFullWidth
            }
        }
    }

    Column {
        id: usageGrid

        width: root.width
        spacing: root.cardSpacing

        Repeater {
            model: root.providerRows

            delegate: UsageRow {
                required property var modelData

                width: usageGrid.width
                rowProviders: modelData
                cardSpacing: root.cardSpacing
            }
        }
    }
}
