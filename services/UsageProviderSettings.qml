pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property var defaultProviderIds: ["codex", "claude", "antigravity", "zai", "kimi", "cursor"]
    readonly property var barProviderIds: Config.options?.bar?.usageProviders ?? root.defaultProviderIds
    readonly property bool sidebarUsageEnabled: Config.options?.sidebar?.aiUsage?.enable ?? true
    readonly property var sidebarProviderIds: Config.options?.sidebar?.aiUsage?.providers ?? root.defaultProviderIds
    readonly property var enabledProviderIds: root.defaultProviderIds.filter(providerId =>
        root.barProviderIds.includes(providerId)
        || (root.sidebarUsageEnabled && root.sidebarProviderIds.includes(providerId)))

    function providerEnabled(providerId) {
        return root.enabledProviderIds.includes(providerId)
    }
}
