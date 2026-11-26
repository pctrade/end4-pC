import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    property var providers: []

    function formatTokens(count) {
        if (count >= 1000000) return `${(count / 1000000).toFixed(1)}M`;
        if (count >= 1000) return `${Math.round(count / 1000)}k`;
        return `${count}`;
    }

    function formatReset(usage) {
        if (usage.resetsAt <= 0) return Translation.tr("No usage in this window");
        const seconds = Math.max(0, usage.resetsAt - Date.now() / 1000);
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return Translation.tr("Resets in %1").arg(h > 0 ? `${h}h ${m}m` : `${m}m`);
    }

    ColumnLayout {
        spacing: 10

        Repeater {
            model: root.providers
            delegate: ColumnLayout {
                id: provider
                required property var modelData
                spacing: 10
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 3
                    spacing: 7

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer

                        CustomIcon {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: provider.modelData.icon
                            colorize: true
                            color: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -3

                        StyledText {
                            text: provider.modelData.name
                            font {
                                weight: Font.Medium
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                            opacity: 0.6
                            text: provider.modelData.codex && !provider.modelData.usage.available ? Translation.tr("No usage data yet") : root.formatReset(provider.modelData.usage)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        Layout.rightMargin: 8
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        color: Appearance.colors.colPrimary
                        text: provider.modelData.codex && !provider.modelData.usage.available ? "—" : `${Math.round(provider.modelData.usage.percentage * 100)}%`
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    valueBarWidth: 260
                    value: provider.modelData.usage.percentage
                }

                StyledPopupValueRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    icon: "token"
                    visible: !provider.modelData.codex
                    label: Translation.tr("Tokens (estimate)")
                    value: provider.modelData.codex ? "" : `${root.formatTokens(provider.modelData.usage.tokens)} / ${root.formatTokens(provider.modelData.usage.tokenLimit)}`
                }

                StyledPopupValueRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: !provider.modelData.codex && provider.modelData.usage.activeSessions === 0
                    icon: "bedtime"
                    label: Translation.tr("No active sessions")
                    value: ""
                }

                Repeater {
                    model: provider.modelData.codex ? [] : provider.modelData.usage.sessions
                    delegate: StyledPopupValueRow {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        icon: modelData.status === "busy" ? "progress_activity" : "terminal"
                        label: modelData.name
                        value: modelData.status === "busy" ? Translation.tr("Working") : Translation.tr("Idle")
                    }
                }
                StyledPopupValueRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: provider.modelData.codex && provider.modelData.usage.weeklyResetsAt > 0
                    icon: "date_range"
                    label: Translation.tr("Weekly usage")
                    value: provider.modelData.codex ? `${Math.round(provider.modelData.usage.weeklyPercentage * 100)}%` : ""
                }
            }
        }
    }
}
