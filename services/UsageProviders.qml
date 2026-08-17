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
            name: Translation.tr("Claude"),
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
        {
            id: "zai",
            name: Translation.tr("GLM"),
            icon: "zai-symbolic",
            service: ZaiUsageService,
            url: "https://z.ai/manage-apikey/coding-plan/personal/my-plan",
        },
        {
            id: "kimi",
            name: Translation.tr("Kimi"),
            icon: "kimi-symbolic",
            service: KimiUsageService,
            url: "https://www.kimi.com/code/console",
        },
    ]

    readonly property var selectedProviderIds: Config.options?.bar?.usageProviders ?? ["codex", "claude", "antigravity", "zai", "kimi"]
    readonly property var activeProviders: definitions.filter(provider =>
        root.selectedProviderIds.includes(provider.id))
}
