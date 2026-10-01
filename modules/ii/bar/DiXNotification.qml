import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Full notification view at standard height; chats get a thread layout with quick replies.
ColumnLayout {
    id: xn
    readonly property real wantedWidth: 420
    required property Item di
    spacing: 10

    Item {
        Layout.preferredWidth: 420
        implicitHeight: 0
    }

    readonly property var popups: xn.di.visibleNotifications

    Binding {
        target: xn.di
        property: "replyReady"
        value: xn.canReply
        restoreMode: Binding.RestoreValue
    }
    Binding {
        target: xn.di
        property: "replyHasText"
        value: replyField.text !== ""
        restoreMode: Binding.RestoreValue
    }

    function focusReplyIfRequested() {
        if (!xn.di.replyRequested || !xn.canReply) return
        xn.di.replyRequested = false
        xn.di.wantsKeyboard = true
        Qt.callLater(() => replyField.forceActiveFocus())
    }
    Connections {
        target: xn.di
        function onReplyRequestedChanged() { xn.focusReplyIfRequested() }
    }
    property int lockedId: -1
    readonly property int lockedIndex: xn.popups.findIndex(n => n.notificationId === xn.lockedId)
    readonly property int index: xn.lockedIndex >= 0 ? xn.lockedIndex : Math.max(0, xn.popups.length - 1)
    readonly property var notif: xn.popups[xn.index]
    property bool muteChoosing: false
    onNotifChanged: {
        xn.muteChoosing = false
        xn.replyHint = ""
    }
    function lockOn(index) {
        const target = xn.popups[Math.max(0, Math.min(xn.popups.length - 1, index))]
        if (target) xn.lockedId = target.notificationId
    }
    Component.onCompleted: {
        const opened = xn.di.shownNotification ?? xn.di.latestNotification
        xn.lockedId = opened?.notificationId ?? -1
        xn.focusReplyIfRequested()
    }
    readonly property var parts: IslandEvents.notificationParts(xn.notif)
    readonly property bool critical: (xn.notif?.urgency ?? "").toLowerCase() === "critical"
    readonly property color accent: xn.critical ? Appearance.colors.colError : IslandEvents.appColor(xn.parts.app, Appearance.colors.colPrimary)
    readonly property string rawImage: xn.notif?.image ?? ""
    readonly property string imageSource: xn.rawImage.startsWith("image://icon//")
        ? `file://${xn.rawImage.slice("image://icon/".length)}` : xn.rawImage
    readonly property bool animatedImage: /\.(gif|webp)$/i.test(xn.imageSource)
    readonly property var hero: xn.imageSource !== "" && !xn.bigImage ? { key: "notif-avatar", item: avatarFrame } : null
    readonly property real imageAspect: imageProbe.implicitHeight > 0 ? imageProbe.implicitWidth / imageProbe.implicitHeight : 1
    readonly property bool bigImage: imageProbe.status === Image.Ready
        && (Math.max(imageProbe.implicitWidth, imageProbe.implicitHeight) >= 200 || xn.imageAspect < 0.8 || xn.imageAspect > 1.25)

    readonly property bool canReply: (xn.notif?.hasInlineReply ?? false) || xn.messaging
    readonly property var appActions: (xn.notif?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property real mediaMaxHeight: xn.canReply ? 84 : 130
    readonly property bool messaging: /whats|zap|telegram|discord|vesktop|signal|slack|teams|instagram|messenger/i.test(xn.parts.app)
    property string replyHint: ""

    readonly property var earlier: {
        if (!xn.notif || !xn.messaging) return []
        const key = IslandEvents.conversationKey(xn.notif)
        const since = (xn.notif.time ?? Date.now()) - 60 * 60000
        return Notifications.list
            .filter(n => n.notificationId !== xn.notif.notificationId && IslandEvents.conversationKey(n) === key
                && (n.time ?? 0) >= since && (n.time ?? 0) <= (xn.notif.time ?? Date.now()))
            .sort((a, b) => (a.time ?? 0) - (b.time ?? 0))
            .slice(-1)
    }

    function escaped(text) {
        return (text ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;")
    }

    function sendText(text) {
        if (text.trim() === "" || !xn.notif) return
        xn.di.wantsKeyboard = false
        if (xn.notif.hasInlineReply) {
            Notifications.sendInlineReply(xn.notif.notificationId, text)
            xn.replyHint = Translation.tr("Sent")
            return
        }
        const target = xn.notif
        xn.di.collapse()
        IslandEvents.replyToChat(target, text)
    }

    property real enter: 0
    NumberAnimation on enter {
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }
    function rise(order) {
        return Math.max(0, Math.min(1, (xn.enter - order * 0.12) / 0.55))
    }

    Image {
        id: imageProbe
        visible: false
        source: xn.animatedImage ? "" : xn.imageSource
        asynchronous: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        DiBrandIcon {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            visible: xn.parts.brand !== ""
            source: xn.parts.brand
            size: 15
            color: xn.accent
        }
        Image {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            visible: xn.parts.brand === "" && (xn.notif?.appIcon ?? "") !== ""
            source: Quickshell.iconPath(xn.notif?.appIcon ?? "", "notification-symbolic")
            sourceSize.width: 30
            sourceSize.height: 30
        }
        StyledText {
            Layout.maximumWidth: 190
            text: xn.messaging ? xn.parts.title : (xn.parts.app || Translation.tr("Notification"))
            font.pixelSize: xn.messaging ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: xn.messaging ? (xn.critical ? Appearance.colors.colError : Appearance.colors.colOnLayer0) : xn.accent
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: !xn.notif ? ""
                : xn.messaging ? `· ${xn.parts.app} · ${Qt.formatTime(new Date(xn.notif.time), "hh:mm")}`
                : "· " + Qt.formatTime(new Date(xn.notif.time), "hh:mm")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.55
            elide: Text.ElideRight
        }

        RowLayout {
            visible: xn.popups.length > 1
            spacing: 0

            MaterialSymbol {
                text: "chevron_left"
                iconSize: 18
                color: Appearance.colors.colOnLayer0
                opacity: xn.index > 0 ? 0.9 : 0.3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xn.lockOn(xn.index - 1)
                }
            }
            StyledText {
                text: `${xn.index + 1}/${xn.popups.length}`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
            MaterialSymbol {
                text: "chevron_right"
                iconSize: 18
                color: Appearance.colors.colOnLayer0
                opacity: xn.index < xn.popups.length - 1 ? 0.9 : 0.3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: xn.lockOn(xn.index + 1)
                }
            }
        }

        component HeaderIcon: Rectangle {
            id: headerIcon
            property string icon
            property string tip
            property var onTap: null
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: headerIconArea.containsMouse ? Appearance.colors.colLayer2 : "transparent"

            Behavior on color {
                ColorAnimation { duration: IslandMotion.micro }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: headerIcon.icon
                iconSize: 16
                color: Appearance.colors.colOnLayer0
                opacity: headerIconArea.containsMouse ? 1 : 0.6
            }
            MouseArea {
                id: headerIconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (headerIcon.onTap) headerIcon.onTap()
            }
            StyledToolTip {
                text: headerIcon.tip
                extraVisibleCondition: false
                alternativeVisibleCondition: headerIconArea.containsMouse
            }
        }

        HeaderIcon {
            visible: xn.notif !== null && !xn.muteChoosing
            icon: "open_in_new"
            tip: `${Translation.tr("Open in")} ${xn.parts.app || Translation.tr("app")}`
            onTap: () => {
                IslandEvents.openNotificationSource(xn.notif)
                xn.di.collapse()
            }
        }
        HeaderIcon {
            visible: xn.notif !== null
            icon: xn.muteChoosing ? "arrow_back" : "notifications_off"
            tip: xn.muteChoosing ? Translation.tr("Back") : Translation.tr("Mute conversation")
            onTap: () => { xn.muteChoosing = !xn.muteChoosing }
        }
        Repeater {
            model: xn.muteChoosing ? IslandEvents.muteChoices() : []
            delegate: Rectangle {
                id: choice
                required property var modelData
                implicitWidth: choiceText.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: choiceArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                StyledText {
                    id: choiceText
                    anchors.centerIn: parent
                    text: choice.modelData.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: choiceArea.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                }
                MouseArea {
                    id: choiceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const target = xn.notif
                        IslandEvents.muteKeyFor(IslandEvents.conversationKey(target), choice.modelData.ms)
                        Notifications.timeoutNotification(target.notificationId)
                        xn.muteChoosing = false
                        xn.di.collapse()
                    }
                }
            }
        }
        HeaderIcon {
            visible: !xn.muteChoosing
            icon: "close"
            tip: Translation.tr("Dismiss")
            onTap: () => { if (xn.notif) Notifications.discardNotification(xn.notif.notificationId) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            id: avatarFrame
            visible: xn.imageSource !== "" && !xn.bigImage
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop
            radius: 22
            color: ColorUtils.transparentize(xn.accent, 0.8)
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: avatarFrame.width
                    height: avatarFrame.height
                    radius: avatarFrame.radius
                }
            }
            Image {
                anchors.fill: parent
                source: avatarFrame.visible ? xn.imageSource : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                sourceSize.height: 96
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 5

            StyledText {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                visible: !xn.messaging
                text: xn.parts.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: xn.critical ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                opacity: xn.rise(0)
            }

            Flickable {
                id: thread
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: Math.min(threadColumn.implicitHeight, xn.canReply ? 130 : (xn.appActions.length > 0 ? 146 : 176))
                contentWidth: width
                contentHeight: threadColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: thread.contentY = Math.max(0, thread.contentHeight - thread.height)
                onHeightChanged: thread.contentY = Math.max(0, thread.contentHeight - thread.height)

                ColumnLayout {
                    id: threadColumn
                    width: thread.width
                    spacing: 5

                    Repeater {
                        model: xn.earlier
                        delegate: Rectangle {
                            id: earlierBubble
                            required property var modelData
                            required property int index
                            readonly property var p: IslandEvents.notificationParts(earlierBubble.modelData)
                            Layout.maximumWidth: thread.width
                            Layout.preferredWidth: earlierText.implicitWidth + 22
                            implicitHeight: earlierText.implicitHeight + 12
                            radius: 12
                            topLeftRadius: 4
                            color: Appearance.colors.colLayer1
                            opacity: 0.75 * xn.rise(Math.min(3, xn.earlier.length - earlierBubble.index))
                            transform: Translate { y: (1 - xn.rise(Math.min(3, xn.earlier.length - earlierBubble.index))) * 10 }

                            StyledText {
                                id: earlierText
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 11
                                    rightMargin: 11
                                }
                                text: earlierBubble.p.body || (earlierBubble.p.media?.label ?? "")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                                wrapMode: Text.Wrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        id: bubble
                        visible: xn.parts.body !== "" || xn.parts.media !== null
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: bubbleColumn.implicitHeight + 18
                        radius: 16
                        topLeftRadius: 5
                        color: ColorUtils.mix(Appearance.colors.colLayer2, xn.accent, 0.9)
                        border.width: 1
                        border.color: ColorUtils.transparentize(xn.accent, 0.8)
                        readonly property real r: xn.rise(Math.min(3, xn.earlier.length) + 1)
                        opacity: bubble.r
                        transform: Translate { y: (1 - bubble.r) * 12 }

                        ColumnLayout {
                            id: bubbleColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 9
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignTop
                                    visible: xn.parts.media !== null
                                    text: xn.parts.media?.icon ?? ""
                                    iconSize: 17
                                    fill: 1
                                    color: xn.accent
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    text: {
                                        const body = xn.parts.body || (xn.parts.media?.label ?? "")
                                        return xn.parts.author !== ""
                                            ? `<b><font color="${xn.accent}">${xn.escaped(xn.parts.author)}</font></b><br>${xn.escaped(body)}`
                                            : xn.escaped(body)
                                    }
                                    textFormat: Text.StyledText
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer0
                                    wrapMode: Text.Wrap
                                    maximumLineCount: xn.messaging ? (xn.earlier.length > 0 ? 3 : 5) : 100
                                    elide: Text.ElideRight
                                    lineHeight: 1.1
                                }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                visible: !xn.messaging
                                text: xn.notif ? Qt.formatTime(new Date(xn.notif.time), "hh:mm") : ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.5
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: thread.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    width: 4
                }
                MouseArea {
                    parent: thread
                    anchors.fill: parent
                    z: 10
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * 48
                        thread.contentY = Math.max(0, Math.min(thread.contentHeight - thread.height, thread.contentY - step))
                        wheel.accepted = true
                    }
                }

            }

        }
    }

    Rectangle {
        id: mediaFrame
        visible: xn.bigImage || xn.animatedImage
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.min(360, bigImageItem.paintedWidth || 200)
        Layout.preferredHeight: Math.min(xn.mediaMaxHeight, bigImageItem.paintedHeight || xn.mediaMaxHeight)
        radius: 14
        color: "transparent"
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: mediaFrame.width
                height: mediaFrame.height
                radius: mediaFrame.radius
            }
        }

        AnimatedImage {
            id: bigImageItem
            width: 360
            height: xn.mediaMaxHeight
            anchors.centerIn: parent
            source: mediaFrame.visible ? xn.imageSource : ""
            fillMode: Image.PreserveAspectFit
            playing: true
        }

        NumberAnimation on scale {
            running: mediaFrame.visible
            from: 0.6
            to: 1
            duration: IslandMotion.long
            easing.type: Easing.OutBack
        }
    }

    Flickable {
        id: quickRow
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        visible: xn.canReply
        contentWidth: quickContent.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true

        Row {
            id: quickContent
            spacing: 6

            Rectangle {
                id: geminiChip
                width: geminiRow.implicitWidth + 20
                height: 28
                radius: 14
                color: geminiArea.containsMouse ? ColorUtils.transparentize("#4796E3", 0.7) : Appearance.colors.colLayer1
                scale: Math.max(0.01, xn.rise(xn.earlier.length + 2)) * (geminiArea.pressed ? 0.92 : 1)

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                RowLayout {
                    id: geminiRow
                    anchors.centerIn: parent
                    spacing: 5
                    DiClaudeIcon {
                        agent: "gemini"
                        size: 13
                        color: "#4796E3"
                    }
                    StyledText {
                        text: Translation.tr("Ask Gemini")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
                MouseArea {
                    id: geminiArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        IslandEvents.askGemini([...xn.earlier, xn.notif])
                        xn.di.collapse()
                    }
                }
            }

            Repeater {
                model: ["👍", "❤️", "😂", Translation.tr("Already looking"), Translation.tr("Ok!")]
                delegate: Rectangle {
                    id: quick
                    required property string modelData
                    required property int index
                    width: quickText.implicitWidth + 22
                    height: 28
                    radius: 14
                    color: quickArea.containsMouse ? ColorUtils.transparentize(xn.accent, 0.7) : Appearance.colors.colLayer1
                    scale: Math.max(0.01, xn.rise(xn.earlier.length + 2 + quick.index * 0.35)) * (quickArea.pressed ? 0.92 : 1)

                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.micro }
                    }

                    StyledText {
                        id: quickText
                        anchors.centerIn: parent
                        text: quick.modelData
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                    MouseArea {
                        id: quickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xn.sendText(quick.modelData)
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.NoButton
            enabled: quickRow.interactive
            onWheel: wheel => {
                const delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
                quickRow.contentX = Math.max(0, Math.min(quickRow.contentWidth - quickRow.width, quickRow.contentX - delta / 120 * 60))
                wheel.accepted = true
            }
        }
    }

    RowLayout {
        id: actionRow
        Layout.fillWidth: true
        visible: xn.appActions.length > 0 || xn.canReply
        spacing: 6

        Repeater {
            model: xn.appActions
            delegate: Rectangle {
                id: actionButton
                required property var modelData
                Layout.preferredWidth: Math.min(actionText.implicitWidth + 24, xn.canReply ? 120 : 200)
                Layout.preferredHeight: 34
                radius: 17
                color: actionMouse.containsMouse ? ColorUtils.transparentize(xn.accent, 0.65) : ColorUtils.transparentize(xn.accent, 0.82)
                scale: actionMouse.pressed ? 0.95 : 1

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }
                Behavior on scale {
                    NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutBack }
                }

                StyledText {
                    id: actionText
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    horizontalAlignment: Text.AlignHCenter
                    text: actionButton.modelData.text || actionButton.modelData.identifier
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.attemptInvokeAction(xn.notif.notificationId, actionButton.modelData.identifier)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: !xn.canReply
        }

        RowLayout {
            id: replyRow
            Layout.fillWidth: true
            visible: xn.canReply
            spacing: 6

            TextField {
                id: replyField
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.preferredHeight: 34
                placeholderText: xn.replyHint || xn.notif?.inlineReplyPlaceholder || Translation.tr("Reply…")
                color: Appearance.colors.colOnLayer0
                placeholderTextColor: xn.replyHint !== "" ? Appearance.m3colors.m3success : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.5)
                font.pixelSize: Appearance.font.pixelSize.small
                leftPadding: 14
                background: Rectangle {
                    radius: 17
                    color: Appearance.colors.colLayer2
                    border.width: replyField.activeFocus ? 1.5 : 0
                    border.color: xn.accent
                }
                onTextChanged: if (replyField.text !== "") xn.replyHint = ""
                onAccepted: {
                    xn.sendText(replyField.text)
                    replyField.text = ""
                }
                Keys.onEscapePressed: {
                    xn.di.wantsKeyboard = false
                    replyField.focus = false
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onPressed: mouse => {
                        xn.di.wantsKeyboard = true
                        Qt.callLater(() => replyField.forceActiveFocus())
                        mouse.accepted = false
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: xn.accent
                scale: replyField.text !== "" ? 1.06 : 0.92
                opacity: replyField.text !== "" ? 1 : 0.6

                Behavior on scale {
                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: IslandMotion.micro }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "send"
                    iconSize: 17
                    fill: 1
                    color: ColorUtils.isDark(xn.accent) ? "white" : "black"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        xn.sendText(replyField.text)
                        replyField.text = ""
                    }
                }
            }
        }
    }
}
