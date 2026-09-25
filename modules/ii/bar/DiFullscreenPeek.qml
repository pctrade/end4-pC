import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A fullscreen window buries the bar, and the island with it (DynamicIsland.qml decides what each
// island does then). This is what is left of it at the top edge, only while something is there:
//  - a mini island for what has to break through: critical (hibernating, battery, heat, the power menu), taking
//    input, and feedback on what you just did (volume, a screenshot), click-through
//  - a hairline when something queued up or an agent is waiting on you — pulsing for the agent, brighter the more
//    urgent the queue. Resting the pointer on it opens the queue (and the approval itself, to answer right there)
//  - a red dot while recording
//  - a discreet line for messages from priority apps (WhatsApp): sender and text for a few seconds; resting on it
//    holds it and offers reply, mute this conversation and quiet everything until the fullscreen ends
// A middle click on the hairline (or `ipc call island quiet`) toggles that quiet mode.
// Games take no input at the edge at all (strategy games scroll the map by pushing the pointer there).
Scope {
    id: peek
    required property Item di

    LazyLoader {
        active: peek.di.buried && !Config.options.bar.bottom

        component: PanelWindow {
            id: win

            readonly property var cfg: peek.di.cfg
            readonly property int queueLength: peek.di.fsQueue.length
            readonly property bool attention: peek.di.fsAttention
            readonly property bool hairlineShown: (win.cfg.fullscreenPeek ?? true) && (win.queueLength > 0 || win.attention)
            readonly property bool interactive: win.hairlineShown && !peek.di.fsGame
            readonly property color tone: win.attention ? IslandEvents.colorAttention
                : (peek.di.fsQueueLevel >= 2 ? Appearance.colors.colError : Appearance.colors.colPrimary)

            readonly property real centerX: {
                peek.di.surfaceItem.width
                peek.di.implicitWidth
                const p = peek.di.QsWindow.mapFromItem(peek.di.surfaceItem, 0, 0)
                return p.x + peek.di.surfaceItem.width / 2
            }

            property string miniId: ""
            readonly property string wantedMini: peek.di.fsMiniId
            readonly property bool miniShown: win.wantedMini !== ""
            readonly property bool miniCritical: win.miniShown && peek.di.fullscreenTier(win.miniId) === "critical"

            onWantedMiniChanged: {
                if (win.wantedMini !== "") {
                    miniOutTimer.stop()
                    win.miniId = win.wantedMini
                } else {
                    miniOutTimer.restart()
                }
            }
            Component.onCompleted: win.miniId = win.wantedMini

            Timer {
                id: miniOutTimer
                interval: 280
                onTriggered: win.miniId = ""
            }

            readonly property var message: peek.di.fsMessage
            readonly property var notice: peek.di.fsNotice
            readonly property bool toastShown: win.message !== null || win.notice !== null
            property var shownMessage: null
            property var shownNotice: null
            onMessageChanged: if (win.message !== null) win.shownMessage = win.message
            onNoticeChanged: if (win.notice !== null) win.shownNotice = win.notice
            readonly property bool showingNotice: win.notice !== null || (win.message === null && win.shownNotice !== null && win.shownMessage === null)

            property bool panelOpen: false
            readonly property bool pointerIn: edgeHover.hovered || panelHover.hovered
            property double openedAt: 0

            onPointerInChanged: {
                if (win.pointerIn) {
                    closeTimer.stop()
                    if (!win.panelOpen) openTimer.restart()
                } else {
                    openTimer.stop()
                    closeTimer.restart()
                }
            }
            onInteractiveChanged: if (!win.interactive) win.panelOpen = false

            Timer {
                id: openTimer
                interval: win.cfg.fullscreenHoverDelay ?? 350
                onTriggered: {
                    win.openedAt = Date.now()
                    win.panelOpen = true
                }
            }
            Timer {
                id: closeTimer
                interval: 300
                onTriggered: win.panelOpen = false
            }

            function openHistory() {
                win.panelOpen = false
                peek.di.fsClearQueue()
                peek.di.expandTo(2, "history")
            }

            function ago(time) {
                const minutes = Math.floor((win.openedAt - time) / 60000)
                if (minutes < 1) return Translation.tr("now")
                if (minutes < 60) return Translation.tr("%1 min").arg(minutes)
                return Translation.tr("%1 h").arg(Math.floor(minutes / 60))
            }

            screen: peek.di.QsWindow.window?.screen ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:islandPeek"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: win.miniShown && win.miniId === "session" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 260

            mask: Region {
                item: edgeZone
                Region { item: panelZone }
                Region { item: miniZone }
                Region { item: toastZone }
            }

            Item {
                id: edgeZone
                x: win.centerX - width / 2
                y: 0
                width: win.interactive ? 260 : 0
                height: win.interactive ? 6 : 0

                HoverHandler {
                    id: edgeHover
                }
                TapHandler {
                    acceptedButtons: Qt.MiddleButton
                    onTapped: peek.di.fsToggleQuiet()
                }
            }

            Item {
                id: panelZone
                x: panel.x
                y: 0
                width: win.panelOpen ? panel.width : 0
                height: win.panelOpen ? panel.y + panel.height : 0
            }

            Item {
                id: toastZone
                x: toast.x
                y: toast.y
                width: win.toastShown && !peek.di.fsGame ? toast.width : 0
                height: win.toastShown && !peek.di.fsGame ? toast.height : 0
            }

            Item {
                id: miniZone
                x: mini.x
                y: mini.y
                width: win.miniCritical ? mini.width : 0
                height: win.miniCritical ? mini.height : 0
            }

            property real pulse: 1

            SequentialAnimation {
                id: pulseAnim
                loops: win.attention ? Animation.Infinite : 3
                NumberAnimation { target: win; property: "pulse"; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { target: win; property: "pulse"; to: 1; duration: 700; easing.type: Easing.InOutSine }
            }

            function restartPulse() {
                pulseAnim.stop()
                win.pulse = 1
                if (win.hairlineShown && (win.attention || !peek.di.fsQuiet)) pulseAnim.start()
            }

            Connections {
                target: peek.di
                function onFsQueueSerialChanged() { win.restartPulse() }
            }
            onAttentionChanged: win.restartPulse()
            Connections {
                target: peek.di
                function onFsQuietChanged() { win.restartPulse() }
            }
            onHairlineShownChanged: if (!win.hairlineShown) win.restartPulse()

            Rectangle {
                id: hairline
                readonly property real wanted: win.attention ? 200 : Math.min(240, 96 + 18 * win.queueLength)
                x: win.centerX - width / 2
                y: 0
                width: win.hairlineShown && !win.panelOpen ? hairline.wanted : 0
                height: 3
                radius: 1.5
                color: win.tone
                opacity: !win.hairlineShown || win.panelOpen ? 0
                    : (peek.di.fsQuiet && !win.attention ? 0.3 : 0.45 + 0.5 * win.pulse)

                Behavior on width {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: IslandMotion.medium }
                }
            }

            Rectangle {
                x: win.centerX + Math.max(hairline.width, 0) / 2 + 8
                y: 0
                width: 6
                height: 6
                radius: 3
                color: Appearance.colors.colError
                opacity: peek.di.fsRecording ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.micro }
                }
            }

            Rectangle {
                id: mini
                width: win.miniId !== "" ? peek.di.baseWidth(win.miniId) : 160
                height: peek.di.pillHeight
                radius: height / 2
                x: win.centerX - width / 2
                y: win.miniShown ? 6 : -height - 6
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: win.miniCritical ? Appearance.colors.colError : Appearance.colors.colLayer0Border
                opacity: win.miniShown ? 1 : 0

                Behavior on y {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.micro }
                }
                Behavior on width {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                }

                Loader {
                    anchors.fill: parent
                    clip: true
                    sourceComponent: win.miniId !== "" ? peek.di.componentFor(win.miniId) : null
                }
            }

            Rectangle {
                id: toast
                readonly property bool expandedButtons: toastHover.hovered && !win.showingNotice && !peek.di.fsGame
                readonly property color lineColor: win.shownMessage?.color ?? IslandEvents.appColor(win.shownMessage?.app ?? "", Appearance.colors.colPrimary)
                readonly property bool mutable: (win.shownMessage?.key ?? "") !== ""
                property bool muteChoosing: false
                onExpandedButtonsChanged: if (!toast.expandedButtons) toast.muteChoosing = false
                width: Math.min(460, toastRow.implicitWidth + 24)
                height: 30
                radius: height / 2
                x: win.centerX - width / 2
                y: win.toastShown ? (win.miniShown ? mini.y + mini.height + 6 : 8) : -height - 6
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.08)
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                opacity: win.toastShown ? 1 : 0
                visible: opacity > 0.01 || y > -height

                Behavior on y {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.short }
                }
                Behavior on width {
                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    id: toastHover
                    onHoveredChanged: peek.di.fsMessageHeld = toastHover.hovered && win.message !== null
                }
                TapHandler {
                    acceptedButtons: Qt.MiddleButton
                    onTapped: {
                        peek.di.fsMessageHeld = false
                        peek.di.fsMessage = null
                    }
                }

                RowLayout {
                    id: toastRow
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 7

                    DiBrandIcon {
                        visible: !win.showingNotice && (win.shownMessage?.brand ?? "") !== ""
                        source: win.shownMessage?.brand ?? ""
                        size: 14
                        color: toast.lineColor
                    }
                    MaterialSymbol {
                        visible: win.showingNotice || (win.shownMessage?.brand ?? "") === "" || !["chat", ""].includes(win.shownMessage?.icon ?? "")
                        text: win.showingNotice ? (win.shownNotice?.icon ?? "check") : (win.shownMessage?.icon || "chat")
                        iconSize: 15
                        fill: 1
                        color: win.showingNotice ? Appearance.colors.colOnLayer0 : toast.lineColor
                    }
                    StyledText {
                        Layout.maximumWidth: win.showingNotice ? 300 : 150
                        text: win.showingNotice ? (win.shownNotice?.text ?? "") : (win.shownMessage?.title ?? "")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: !win.showingNotice && text !== "" && !toast.muteChoosing
                        Layout.maximumWidth: toast.expandedButtons ? 150 : 240
                        text: win.shownMessage?.body ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.75
                        elide: Text.ElideRight
                    }

                    ToastButton {
                        visible: win.showingNotice && (win.shownNotice?.actionLabel ?? "") !== ""
                        label: win.shownNotice?.actionLabel ?? ""
                        onTap: () => {
                            const action = win.shownNotice?.action
                            peek.di.fsNotice = null
                            if (action) action()
                        }
                    }

                    ToastButton {
                        visible: toast.expandedButtons && !toast.muteChoosing && (win.shownMessage?.messaging ?? false)
                        icon: "reply"
                        tip: Translation.tr("Reply")
                        onTap: () => {
                            peek.di.fsMessageHeld = false
                            peek.di.fsOpenMessage()
                        }
                    }
                    ToastButton {
                        visible: toast.expandedButtons && toast.mutable
                        icon: toast.muteChoosing ? "arrow_back" : "notifications_off"
                        tip: toast.muteChoosing ? "" : Translation.tr("Mute this conversation")
                        onTap: () => { toast.muteChoosing = !toast.muteChoosing }
                    }
                    Repeater {
                        model: toast.muteChoosing ? IslandEvents.muteChoices() : []
                        delegate: ToastButton {
                            required property var modelData
                            label: modelData.label
                            onTap: () => {
                                const key = win.shownMessage?.key ?? ""
                                toast.muteChoosing = false
                                peek.di.fsMessageHeld = false
                                peek.di.fsMuteConversation(key, modelData.ms)
                            }
                        }
                    }
                    ToastButton {
                        visible: toast.expandedButtons && !toast.muteChoosing
                        icon: "notifications_paused"
                        tip: Translation.tr("Quiet until fullscreen ends")
                        onTap: () => {
                            peek.di.fsMessageHeld = false
                            peek.di.fsToggleQuiet()
                        }
                    }
                }
            }

            component ToastButton: Rectangle {
                id: button
                property string icon: ""
                property string label: ""
                property string tip: ""
                property var onTap: null
                implicitWidth: button.label !== "" ? buttonLabel.implicitWidth + 16 : 22
                implicitHeight: 22
                radius: 11
                color: buttonMouse.containsMouse ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: button.label === ""
                    text: button.icon
                    iconSize: 14
                    fill: 1
                    color: buttonMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                }
                StyledText {
                    id: buttonLabel
                    anchors.centerIn: parent
                    visible: button.label !== ""
                    text: button.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: buttonMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                }
                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (button.onTap) button.onTap()
                }
                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: button.tip !== "" && buttonMouse.containsMouse
                    y: button.height + 6
                    text: button.tip
                }
            }

            ColumnLayout {
                id: panel
                x: win.centerX - width / 2
                y: win.toastShown ? toast.y + toast.height + 6 : (win.miniShown ? mini.y + mini.height + 6 : 6)
                spacing: 6
                opacity: win.panelOpen ? 1 : 0
                scale: win.panelOpen ? 1 : 0.94
                transformOrigin: Item.Top
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.micro }
                }
                Behavior on scale {
                    NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack }
                }

                HoverHandler {
                    id: panelHover
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.attention
                    implicitWidth: peek.di.baseWidth("approval")
                    implicitHeight: peek.di.pillHeight
                    radius: height / 2
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: IslandEvents.colorAttention

                    Loader {
                        anchors.fill: parent
                        clip: true
                        active: win.attention && win.panelOpen
                        sourceComponent: peek.di.componentFor("approval")
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.queueLength > 0
                    implicitWidth: 320
                    implicitHeight: queueColumn.implicitHeight + 12
                    radius: 18
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        id: queueColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 6
                        }
                        spacing: 0

                        Repeater {
                            model: peek.di.fsQueue.slice(0, 3)
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 12
                                color: rowHover.hovered ? Appearance.colors.colLayer1 : "transparent"
                                readonly property bool mutable: (row.modelData.key ?? "") !== ""

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 8
                                        rightMargin: 8
                                    }
                                    spacing: 8

                                    MaterialSymbol {
                                        text: row.modelData.icon
                                        iconSize: 16
                                        fill: 1
                                        color: row.modelData.level >= 2 ? Appearance.colors.colError : Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        opacity: row.choosing ? 0 : 1
                                        text: row.modelData.title
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer0
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        visible: !(row.mutable && rowHover.hovered)
                                        text: win.ago(row.modelData.time)
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colOnLayer0
                                        opacity: 0.6
                                    }
                                }

                                HoverHandler {
                                    id: rowHover
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.openHistory()
                                }
                                property bool choosing: false
                                onMutableChanged: row.choosing = false
                                Connections {
                                    target: rowHover
                                    function onHoveredChanged() { if (!rowHover.hovered) row.choosing = false }
                                }
                                RowLayout {
                                    anchors {
                                        right: parent.right
                                        rightMargin: 6
                                        verticalCenter: parent.verticalCenter
                                    }
                                    visible: row.mutable && rowHover.hovered
                                    spacing: 4

                                    Repeater {
                                        model: row.choosing ? IslandEvents.muteChoices() : []
                                        delegate: ToastButton {
                                            required property var modelData
                                            label: modelData.label
                                            onTap: () => peek.di.fsMuteConversation(row.modelData.key, modelData.ms)
                                        }
                                    }
                                    ToastButton {
                                        icon: row.choosing ? "arrow_back" : "notifications_off"
                                        tip: row.choosing ? "" : Translation.tr("Mute this conversation")
                                        onTap: () => { row.choosing = !row.choosing }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    ToastButton {
                        label: peek.di.fsQuiet ? Translation.tr("Notify again") : Translation.tr("Quiet until fullscreen ends")
                        onTap: () => peek.di.fsToggleQuiet()
                    }
                    ToastButton {
                        visible: win.queueLength > 0
                        label: win.queueLength > 3
                            ? Translation.tr("+%1 · Open history").arg(win.queueLength - 3)
                            : Translation.tr("Open history")
                        onTap: () => win.openHistory()
                    }
                }
            }
        }
    }
}
