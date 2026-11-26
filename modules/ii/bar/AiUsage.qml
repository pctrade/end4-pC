import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    property bool vertical: false
    readonly property var providers: {
        const result = [];
        if (Config.options.bar.aiUsage.claudeEnabled)
            result.push({ name: "Claude Code", icon: "claude-symbolic", usage: ClaudeUsage, codex: false });
        if (Config.options.bar.aiUsage.codexEnabled)
            result.push({ name: "Codex", icon: "openai-symbolic", usage: CodexUsage, codex: true });
        return result;
    }

    visible: providers.length > 0
    implicitWidth: providers.length === 0 ? 0 : (vertical ? Appearance.sizes.verticalBarWidth : content.implicitWidth + 12)
    implicitHeight: providers.length === 0 ? 0 : (vertical ? content.implicitHeight + 10 : Appearance.sizes.barHeight)
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.providers.length
        columnSpacing: 10
        rowSpacing: 5

        Repeater {
            model: root.providers
            delegate: GridLayout {
                required property var modelData
                readonly property bool active: modelData.codex ? modelData.usage.available : modelData.usage.activeSessions > 0
                readonly property color providerColor: active ? root.contentColor : (root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.6) : Appearance.colors.colSubtext)
                columns: root.vertical ? 1 : 2
                columnSpacing: 5
                rowSpacing: 2

                CustomIcon {
                    Layout.alignment: Qt.AlignCenter
                    width: 15
                    height: 15
                    source: modelData.icon
                    colorize: true
                    color: providerColor
                }
                StyledText {
                    Layout.alignment: Qt.AlignCenter
                    text: modelData.codex && !modelData.usage.available ? "—" : `${Math.round(modelData.usage.percentage * 100)}%`
                    font.pixelSize: root.vertical ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    color: providerColor
                }
            }
        }
    }

    AiUsagePopup {
        hoverTarget: root
        providers: root.providers
    }
}
