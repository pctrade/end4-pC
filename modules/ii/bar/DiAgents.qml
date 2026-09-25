import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The AI agents, pinned: one ring per agent with its 5h usage, and what they are doing right now
RowLayout {
    id: agents
    required property Item di
    anchors {
        fill: parent
        leftMargin: 8
        rightMargin: 12
    }
    spacing: 8

    readonly property var waiting: ClaudeCode.liveSessions.filter(s => s.state === "waiting")
    readonly property var working: ClaudeCode.liveSessions.filter(s => s.state === "working")
    readonly property real worstLimit: {
        let worst = -1
        for (const agent of ClaudeCode.openAgents) {
            const limit = ClaudeCode.limits[agent]
            if (limit) worst = Math.max(worst, limit.five)
        }
        return worst
    }
    // ONE mark for whichever agent needs attention most, not one per agent — a second near-identical mark
    // reads as a glitch, not as "two agents".
    readonly property string leadAgent: agents.waiting[0]?.agent ?? agents.working[0]?.agent ?? (ClaudeCode.openAgents[0] ?? "claude")

    Item {
        id: mark
        readonly property string modelData: agents.leadAgent
        readonly property real used: ClaudeCode.limits[mark.modelData]?.five ?? -1
        readonly property bool isWaiting: agents.waiting.some(s => s.agent === mark.modelData)
        implicitWidth: 24
        implicitHeight: 24

        CircularProgress {
            anchors.fill: parent
            visible: mark.used >= 0
            implicitSize: 24
            lineWidth: 2
            value: Math.max(0, Math.min(1, mark.used / 100))
            colPrimary: mark.used >= 95 ? IslandEvents.colorError
                : mark.used >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
            colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
        }

        DiClaudeIcon {
            anchors.centerIn: parent
            agent: mark.modelData
            size: 13
            color: mark.isWaiting ? IslandEvents.colorAttention : ClaudeCode.agentColor(mark.modelData)

            SequentialAnimation on scale {
                running: mark.isWaiting
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 1.25; duration: IslandMotion.long; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: IslandMotion.long; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            visible: ClaudeCode.openAgents.length > 1
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: -2
                bottomMargin: -2
            }
            implicitWidth: extraText.implicitWidth + 6
            implicitHeight: 13
            radius: 6.5
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0

            StyledText {
                id: extraText
                anchors.centerIn: parent
                text: `+${ClaudeCode.openAgents.length - 1}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: agents.waiting.length > 0 ? Translation.tr("Waiting for you")
                : agents.working.length > 0 ? Translation.tr("Working")
                : Translation.tr("AI agents")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: agents.waiting.length > 0 ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: {
                const session = agents.waiting[0] ?? agents.working[0] ?? ClaudeCode.liveSessions[0]
                if (session) return `${session.project ?? "~"}${session.detail ? " · " + session.detail : ""}`
                return ClaudeCode.openCount > 0 ? Translation.tr("%1 open").arg(ClaudeCode.openCount) : Translation.tr("None open")
            }
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    // The number that decides whether you can keep going today
    StyledText {
        visible: agents.worstLimit >= 0
        text: `${Math.round(agents.worstLimit)}%`
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: agents.worstLimit >= 95 ? IslandEvents.colorError
            : agents.worstLimit >= 80 ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
    }
}
