pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

Singleton {
    id: root

    readonly property var definitions: [
        {
            id: "codex",
            name: Translation.tr("Codex"),
            icon: "openai-symbolic",
            service: CodexUsageService,
            url: "https://chatgpt.com/codex/settings/usage",
        },
        {
            id: "claude",
            name: Translation.tr("Claude Code"),
            icon: "claude-symbolic",
            service: ClaudeUsageService,
            url: "https://claude.ai/settings/usage",
        },
        {
            id: "antigravity",
            name: Translation.tr("Antigravity"),
            icon: "antigravity-symbolic",
            service: AntigravityUsageService,
            url: "https://antigravity.google/",
        },
    ]

    readonly property var selectedProviderIds: Config.options?.bar?.usageProviders ?? ["codex", "claude", "antigravity"]
    readonly property var activeProviders: definitions.filter(provider =>
        root.selectedProviderIds.includes(provider.id))
}
