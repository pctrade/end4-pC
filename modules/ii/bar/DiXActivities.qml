import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Coding agents and live activities: one row per session, details on tap, usage limits in a second column.
RowLayout {
    id: xact
    required property Item di
    spacing: 16
    implicitWidth: xact.wantedWidth
    readonly property bool twoColumns: xact.limitAgents.length > 0
    readonly property real wantedWidth: xact.twoColumns ? 532 : 372
    readonly property real sideWidth: 176

    readonly property var otherActivities: [...IslandEvents.activities].reverse()
        .filter(a => !a.id.startsWith("agent-") && a.id !== "agents-waiting")
    readonly property var limitAgents: ["claude", "codex", "gemini"].filter(a => ClaudeCode.limits[a] !== undefined)
    readonly property var sessions: ClaudeCode.sessionList
    readonly property int workingCount: ClaudeCode.liveSessions.filter(s => s.state === "working").length
    readonly property int waitingCount: ClaudeCode.liveSessions.filter(s => s.state === "waiting").length
    readonly property bool isEmpty: xact.sessions.length === 0 && xact.otherActivities.length === 0
    property double now: Date.now()
    // "s:<session key>" or "a:<activity id>"; only one row is open at a time
    property string expandedKey: ""

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
    function toggle(key) {
        xact.expandedKey = xact.expandedKey === key ? "" : key
    }
    function levelColor(percent) {
        return percent >= 95 ? IslandEvents.colorError : percent >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
    }
    function statusSummary() {
        const parts = []
        if (xact.workingCount > 0) parts.push(Translation.tr("%1 working").arg(xact.workingCount))
        if (xact.waitingCount > 0) parts.push(Translation.tr("%1 waiting").arg(xact.waitingCount))
        return parts.join(" · ")
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component SmallButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        property color tint: Appearance.colors.colPrimary
        property bool solid: false
        property var onTap: () => {}
        implicitWidth: buttonRow.implicitWidth + (button.label !== "" ? 18 : 10)
        implicitHeight: 26
        radius: 13
        color: button.solid ? (buttonMouse.containsMouse ? Qt.lighter(button.tint, 1.12) : button.tint)
            : buttonMouse.containsMouse ? ColorUtils.transparentize(button.tint, 0.7) : ColorUtils.transparentize(button.tint, 0.85)
        scale: buttonMouse.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }
        Behavior on scale {
            NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutBack }
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
                color: button.solid ? Appearance.m3colors.m3onSuccess : button.tint
            }
            StyledText {
                visible: button.label !== ""
                Layout.maximumWidth: 260
                text: button.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: button.solid ? Appearance.m3colors.m3onSuccess : Appearance.colors.colOnLayer1
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

    component MiniBar: Rectangle {
        id: miniBar
        property real percent: 0
        property real reveal: 1
        property color tint: xact.levelColor(miniBar.percent)
        implicitHeight: 4
        radius: 2
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

        Rectangle {
            width: miniBar.width * Math.max(0, Math.min(1, miniBar.percent / 100)) * miniBar.reveal
            height: parent.height
            radius: 2
            color: miniBar.tint

            Behavior on color {
                ColorAnimation { duration: IslandMotion.short }
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        Layout.fillWidth: false
        Layout.preferredWidth: xact.wantedWidth - (xact.twoColumns ? xact.sideWidth + xact.spacing : 0)
        Layout.maximumWidth: mainColumn.Layout.preferredWidth
        Layout.alignment: Qt.AlignTop
        spacing: 6

        RowLayout {
            id: agentsHeader
            Layout.fillWidth: true
            visible: xact.sessions.length > 0
            spacing: 8
            DiCascade { target: agentsHeader; index: 0 }

            SectionLabel {
                Layout.fillWidth: true
                text: Translation.tr("Agents")
            }
            SectionLabel {
                visible: !xact.twoColumns && text !== ""
                text: xact.statusSummary()
                font.features: { "tnum": 1 }
            }
        }

        Repeater {
            model: xact.sessions.length
            delegate: Item {
                id: row
                required property int index
                readonly property var d: xact.sessions[row.index] ?? ({})
                readonly property string rowKey: `s:${row.d.key ?? ""}`
                readonly property bool open: xact.expandedKey === row.rowKey
                readonly property bool waiting: row.d.state === "waiting"
                readonly property bool working: row.d.state === "working"
                readonly property bool ended: row.d.state === "ended"
                readonly property bool alive: ClaudeCode.windowAlive(row.d)
                readonly property bool canType: row.alive && !row.ended
                readonly property bool asksPermission: row.waiting && (row.d.permission ?? "") !== ""
                readonly property bool hasOptions: row.waiting && row.canType && (row.d.options ?? []).length > 0
                readonly property real context: row.d.context ?? -1
                readonly property bool hasContext: row.context >= 0 && !row.ended
                readonly property string diffText: ClaudeCode.formatDiff(row.d.diff)
                readonly property color accent: row.waiting ? IslandEvents.colorAttention
                    : row.working ? IslandEvents.colorProgress : Appearance.colors.colOnLayer1
                readonly property string ago: xact.agoText(xact.now - (row.d.updated ?? xact.now))
                readonly property string shortState: row.asksPermission ? Translation.tr("Needs permission")
                    : row.waiting ? (row.d.question || row.d.waitingText || Translation.tr("Waiting for you"))
                    : row.working ? (row.d.detail || Translation.tr("Thinking…"))
                    : row.ended ? Translation.tr("Closed · %1").arg(row.ago)
                    : Translation.tr("Idle · %1").arg(row.ago)
                readonly property string longState: row.waiting ? (row.d.question || row.d.waitingText || Translation.tr("Waiting for you"))
                    : [row.working ? (row.d.detail || Translation.tr("Thinking…")) : "", row.d.summary].filter(Boolean).join(" · ")
                property bool ready: false

                Layout.fillWidth: true
                implicitHeight: card.height
                DiCascade { target: row; index: row.index + 1 }

                Timer {
                    interval: 60
                    running: true
                    onTriggered: row.ready = true
                }
                DiSpring {
                    id: rowHeight
                    target: rowBody.implicitHeight + 12
                    animated: row.ready
                    stiffness: 420
                    dampingRatio: 0.86
                }
                DiSpring {
                    id: contextReveal
                    stiffness: 55
                    dampingRatio: 1
                    epsilon: 0.002
                }
                Timer {
                    interval: 220 + row.index * 40
                    running: true
                    onTriggered: contextReveal.target = 1
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: rowHeight.value
                    radius: 12
                    clip: true
                    opacity: row.ended ? 0.7 : 1
                    color: row.waiting ? ColorUtils.transparentize(IslandEvents.colorAttention, rowMouse.containsMouse ? 0.82 : 0.88)
                        : rowMouse.containsMouse || row.open ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.micro }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xact.toggle(row.rowKey)
                    }

                    ColumnLayout {
                        id: rowBody
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 10
                            rightMargin: 10
                            topMargin: 6
                        }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9

                            Item {
                                implicitWidth: 20
                                implicitHeight: 20

                                DiClaudeIcon {
                                    anchors.centerIn: parent
                                    agent: row.d.agent ?? "claude"
                                    size: 17
                                }
                                Rectangle {
                                    visible: row.working || row.waiting
                                    anchors {
                                        right: parent.right
                                        bottom: parent.bottom
                                        rightMargin: -2
                                        bottomMargin: -2
                                    }
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: row.accent
                                    border.width: 1.5
                                    border.color: Appearance.colors.colLayer1

                                    SequentialAnimation on opacity {
                                        running: row.working || row.waiting
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
                                    text: [row.d.project, row.d.model].filter(Boolean).join(" · ")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.shortState
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: row.waiting ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
                                    opacity: row.waiting ? 0.95 : 0.6
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                visible: row.hasContext
                                Layout.preferredWidth: 30
                                spacing: 2

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: `${Math.round(row.context)}%`
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.features: { "tnum": 1 }
                                    color: row.context >= 80 ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
                                    opacity: 0.75
                                }
                                MiniBar {
                                    Layout.fillWidth: true
                                    implicitHeight: 3
                                    percent: row.context
                                    reveal: contextReveal.value
                                }
                            }

                            MaterialSymbol {
                                text: "expand_more"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                                opacity: rowMouse.containsMouse || row.open ? 0.7 : 0.35
                                rotation: row.open ? 180 : 0

                                Behavior on rotation {
                                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: IslandMotion.micro }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: row.asksPermission
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: row.d.permission ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.8
                                elide: Text.ElideRight
                            }
                            SmallButton {
                                icon: "close"
                                label: Translation.tr("Deny")
                                tint: Appearance.colors.colError
                                onTap: () => ClaudeCode.deny(row.d.key)
                            }
                            SmallButton {
                                icon: "check"
                                label: Translation.tr("Approve")
                                tint: IslandEvents.colorSuccess
                                solid: true
                                onTap: () => ClaudeCode.approve(row.d.key)
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: row.hasOptions && !row.asksPermission
                            spacing: 6

                            Repeater {
                                model: row.hasOptions ? row.d.options : []
                                delegate: SmallButton {
                                    required property string modelData
                                    required property int index
                                    label: `${index + 1}. ${modelData}`
                                    tint: IslandEvents.colorAttention
                                    onTap: () => ClaudeCode.answer(row.d.key, index)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: row.open
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== "" && text !== row.shortState
                                text: row.longState
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.75
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: row.hasContext
                                spacing: 8

                                MiniBar {
                                    Layout.fillWidth: true
                                    percent: row.context
                                    reveal: contextReveal.value
                                }
                                StyledText {
                                    text: Translation.tr("context %1%").arg(Math.round(row.context))
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.features: { "tnum": 1 }
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.7
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                visible: row.diffText !== ""
                                elide: Text.ElideRight
                                text: row.diffText
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.8
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 2
                                spacing: 6

                                SmallButton {
                                    visible: row.canType
                                    icon: "terminal"
                                    label: Translation.tr("Open")
                                    tint: row.waiting ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                                    onTap: () => {
                                        ClaudeCode.focusSession(row.d.key)
                                        xact.di.collapse()
                                    }
                                }
                                SmallButton {
                                    visible: !row.canType && !row.working
                                    icon: "replay"
                                    label: Translation.tr("Resume session")
                                    onTap: () => {
                                        ClaudeCode.resume(row.d.key)
                                        xact.di.collapse()
                                    }
                                }
                                SmallButton {
                                    visible: row.diffText !== "" && !row.working
                                    icon: "difference"
                                    label: Translation.tr("View diff")
                                    onTap: () => {
                                        ClaudeCode.openDiff(row.d.key)
                                        xact.di.collapse()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        SectionLabel {
            id: liveLabel
            Layout.topMargin: xact.sessions.length > 0 ? 2 : 0
            visible: xact.otherActivities.length > 0
            text: Translation.tr("Live activities")
            DiCascade { target: liveLabel; index: xact.sessions.length + 1 }
        }

        Repeater {
            model: xact.otherActivities.length
            delegate: Item {
                id: item
                required property int index
                readonly property var d: xact.otherActivities[item.index] ?? ({})
                readonly property string rowKey: `a:${item.d.id ?? ""}`
                readonly property var commandData: item.d.data ?? null
                readonly property bool isCommand: (item.commandData?.command ?? "") !== ""
                readonly property bool running: item.d.state === "running"
                readonly property bool expandable: item.isCommand && !item.running
                readonly property bool open: item.expandable && xact.expandedKey === item.rowKey
                property bool showLog: false
                property string logText: ""
                property bool ready: false
                readonly property color accent: item.d.state === "error" ? IslandEvents.colorError
                    : item.d.state === "done" ? IslandEvents.colorSuccess
                    : item.d.state === "attention" ? IslandEvents.colorAttention : IslandEvents.colorProgress

                Layout.fillWidth: true
                implicitHeight: itemCard.height
                DiCascade { target: item; index: xact.sessions.length + item.index + 2 }
                onOpenChanged: if (!item.open) item.showLog = false

                Timer {
                    interval: 60
                    running: true
                    onTriggered: item.ready = true
                }
                DiSpring {
                    id: itemHeight
                    target: itemBody.implicitHeight + 12
                    animated: item.ready
                    stiffness: 420
                    dampingRatio: 0.86
                }

                FileView {
                    path: item.showLog ? (item.commandData?.log ?? "") : ""
                    printErrors: false
                    onLoaded: item.logText = text().split("\n").filter(l => l.trim() !== "").slice(-8).join("\n")
                }

                Rectangle {
                    id: itemCard
                    width: parent.width
                    height: itemHeight.value
                    radius: 12
                    clip: true
                    color: (item.expandable && itemMouse.containsMouse) || item.open ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.micro }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: item.expandable
                        cursorShape: item.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (item.expandable) xact.toggle(item.rowKey)
                    }

                    ColumnLayout {
                        id: itemBody
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 10
                            rightMargin: 8
                            topMargin: 6
                        }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9

                            MaterialSymbol {
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: item.d.state === "done" ? "check_circle" : item.d.state === "error" ? "error" : (item.d.icon ?? "bolt")
                                iconSize: 17
                                fill: 1
                                color: item.accent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: -3
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: item.d.title ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    font.family: item.isCommand ? Appearance.font.family.monospace : Appearance.font.family.main
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    visible: text !== ""
                                    text: item.d.subtitle ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.features: { "tnum": 1 }
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            StyledText {
                                visible: (item.d.progress ?? -1) >= 0 && item.running
                                text: `${Math.round(item.d.progress * 100)}%`
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.75
                            }
                            MaterialSymbol {
                                visible: item.expandable
                                text: "expand_more"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                                opacity: itemMouse.containsMouse || item.open ? 0.7 : 0.35
                                rotation: item.open ? 180 : 0

                                Behavior on rotation {
                                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
                                }
                            }
                            Item {
                                implicitWidth: 20
                                implicitHeight: 20

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 15
                                    color: Appearance.colors.colOnLayer1
                                    opacity: closeMouse.containsMouse ? 0.9 : 0.45
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: IslandEvents.removeActivity(item.d.id)
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: item.open
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
                            Layout.bottomMargin: 2
                            visible: item.open && item.showLog
                            implicitHeight: logLabel.implicitHeight + 14
                            radius: 8
                            color: Appearance.colors.colLayer3

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
                                maximumLineCount: 8
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        visible: item.running
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 10
                            rightMargin: 10
                            bottomMargin: 3
                        }
                        height: 3
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 1.5
                            color: ColorUtils.transparentize(item.accent, 0.8)
                        }
                        Rectangle {
                            id: bar
                            height: parent.height
                            radius: 1.5
                            color: item.accent
                            width: (item.d.progress ?? -1) >= 0 ? parent.width * item.d.progress : parent.width * 0.3
                            x: 0

                            Behavior on width {
                                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
                            }

                            NumberAnimation on x {
                                running: item.running && (item.d.progress ?? -1) < 0
                                loops: Animation.Infinite
                                from: -bar.width
                                to: bar.parent.width
                                duration: 1200
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: emptyState
            Layout.fillWidth: true
            Layout.topMargin: 36
            Layout.bottomMargin: 36
            visible: xact.isEmpty
            spacing: 2
            DiCascade { target: emptyState; index: 0 }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "terminal"
                iconSize: 30
                color: Appearance.colors.colOnLayer0
                opacity: 0.35
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Nothing running")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: mainColumn.Layout.preferredWidth - 20
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Coding agents, long commands and downloads show up here")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.45
                wrapMode: Text.Wrap
            }
        }
    }

    ColumnLayout {
        id: sideColumn
        visible: xact.twoColumns
        Layout.fillWidth: false
        Layout.preferredWidth: xact.sideWidth
        Layout.maximumWidth: xact.sideWidth
        Layout.alignment: Qt.AlignTop
        spacing: 6

        RowLayout {
            id: summary
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            visible: xact.limitAgents.length < 3
            spacing: 10
            DiCascade { target: summary; index: 1 }

            StyledText {
                text: ClaudeCode.openCount
                font.pixelSize: 38
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: ClaudeCode.anyWaiting ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: ClaudeCode.openCount === 1 ? Translation.tr("open session") : Translation.tr("open sessions")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: xact.statusSummary() || Translation.tr("All idle")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
        }

        SectionLabel {
            id: limitsLabel
            text: Translation.tr("Limits")
            DiCascade { target: limitsLabel; index: 2 }
        }

        Repeater {
            model: xact.limitAgents
            delegate: Item {
                id: limitCard
                required property string modelData
                required property int index
                readonly property var limit: ClaudeCode.limits[limitCard.modelData] ?? ({})
                readonly property real five: limitCard.limit.five ?? 0
                readonly property real week: limitCard.limit.week ?? -1
                Layout.fillWidth: true
                implicitHeight: limitBody.implicitHeight + 16
                DiCascade { target: limitCard; index: limitCard.index + 3 }

                DiSpring {
                    id: limitReveal
                    stiffness: 50
                    dampingRatio: 1
                    epsilon: 0.002
                }
                Timer {
                    interval: 300 + limitCard.index * 60
                    running: true
                    onTriggered: limitReveal.target = 1
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Appearance.colors.colLayer1
                }

                ColumnLayout {
                    id: limitBody
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        DiClaudeIcon {
                            agent: limitCard.modelData
                            size: 13
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: ClaudeCode.agentNames[limitCard.modelData] ?? limitCard.modelData
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        MaterialSymbol {
                            visible: !!limitCard.limit.fiveReset
                            text: "update"
                            iconSize: 12
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.55
                        }
                        StyledText {
                            visible: !!limitCard.limit.fiveReset
                            text: ClaudeCode.formatReset(limitCard.limit.fiveReset)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.6
                        }
                    }

                    Repeater {
                        model: [
                            { label: Translation.tr("5h"), value: limitCard.five },
                            { label: Translation.tr("Week"), value: limitCard.week }
                        ].filter(m => m.value >= 0)
                        delegate: RowLayout {
                            id: limitRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                Layout.preferredWidth: 32
                                text: limitRow.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                            MiniBar {
                                Layout.fillWidth: true
                                percent: limitRow.modelData.value
                                reveal: limitReveal.value
                            }
                            StyledText {
                                Layout.preferredWidth: 30
                                horizontalAlignment: Text.AlignRight
                                text: `${Math.round(limitRow.modelData.value)}%`
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: limitRow.modelData.value >= 80 ? IslandEvents.colorAttention : Appearance.colors.colOnLayer1
                                opacity: 0.85
                            }
                        }
                    }
                }
            }
        }
    }
}
