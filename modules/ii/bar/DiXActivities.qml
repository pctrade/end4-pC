import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xact
    required property Item di
    spacing: 8
    implicitWidth: 390
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 390

    // A ColumnLayout takes its width from its children and ignores implicitWidth; this is what holds 390
    Item {
        Layout.preferredWidth: 390
        implicitHeight: 0
    }

    // Agent sessions have their own section; the plain list skips their activity entries
    readonly property var otherActivities: [...IslandEvents.activities].reverse()
        .filter(a => !a.id.startsWith("agent-") && a.id !== "agents-waiting")
    readonly property var limitAgents: ["claude", "codex", "gemini"].filter(a => ClaudeCode.limits[a] !== undefined)
    property double now: Date.now()

    Component.onCompleted: ClaudeCode.refreshWindows()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            xact.now = Date.now()
            ClaudeCode.refreshWindows()
        }
    }

    function agoText(ms) {
        const minutes = Math.floor(ms / 60000)
        if (minutes < 1) return Translation.tr("just now")
        if (minutes < 60) return Translation.tr("%1 min ago").arg(minutes)
        return Translation.tr("%1 h ago").arg(Math.floor(minutes / 60))
    }

    component SmallButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        property color tint: Appearance.colors.colPrimary
        property var onTap: () => {}
        implicitWidth: buttonRow.implicitWidth + 18
        implicitHeight: 28
        radius: 14
        color: buttonMouse.containsMouse ? ColorUtils.transparentize(button.tint, 0.7) : ColorUtils.transparentize(button.tint, 0.85)
        scale: buttonMouse.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                visible: button.icon !== ""
                text: button.icon
                iconSize: 15
                fill: 1
                color: button.tint
            }
            StyledText {
                Layout.maximumWidth: 300
                text: button.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.onTap()
        }
    }

    // AI agents: title, then each agent's plan usage as a small ring
    RowLayout {
        Layout.fillWidth: true
        visible: ClaudeCode.sessionList.length > 0 || xact.limitAgents.length > 0
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("AI agents")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }

        Repeater {
            model: xact.limitAgents
            delegate: RowLayout {
                id: limitChip
                required property string modelData
                readonly property var limit: ClaudeCode.limits[limitChip.modelData]
                readonly property real used: limitChip.limit?.five ?? 0
                spacing: 4

                Item {
                    implicitWidth: 20
                    implicitHeight: 20

                    CircularProgress {
                        anchors.fill: parent
                        implicitSize: 20
                        lineWidth: 2
                        value: Math.max(0, Math.min(1, limitChip.used / 100))
                        colPrimary: limitChip.used >= 95 ? IslandEvents.colorError : limitChip.used >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                        colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                    }
                    DiClaudeIcon {
                        anchors.centerIn: parent
                        agent: limitChip.modelData
                        size: 10
                    }
                }
                StyledText {
                    text: `${Math.round(limitChip.used)}%${limitChip.limit?.fiveReset ? ` · ${ClaudeCode.formatReset(limitChip.limit.fiveReset)}` : ""}`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: limitChip.used >= 80 ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
                    opacity: 0.85
                }
            }
        }
    }

    Repeater {
        model: ClaudeCode.sessionList
        delegate: Rectangle {
            id: session
            required property var modelData
            readonly property bool waiting: session.modelData.state === "waiting"
            readonly property bool working: session.modelData.state === "working"
            readonly property bool ended: session.modelData.state === "ended"
            readonly property bool alive: ClaudeCode.windowAlive(session.modelData)
            readonly property bool canType: session.alive && !session.ended
            readonly property color accent: session.waiting ? IslandEvents.colorAttention
                : session.working ? IslandEvents.colorProgress : Appearance.colors.colOnLayer1
            readonly property string diffText: ClaudeCode.formatDiff(session.modelData.diff)
            Layout.fillWidth: true
            implicitHeight: sessionColumn.implicitHeight + 18
            radius: 14
            color: session.waiting ? ColorUtils.transparentize(IslandEvents.colorAttention, 0.88) : Appearance.colors.colLayer1
            opacity: session.ended ? 0.7 : 1

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            ColumnLayout {
                id: sessionColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    // The agent's mark, with a small dot for its state
                    Item {
                        implicitWidth: 20
                        implicitHeight: 20

                        DiClaudeIcon {
                            anchors.centerIn: parent
                            agent: session.modelData.agent
                            size: 18
                        }
                        Rectangle {
                            visible: session.working || session.waiting
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                rightMargin: -2
                                bottomMargin: -2
                            }
                            width: 8
                            height: 8
                            radius: 4
                            color: session.accent
                            border.width: 1.5
                            border.color: Appearance.colors.colLayer1

                            SequentialAnimation on opacity {
                                running: session.working || session.waiting
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: -3

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: [session.modelData.project, session.modelData.model].filter(Boolean).join(" · ")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: session.waiting ? (session.modelData.question || session.modelData.waitingText || Translation.tr("Waiting for you"))
                                : session.working ? (session.modelData.detail || Translation.tr("Thinking…"))
                                : [session.ended ? Translation.tr("Closed · %1").arg(xact.agoText(xact.now - (session.modelData.updated ?? xact.now)))
                                    : Translation.tr("Idle · %1").arg(xact.agoText(xact.now - (session.modelData.updated ?? xact.now))),
                                   session.modelData.summary].filter(Boolean).join(" · ")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.75
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    SmallButton {
                        visible: session.canType
                        icon: "terminal"
                        label: Translation.tr("Open")
                        tint: session.waiting ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                        onTap: () => {
                            ClaudeCode.focusSession(session.modelData.key)
                            xact.di.collapse()
                        }
                    }
                    SmallButton {
                        visible: !session.canType && !session.working
                        icon: "replay"
                        label: Translation.tr("Resume session")
                        onTap: () => {
                            ClaudeCode.resume(session.modelData.key)
                            xact.di.collapse()
                        }
                    }
                }

                // Context window
                RowLayout {
                    Layout.fillWidth: true
                    visible: (session.modelData.context ?? -1) >= 0 && !session.ended
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

                        Rectangle {
                            width: parent.width * Math.min(1, Math.max(0, session.modelData.context) / 100)
                            height: parent.height
                            radius: 2
                            color: session.modelData.context >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary

                            Behavior on width {
                                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    StyledText {
                        text: Translation.tr("context %1%").arg(session.modelData.context)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }

                // What the last turn changed in the repository
                RowLayout {
                    Layout.fillWidth: true
                    visible: session.diffText !== "" && !session.working
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: session.diffText
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.8
                    }
                    SmallButton {
                        icon: "difference"
                        label: Translation.tr("View diff")
                        onTap: () => {
                            ClaudeCode.openDiff(session.modelData.key)
                            xact.di.collapse()
                        }
                    }
                }

                // A question from the agent: answer it right here (the number key goes to its terminal)
                Flow {
                    Layout.fillWidth: true
                    visible: session.waiting && session.canType && (session.modelData.options ?? []).length > 0
                    spacing: 6

                    Repeater {
                        model: session.modelData.options ?? []
                        delegate: SmallButton {
                            required property string modelData
                            required property int index
                            label: `${index + 1}. ${modelData}`
                            tint: IslandEvents.colorAttention
                            onTap: () => ClaudeCode.answer(session.modelData.key, index)
                        }
                    }
                }
            }
        }
    }

    StyledText {
        text: Translation.tr("Live activities")
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        visible: xact.otherActivities.length > 0 || ClaudeCode.sessionList.length === 0
    }

    // Empty state: says what would show up here
    ColumnLayout {
        Layout.fillWidth: true
        visible: xact.otherActivities.length === 0 && ClaudeCode.sessionList.length === 0
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Nothing running")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Long commands, downloads and AI agents show up here")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.5
            wrapMode: Text.Wrap
        }
    }

    Repeater {
        model: xact.otherActivities
        delegate: Rectangle {
            id: item
            required property var modelData
            readonly property var commandData: item.modelData.data ?? null
            readonly property bool isCommand: (item.commandData?.command ?? "") !== ""
            property bool showLog: false
            property string logText: ""
            readonly property color accent: item.modelData.state === "error" ? IslandEvents.colorError
                : item.modelData.state === "done" ? IslandEvents.colorSuccess
                : item.modelData.state === "attention" ? IslandEvents.colorAttention : IslandEvents.colorProgress
            Layout.fillWidth: true
            implicitHeight: itemColumn.implicitHeight + 16
            radius: 14
            color: Appearance.colors.colLayer1

            FileView {
                path: item.showLog ? (item.commandData?.log ?? "") : ""
                printErrors: false
                onLoaded: item.logText = text().split("\n").filter(l => l.trim() !== "").slice(-14).join("\n")
            }

            ColumnLayout {
                id: itemColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: item.modelData.state === "done" ? "check_circle" : item.modelData.state === "error" ? "error" : item.modelData.icon
                        iconSize: 18
                        fill: 1
                        color: item.accent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -3
                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.title
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            font.family: item.isCommand ? Appearance.font.family.monospace : Appearance.font.family.main
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: item.modelData.subtitle
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                    StyledText {
                        visible: item.modelData.progress >= 0 && item.modelData.state === "running"
                        text: `${Math.round(item.modelData.progress * 100)}%`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                    }
                    MaterialSymbol {
                        text: "close"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: IslandEvents.removeActivity(item.modelData.id)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    visible: item.modelData.state === "running"
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: ColorUtils.transparentize(item.accent, 0.8)
                    }
                    Rectangle {
                        id: bar
                        height: parent.height
                        radius: 2
                        color: item.accent
                        width: item.modelData.progress >= 0 ? parent.width * item.modelData.progress : parent.width * 0.3
                        x: 0

                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }

                        NumberAnimation on x {
                            running: item.modelData.progress < 0
                            loops: Animation.Infinite
                            from: -bar.width
                            to: bar.parent.width
                            duration: 1200
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                // Terminal commands: see the output, run it again, jump back to the terminal
                Flow {
                    Layout.fillWidth: true
                    visible: item.isCommand && item.modelData.state !== "running"
                    spacing: 6

                    SmallButton {
                        visible: (item.commandData?.log ?? "") !== ""
                        icon: item.showLog ? "expand_less" : "subject"
                        label: item.showLog ? Translation.tr("Hide output") : Translation.tr("Show output")
                        tint: item.accent
                        onTap: () => item.showLog = !item.showLog
                    }
                    SmallButton {
                        icon: "replay"
                        label: Translation.tr("Run again")
                        tint: item.accent
                        onTap: () => {
                            IslandEvents.rerunCommand(item.commandData)
                            xact.di.collapse()
                        }
                    }
                    SmallButton {
                        visible: (item.commandData?.terminal ?? 0) > 0
                        icon: "terminal"
                        label: Translation.tr("Go to terminal")
                        tint: item.accent
                        onTap: () => {
                            IslandEvents.focusWindowPid(item.commandData.terminal)
                            xact.di.collapse()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: item.showLog
                    implicitHeight: logLabel.implicitHeight + 16
                    radius: 10
                    color: Appearance.colors.colLayer2

                    StyledText {
                        id: logLabel
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 8
                        }
                        text: item.logText !== "" ? item.logText : Translation.tr("No output captured")
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer2
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
