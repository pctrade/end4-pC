import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "whatsapp"
    hoverEnabled: true

    implicitWidth: 480
    implicitHeight: 360

    property string mode: "list" // "list" | "detail" | "send"
    property string targetMode: "list"
    property var selectedChat: null
    property int selectedChatIndex: -1

    property string recipientInput: ""
    property string messageInput: ""
    property string searchQuery: ""

    property bool showToast: false
    property string toastText: ""

    // Daemon configuration and connection status (wired to WhatsAppService IPC client)
    property bool daemonConfigured: WhatsAppService.daemonConfigured || (Config.options.background.widgets.whatsapp.daemonConfigured ?? false)
    property bool daemonConnected: WhatsAppService.daemonConnected
    property string connectionStatus: WhatsAppService.connectionStatus

    readonly property string daemonState: {
        if (!daemonConfigured) return "not_configured";
        if (!daemonConnected) return "offline";
        if (connectionStatus === "authenticating" || connectionStatus === "unconfigured") {
            return "authenticating";
        }
        return "connected";
    }

    function retryConnection() {
        notifyToast("Connecting to daemon...");
        WhatsAppService.connectToDaemon();
    }

    // Configurable options bound to Config
    property string chatListMode: Config.options.background.widgets.whatsapp.chatListMode ?? "recent"
    property string presentationMode: Config.options.background.widgets.whatsapp.presentationMode ?? "compact"
    property real pinnedX: Config.options.background.widgets.whatsapp.pinnedX ?? -1
    property real pinnedY: Config.options.background.widgets.whatsapp.pinnedY ?? -1
    property int maxChatCount: Config.options.background.widgets.whatsapp.maxChatCount ?? 10
    property int maxUnreadChats: Config.options.background.widgets.whatsapp.maxUnreadChats ?? 5
    property int maxMessageHistory: Config.options.background.widgets.whatsapp.maxMessageHistory ?? 25
    property bool showTimestamps: Config.options.background.widgets.whatsapp.showTimestamps ?? true
    property bool showUnreadBadge: Config.options.background.widgets.whatsapp.showUnreadBadge ?? true
    property bool autoMarkAsRead: Config.options.background.widgets.whatsapp.autoMarkAsRead ?? false

    function switchPresentationMode(newMode) {
        if (root.presentationMode === newMode) return;
        root.presentationMode = newMode;
        Config.options.background.widgets.whatsapp.presentationMode = newMode;
    }

    property string replyQuotedText: ""
    property string replyQuotedMsgId: ""
    property string inlineInputText: ""

    property bool isSendingMessage: false
    property string pendingSendReqId: ""

    Timer {
        id: sendTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.isSendingMessage) {
                root.isSendingMessage = false;
                root.pendingSendReqId = "";
                notifyToast("Error: Send request timed out");
            }
        }
    }

    Connections {
        target: WhatsAppService
        function onMessageSendResult(reqId, success, error, data) {
            if (root.isSendingMessage && (reqId === root.pendingSendReqId || !reqId)) {
                sendTimeoutTimer.stop();
                root.isSendingMessage = false;
                root.pendingSendReqId = "";

                if (success) {
                    root.inlineInputText = "";
                    root.replyQuotedText = "";
                    root.replyQuotedMsgId = "";
                    notifyToast("Message sent");
                } else {
                    notifyToast("Send failed: " + (error || "Delivery error"));
                }
            }
        }
    }

    function startMessageReply(msgData) {
        if (!msgData) return;
        root.replyQuotedText = msgData.text || "";
        root.replyQuotedMsgId = msgData.id || "";
    }

    function sendInlineMessage() {
        if (root.isSendingMessage) return;

        const txt = root.inlineInputText.trim();
        if (!txt || !root.selectedChat) return;

        if (!WhatsAppService.daemonConnected) {
            notifyToast("Error: Daemon disconnected");
            return;
        }

        const recipient = root.selectedChat.id || root.selectedChat.recipient || root.selectedChat.name;
        const replyId = root.replyQuotedMsgId || null;

        root.isSendingMessage = true;
        const reqId = WhatsAppService.sendMessage(recipient, txt, replyId);
        root.pendingSendReqId = reqId || "";
        sendTimeoutTimer.restart();
    }

    readonly property var filteredChats: {
        var list = WhatsAppService.chats || [];
        if (root.chatListMode === "unread") {
            list = list.filter(c => (c.unreadCount || 0) > 0);
        }
        if (root.searchQuery.trim().length > 0) {
            var q = root.searchQuery.trim().toLowerCase();
            list = list.filter(c => {
                var nameMatch = c.name && c.name.toLowerCase().indexOf(q) !== -1;
                var msgMatch = c.lastMessage && c.lastMessage.toLowerCase().indexOf(q) !== -1;
                var idMatch = c.id && c.id.toLowerCase().indexOf(q) !== -1;
                return nameMatch || msgMatch || idMatch;
            });
        }
        if (root.maxChatCount > 0 && list.length > root.maxChatCount) {
            list = list.slice(0, root.maxChatCount);
        }
        return list;
    }

    readonly property var activeChats: filteredChats

    readonly property int totalUnreadCount: {
        var count = 0;
        var list = WhatsAppService.chats || [];
        for (var i = 0; i < list.length; i++) {
            count += (list[i].unreadCount || 0);
        }
        return count;
    }

    onModeChanged: GlobalStates.desktopWidgetKeyboardFocus = true
    onVisibleChanged: {
        if (!visible) GlobalStates.desktopWidgetKeyboardFocus = false;
    }
    Component.onCompleted: GlobalStates.desktopWidgetKeyboardFocus = true

    function switchMode(newMode) {
        if (root.mode === newMode && !flipAnim.running) return;
        root.targetMode = newMode;
        flipAnim.start();
    }

    function openMessageDetail(chatData, index) {
        root.selectedChat = chatData;
        root.selectedChatIndex = index;
        if (chatData && chatData.id) {
            WhatsAppService.getChatHistory(chatData.id, root.maxMessageHistory);
        }
        if (root.autoMarkAsRead && chatData && chatData.id) {
            WhatsAppService.markRead(chatData.id);
        }
        switchMode("detail");
    }

    function copyCurrentMessage() {
        if (root.selectedChat && root.selectedChat.lastMessage) {
            Quickshell.clipboardText = root.selectedChat.lastMessage;
            notifyToast("Copied to clipboard");
        }
    }

    function replyToCurrentMessage() {
        if (!root.selectedChat) return;
        root.replyQuotedText = root.selectedChat.lastMessage || "";
        root.recipientInput = root.selectedChat.name || root.selectedChat.recipient || "";
        root.messageInput = "";
        switchMode("send");
    }

    function markCurrentAsRead() {
        if (root.selectedChat && root.selectedChat.id) {
            WhatsAppService.markRead(root.selectedChat.id);
            root.selectedChat = Object.assign({}, root.selectedChat, { unreadCount: 0 });
            notifyToast("Marked as read");
        }
    }

    function openSendView() {
        root.replyQuotedText = "";
        root.recipientInput = "";
        root.messageInput = "";
        switchMode("send");
    }

    function cancelSendView() {
        root.replyQuotedText = "";
        root.recipientInput = "";
        root.messageInput = "";
        switchMode("list");
    }

    function handleSend() {
        if (root.recipientInput.trim().length === 0 || root.messageInput.trim().length === 0) return;

        const newContactName = root.recipientInput.trim();
        const newMsg = root.messageInput.trim();
        const replyToId = root.replyQuotedText ? (root.selectedChat ? root.selectedChat.id : null) : null;

        WhatsAppService.sendMessage(newContactName, newMsg, replyToId);
        notifyToast("Message queued");

        sendTimer.restart();
    }

    function notifyToast(msg) {
        root.toastText = msg;
        root.showToast = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 1800
        repeat: false
        onTriggered: root.showToast = false
    }

    Timer {
        id: sendTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.recipientInput = "";
            root.messageInput = "";
            switchMode("list");
        }
    }

    // INLINE COMPONENT CONTAINING THE FULL WHATSAPP UI CARD
    Component {
        id: cardComponent

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Appearance.rounding?.verylarge ?? 30
            color: Appearance.colors.colPrimaryContainer

            StyledRectangularShadow {
                target: card
                z: -2
            }

            // LIST VIEW PAGE
            ColumnLayout {
                id: listPage
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10
                visible: root.mode === "list"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: "WhatsApp"
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    // Total Unread Count Badge
                    Rectangle {
                        visible: root.showUnreadBadge && root.daemonState === "connected" && root.totalUnreadCount > 0
                        implicitWidth: Math.max(20, unreadCountText.implicitWidth + 8)
                        implicitHeight: 20
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary

                        StyledText {
                            id: unreadCountText
                            anchors.centerIn: parent
                            text: root.totalUnreadCount.toString()
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    // Presentation Mode Header Buttons
                    RowLayout {
                        spacing: 3

                        // Compact Button
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: root.presentationMode === "compact"
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 13
                                text: "crop_free"
                                color: root.presentationMode === "compact"
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchPresentationMode("compact")
                            }
                        }

                        // Expanded Button
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: root.presentationMode === "expanded"
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 13
                                text: "open_in_full"
                                color: root.presentationMode === "expanded"
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchPresentationMode("expanded")
                            }
                        }

                        // Pinned Button
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: root.presentationMode === "pinned"
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 13
                                text: "push_pin"
                                color: root.presentationMode === "pinned"
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchPresentationMode("pinned")
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Daemon Status Indicator Badge
                    Rectangle {
                        implicitWidth: daemonStatusRow.implicitWidth + 12
                        implicitHeight: 22
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(
                            root.daemonState === "connected" ? Appearance.colors.colPrimary : Appearance.colors.colOutline, 0.85)

                        RowLayout {
                            id: daemonStatusRow
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: root.daemonState === "connected" ? "#4CAF50" :
                                       root.daemonState === "authenticating" ? "#FF9800" :
                                       root.daemonState === "offline" ? "#FF9800" : "#9E9E9E"
                            }

                            StyledText {
                                text: root.daemonState === "connected" ? "Connected" :
                                      root.daemonState === "authenticating" ? "Authenticating" :
                                      root.daemonState === "offline" ? "Offline" : "Not configured"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.8
                            }
                        }
                    }

                    // Send Message action button
                    ToolbarPairedFab {
                        visible: root.daemonState === "connected"
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 34
                        iconText: "edit_square"
                        onClicked: root.openSendView()
                    }
                }

                // 1. NOT CONFIGURED STATE VIEW
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: 8
                    visible: root.daemonState === "not_configured"

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "settings_suggest"
                        iconSize: 42
                        color: Appearance.colors.colPrimary
                        opacity: 0.7
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Daemon Not Configured"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Requires a separate background daemon to sync messages."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    RippleButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        implicitHeight: 28
                        implicitWidth: setupBtnRow.implicitWidth + 20
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

                        onClicked: {
                            Qt.openUrlExternally(Config.options.background.widgets.whatsapp.daemonRepoUrl)
                        }

                        contentItem: RowLayout {
                            id: setupBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: "Setup daemon"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }

                            MaterialSymbol {
                                text: "open_in_new"
                                iconSize: 14
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                // 1.5 AUTHENTICATING STATE VIEW
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: 8
                    visible: root.daemonState === "authenticating"

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "qr_code_2"
                        iconSize: 42
                        color: Appearance.colors.colPrimary
                        opacity: 0.8
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Scan QR Code"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Daemon connected. Scan the QR code displayed in the daemon terminal to link WhatsApp."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }

                // 2. OFFLINE STATE VIEW
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: 8
                    visible: root.daemonState === "offline"

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "cloud_off"
                        iconSize: 42
                        color: Appearance.colors.colPrimary
                        opacity: 0.7
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Daemon Disconnected"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "WhatsApp daemon is offline. Start the daemon process to reconnect."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    RippleButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        implicitHeight: 28
                        implicitWidth: retryBtnRow.implicitWidth + 20
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

                        onClicked: {
                            WhatsAppService.connectToDaemon();
                        }

                        contentItem: RowLayout {
                            id: retryBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: "Reconnect"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }

                            MaterialSymbol {
                                text: "refresh"
                                iconSize: 14
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                // Local Search & Filter Controls Bar
                RowLayout {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    spacing: 6
                    visible: root.daemonState === "connected"

                    // Compact Search Input Box
                    Rectangle {
                        id: searchBox
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)
                        border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 4

                            MaterialSymbol {
                                text: "search"
                                iconSize: 14
                                color: Appearance.colors.colOnSurface
                                opacity: 0.6
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: searchInput.text.length === 0
                                    text: "Search..."
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurface
                                    opacity: 0.5
                                }

                                StyledTextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurface
                                    text: root.searchQuery
                                    onTextChanged: root.searchQuery = text
                                }
                            }

                            MaterialSymbol {
                                visible: root.searchQuery.length > 0
                                text: "close"
                                iconSize: 14
                                color: Appearance.colors.colOnSurface
                                opacity: 0.6
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.searchQuery = "";
                                        searchInput.text = "";
                                    }
                                }
                            }
                        }
                    }

                    // Filter Mode Toggle Button (All / Unread)
                    RippleButton {
                        implicitHeight: 28
                        implicitWidth: filterModeRow.implicitWidth + 14
                        buttonRadius: Appearance.rounding.full
                        colBackground: root.chatListMode === "unread"
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)

                        onClicked: {
                            root.chatListMode = (root.chatListMode === "unread" ? "recent" : "unread");
                            Config.options.background.widgets.whatsapp.chatListMode = root.chatListMode;
                        }

                        contentItem: RowLayout {
                            id: filterModeRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: root.chatListMode === "unread" ? "mark_chat_unread" : "chat"
                                iconSize: 13
                                color: root.chatListMode === "unread"
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }

                            StyledText {
                                text: root.chatListMode === "unread" ? "Unread" : "All"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: root.chatListMode === "unread"
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }
                        }
                    }
                }

                // 3. CONNECTED STATE: REAL RECENT CHATS LIST VIEW
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    clip: true
                    visible: root.daemonState === "connected"

                    // Empty Chat State Indicator
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: root.activeChats.length === 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.chatListMode === "unread" ? "mark_chat_read" : "chat_bubble_outline"
                            iconSize: 36
                            color: Appearance.colors.colPrimary
                            opacity: 0.5
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.chatListMode === "unread" ? "No unread messages" : "No recent chats"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            opacity: 0.6
                        }
                    }

                    // Real Chat List
                    ListView {
                        id: chatListView
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2
                        clip: true
                        visible: root.activeChats.length > 0
                        model: root.activeChats

                        ScrollBar.vertical: StyledScrollBar {
                            policy: ScrollBar.AlwaysOn
                            active: true
                        }

                        delegate: Item {
                            id: chatItem
                            required property var modelData
                            required property int index

                            width: chatListView.width
                            height: 54
                            implicitHeight: 54

                            property bool hovered: chatHoverArea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: chatItem.hovered
                                    ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.9)
                                    : "transparent"

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        margins: 6
                                    }
                                    spacing: 10

                                    MaterialShapeWrappedMaterialSymbol {
                                        shape: MaterialShape.Shape.Cookie12Sided
                                        color: Appearance.colors.colPrimary
                                        colSymbol: Appearance.colors.colOnPrimary
                                        text: (chatItem.modelData && chatItem.modelData.avatarIcon) ? chatItem.modelData.avatarIcon : ((chatItem.modelData && chatItem.modelData.id && chatItem.modelData.id.indexOf("@g.us") !== -1) ? "group" : "person")
                                        iconSize: 18
                                        padding: 6
                                        fill: 1
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: chatItem.modelData.name
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.weight: Font.DemiBold
                                                color: Appearance.colors.colOnPrimaryContainer
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                visible: root.showTimestamps
                                                text: chatItem.modelData.time
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colOnPrimaryContainer
                                                opacity: 0.6
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: (chatItem.modelData && chatItem.modelData.lastMessage) ? chatItem.modelData.lastMessage.replace(/[\r\n]+/g, " ") : ""
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnPrimaryContainer
                                                opacity: 0.7
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            Rectangle {
                                                visible: root.showUnreadBadge && chatItem.modelData.unreadCount > 0
                                                implicitWidth: Math.max(18, unreadText.implicitWidth + 8)
                                                implicitHeight: 18
                                                radius: 9
                                                color: Appearance.colors.colPrimary

                                                StyledText {
                                                    id: unreadText
                                                    anchors.centerIn: parent
                                                    text: chatItem.modelData.unreadCount.toString()
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    font.weight: Font.Bold
                                                    color: Appearance.colors.colOnPrimary
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: (mouse) => {
                                                        mouse.accepted = true;
                                                        if (chatItem.modelData && chatItem.modelData.id) {
                                                            WhatsAppService.markRead(chatItem.modelData.id);
                                                            notifyToast("Marked as read");
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: chatHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openMessageDetail(chatItem.modelData, chatItem.index)
                                }
                            }
                        }
                    }
                }
            }

            // MESSAGE DETAIL PAGE (PHASE 2 CONVERSATION SCREEN)
            ColumnLayout {
                id: detailPage
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 8
                visible: root.mode === "detail"

                // Conversation Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Back Navigation Button
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 18
                            text: "arrow_back"
                            color: Appearance.colors.colOnSurface
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchMode("list")
                        }
                    }

                    // Contact Avatar
                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: (root.selectedChat && root.selectedChat.avatarIcon) ? root.selectedChat.avatarIcon : ((root.selectedChat && root.selectedChat.id && root.selectedChat.id.indexOf("@g.us") !== -1) ? "group" : "person")
                        iconSize: 16
                        padding: 4
                        fill: 1
                    }

                    // Contact Name & Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: root.selectedChat ? root.selectedChat.name : "Conversation"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: "WhatsApp"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    // Manual Mark as Read Button
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 16
                            text: "done_all"
                            color: (root.selectedChat && root.selectedChat.unreadCount > 0)
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnSurface
                            opacity: (root.selectedChat && root.selectedChat.unreadCount > 0) ? 1.0 : 0.6
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.markCurrentAsRead()
                        }
                    }
                }

                // Conversation History Messages View Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    clip: true

                    // Loading State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: !WhatsAppService.activeChatHistory

                        MaterialLoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 28
                            implicitHeight: 28
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Loading messages..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            opacity: 0.6
                        }
                    }

                    // Empty History State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: WhatsAppService.activeChatHistory && WhatsAppService.activeChatHistory.length === 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "chat_bubble_outline"
                            iconSize: 36
                            color: Appearance.colors.colPrimary
                            opacity: 0.5
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No message history for this chat"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            opacity: 0.6
                        }
                    }

                    // Real Message History ListView
                    ListView {
                        id: messageHistoryView
                        anchors {
                            fill: parent
                            topMargin: 8
                            bottomMargin: 8
                            leftMargin: 8
                            rightMargin: 12
                        }
                        spacing: 6
                        clip: true
                        visible: WhatsAppService.activeChatHistory && WhatsAppService.activeChatHistory.length > 0
                        model: WhatsAppService.activeChatHistory || []

                        ScrollBar.vertical: StyledScrollBar {
                            policy: ScrollBar.AlwaysOn
                            active: true
                        }

                        onCountChanged: {
                            if (count > 0) {
                                messageHistoryView.positionViewAtEnd();
                            }
                        }

                        delegate: Item {
                            id: msgDelegate
                            required property var modelData
                            required property int index

                            width: messageHistoryView.width
                            height: bubbleRect.height + 8

                            readonly property bool isOutgoing: !!(msgDelegate.modelData && msgDelegate.modelData.fromMe)
                            property bool bubbleHovered: bubbleMouseArea.containsMouse

                            readonly property var quotedMsgData: {
                                if (!msgDelegate.modelData) return null;
                                if (msgDelegate.modelData.quotedMessage) return msgDelegate.modelData.quotedMessage;

                                // 1. Extract from rawMessage Baileys contextInfo
                                var rawCtx = null;
                                if (msgDelegate.modelData.rawMessage) {
                                    var rm = msgDelegate.modelData.rawMessage;
                                    if (rm.extendedTextMessage && rm.extendedTextMessage.contextInfo) {
                                        rawCtx = rm.extendedTextMessage.contextInfo;
                                    } else if (rm.contextInfo) {
                                        rawCtx = rm.contextInfo;
                                    }
                                }
                                if (rawCtx && rawCtx.quotedMessage) {
                                    var qMsg = rawCtx.quotedMessage;
                                    var qTxt = qMsg.conversation || (qMsg.extendedTextMessage ? qMsg.extendedTextMessage.text : "") || (qMsg.imageMessage ? (qMsg.imageMessage.caption || "Photo") : "");
                                    var qSender = (msgDelegate.modelData.fromMe ? (root.selectedChat ? root.selectedChat.name : "Contact") : "You");
                                    if (qTxt) {
                                        return { sender: qSender, text: qTxt };
                                    }
                                }

                                // 2. Resolve from activeChatHistory using replyToMessageId
                                if (msgDelegate.modelData.replyToMessageId && WhatsAppService.activeChatHistory) {
                                    var refId = msgDelegate.modelData.replyToMessageId;
                                    for (var i = 0; i < WhatsAppService.activeChatHistory.length; i++) {
                                        var item = WhatsAppService.activeChatHistory[i];
                                        if (item && item.id === refId) {
                                            return {
                                                sender: item.sender || (item.fromMe ? "You" : (root.selectedChat ? root.selectedChat.name : "Contact")),
                                                text: item.text || ""
                                            };
                                        }
                                    }
                                }
                                return null;
                            }

                            Rectangle {
                                id: bubbleRect
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                anchors.right: isOutgoing ? parent.right : undefined
                                anchors.left: isOutgoing ? undefined : parent.left
                                anchors.rightMargin: isOutgoing ? 4 : 0
                                readonly property real minBubbleWidth: messageHistoryView.width * 0.5
                                readonly property real maxBubbleWidth: messageHistoryView.width * 0.8
                                width: Math.min(maxBubbleWidth, Math.max(minBubbleWidth, contentCol.implicitWidth + 24))
                                height: contentCol.implicitHeight + 16
                                radius: 16
                                bottomRightRadius: isOutgoing ? 4 : 16
                                bottomLeftRadius: isOutgoing ? 16 : 4
                                color: isOutgoing
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.colors.colSurfaceContainerHighest

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                MouseArea {
                                    id: bubbleMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            root.startMessageReply(msgDelegate.modelData);
                                        }
                                    }
                                }

                                Column {
                                    id: contentCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    spacing: 4

                                    // Quoted Message Banner in Bubble
                                    Rectangle {
                                        id: quotedBanner
                                        width: parent.width
                                        height: visible ? (quotedCol.implicitHeight + 12) : 0
                                        radius: 8
                                        color: isOutgoing
                                            ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.88)
                                            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                                        visible: !!(msgDelegate.quotedMsgData && msgDelegate.quotedMsgData.text)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            anchors.topMargin: 4
                                            anchors.bottomMargin: 4
                                            spacing: 6

                                            Rectangle {
                                                implicitWidth: 3
                                                Layout.fillHeight: true
                                                color: Appearance.colors.colPrimary
                                                radius: 1.5
                                            }

                                            ColumnLayout {
                                                id: quotedCol
                                                Layout.fillWidth: true
                                                spacing: 1

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        var q = msgDelegate.quotedMsgData;
                                                        if (!q) return "";
                                                        return q.sender ? q.sender : (q.fromMe ? "You" : "Contact");
                                                    }
                                                    font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                                    font.weight: Font.Bold
                                                    color: Appearance.colors.colPrimary
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        var q = msgDelegate.quotedMsgData;
                                                        return q && q.text ? q.text : "";
                                                    }
                                                    font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                                    color: isOutgoing
                                                        ? Appearance.colors.colOnPrimaryContainer
                                                        : Appearance.colors.colOnSurface
                                                    opacity: 0.85
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                }
                                            }
                                        }
                                    }

                                    // Message Text
                                    StyledText {
                                        id: msgText
                                        width: parent.width
                                        text: (msgDelegate.modelData && msgDelegate.modelData.text) ? msgDelegate.modelData.text : ""
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: isOutgoing
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurface
                                        wrapMode: Text.Wrap
                                    }

                                    // Footer Row: Time + Tick + Hover Actions
                                    Row {
                                        anchors.right: parent.right
                                        spacing: 2
                                        visible: msgDelegate.modelData && msgDelegate.modelData.time

                                        // Action Buttons (Copy & Reply - always visible)
                                        Row {
                                            spacing: 2
                                            anchors.verticalCenter: parent.verticalCenter

                                            // Copy Button
                                            Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                radius: 10
                                                color: copyArea.containsMouse
                                                    ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                                    : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.4)

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    iconSize: 12
                                                    text: "content_copy"
                                                    color: isOutgoing
                                                        ? Appearance.colors.colOnPrimaryContainer
                                                        : Appearance.colors.colOnSurface
                                                    opacity: 0.8
                                                }

                                                MouseArea {
                                                    id: copyArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (msgDelegate.modelData && msgDelegate.modelData.text) {
                                                            Quickshell.clipboardText = msgDelegate.modelData.text;
                                                            root.notifyToast("Copied to clipboard");
                                                        }
                                                    }
                                                }
                                            }

                                            // Reply Button
                                            Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                radius: 10
                                                color: replyArea.containsMouse
                                                    ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                                    : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.4)

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    iconSize: 12
                                                    text: "reply"
                                                    color: isOutgoing
                                                        ? Appearance.colors.colOnPrimaryContainer
                                                        : Appearance.colors.colOnSurface
                                                    opacity: 0.8
                                                }

                                                MouseArea {
                                                    id: replyArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.startMessageReply(msgDelegate.modelData)
                                                }
                                            }
                                        }

                                        // Timestamp
                                        StyledText {
                                            text: (msgDelegate.modelData && msgDelegate.modelData.time) ? msgDelegate.modelData.time : ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                            color: isOutgoing
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colOnSurface
                                            opacity: 0.55
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        // Message Status Tick Icon (Outgoing messages only)
                                        MaterialSymbol {
                                            visible: isOutgoing
                                            iconSize: 13
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                var s = msgDelegate.modelData ? msgDelegate.modelData.status : "sent";
                                                if (s === "pending") return "schedule";
                                                if (s === "delivered" || s === "read") return "done_all";
                                                if (s === "error") return "error_outline";
                                                return "done";
                                            }
                                            color: {
                                                var s = msgDelegate.modelData ? msgDelegate.modelData.status : "sent";
                                                if (s === "read") return "#34B7F1";
                                                if (s === "error") return Appearance.colors.colError || "#FF5252";
                                                return Appearance.colors.colOnPrimaryContainer;
                                            }
                                            opacity: {
                                                var s = msgDelegate.modelData ? msgDelegate.modelData.status : "sent";
                                                return s === "read" ? 1.0 : 0.6;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // DOCKED INLINE COMPOSER & REPLY BAR
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Quoted Message Preview Banner
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Appearance.rounding.small
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                        visible: root.replyQuotedText.length > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Rectangle {
                                implicitWidth: 3
                                Layout.fillHeight: true
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    text: "Replying to message"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.replyQuotedText
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurface
                                    opacity: 0.8
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MaterialSymbol {
                                text: "close"
                                iconSize: 14
                                color: Appearance.colors.colOnSurface
                                opacity: 0.6
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.replyQuotedText = "";
                                        root.replyQuotedMsgId = "";
                                    }
                                }
                            }
                        }
                    }

                    // Composer Bar Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Composer Text Box
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Appearance.rounding.full
                            color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)
                            border.color: inlineInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    StyledText {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        visible: inlineInput.text.length === 0
                                        text: "Type a message..."
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSurface
                                        opacity: 0.5
                                    }

                                    StyledTextInput {
                                        id: inlineInput
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSurface
                                        text: root.inlineInputText
                                        onTextChanged: root.inlineInputText = text

                                        Keys.onReturnPressed: (event) => {
                                            if (event.modifiers & Qt.ShiftModifier) {
                                                event.accepted = false;
                                            } else {
                                                event.accepted = true;
                                                root.sendInlineMessage();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Send Action Button
                        RippleButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            colBackground: root.isSendingMessage ? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colPrimary
                            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)

                            onClicked: {
                                if (!root.isSendingMessage) {
                                    root.sendInlineMessage();
                                }
                            }

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.isSendingMessage ? "sync" : "send"
                                iconSize: 16
                                color: root.isSendingMessage ? Appearance.colors.colOnSurface : Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }

            // SEND MESSAGE PAGE
            ColumnLayout {
                id: sendPage
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10
                visible: root.mode === "send"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.5)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 18
                            text: "arrow_back"
                            color: Appearance.colors.colOnSurface
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelSendView()
                        }
                    }

                    StyledText {
                        text: "New Message"
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                // Quoted message preview banner
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                    visible: root.replyQuotedText.length > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle {
                            implicitWidth: 3
                            Layout.fillHeight: true
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: "Replying to message"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.replyQuotedText
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurface
                                opacity: 0.8
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MaterialSymbol {
                            text: "close"
                            iconSize: 14
                            color: Appearance.colors.colOnSurface
                            opacity: 0.6
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.replyQuotedText = ""
                            }
                        }
                    }
                }

                // Form Fields
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Recipient Field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Recipient (phone or JID)"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerLow

                            StyledTextInput {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer0
                                text: root.recipientInput
                                onTextChanged: root.recipientInput = text
                            }
                        }
                    }

                    // Message Area
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        StyledText {
                            text: "Message"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.min(130, Math.max(70, messageArea.implicitHeight + 16))
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerLow

                            Flickable {
                                id: messageFlickable
                                anchors.fill: parent
                                anchors.margins: 6
                                contentWidth: width
                                contentHeight: messageArea.implicitHeight
                                clip: true

                                ScrollBar.vertical: StyledScrollBar {}

                                TextArea {
                                    id: messageArea
                                    width: messageFlickable.width
                                    text: root.messageInput
                                    wrapMode: TextArea.Wrap
                                    placeholderText: "Type your message..."
                                    placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.5)
                                    color: Appearance.colors.colOnLayer0
                                    background: null
                                    onTextChanged: root.messageInput = text

                                    onCursorPositionChanged: {
                                        var rect = cursorRectangle;
                                        if (rect.y + rect.height > messageFlickable.contentY + messageFlickable.height) {
                                            messageFlickable.contentY = rect.y + rect.height - messageFlickable.height;
                                        } else if (rect.y < messageFlickable.contentY) {
                                            messageFlickable.contentY = rect.y;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Send Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        DialogButton {
                            buttonText: "Cancel"
                            onClicked: root.cancelSendView()
                        }

                        DialogButton {
                            buttonText: "Send"
                            enabled: root.recipientInput.trim().length > 0 && root.messageInput.trim().length > 0
                            colEnabled: Appearance.colors.colPrimary
                            colDisabled: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.6)
                            onClicked: root.handleSend()
                        }
                    }
                }
            }

            // TOAST NOTIFICATION OVERLAY
            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 14
                }
                implicitWidth: toastRow.implicitWidth + 24
                implicitHeight: 32
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimary
                opacity: root.showToast ? 1 : 0
                visible: opacity > 0
                z: 10

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                RowLayout {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "check_circle"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        text: root.toastText
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale
                property: "xScale"
                to: 0
                duration: 150
                easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.mode = root.targetMode
            }
            NumberAnimation {
                target: flipScale
                property: "xScale"
                to: 1
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        // Compact Mode: Full WhatsApp UI
        Loader {
            anchors.fill: parent
            active: root.presentationMode === "compact"
            sourceComponent: cardComponent
        }

        // Desktop Background Canvas Placeholder when active in Overlay Mode
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding?.verylarge ?? 30
            color: Appearance.colors.colPrimaryContainer
            visible: root.presentationMode !== "compact"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.presentationMode === "expanded" ? "open_in_full" : "push_pin"
                    iconSize: 36
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.presentationMode === "expanded" ? "Active in Expanded Mode" : "Active in Pinned Mode"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }

                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 28
                    implicitWidth: 140
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimary

                    onClicked: root.switchPresentationMode("compact")

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: "Return to Compact"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    // TOP OVERLAY WINDOW (FOR EXPANDED AND PINNED PRESENTATION MODES)
    Loader {
        id: presentationOverlayLoader
        active: root.presentationMode === "expanded" || root.presentationMode === "pinned"

        sourceComponent: PanelWindow {
            id: overlayWindow
            WlrLayershell.namespace: "quickshell:whatsapp-presentation"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.presentationMode === "expanded" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            mask: Region {
                item: root.presentationMode === "pinned" ? floatingCardContainer : null
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Dimmed Backdrop for Expanded Mode
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                visible: root.presentationMode === "expanded"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.switchPresentationMode("compact")
                }
            }

            // Floating Overlay Card Container
            Item {
                id: floatingCardContainer
                anchors.centerIn: root.presentationMode === "expanded" ? parent : undefined

                x: root.presentationMode === "pinned"
                    ? (root.pinnedX >= 0 ? root.pinnedX : parent.width - width - 36)
                    : (root.presentationMode === "expanded" ? (parent.width - width) / 2 : 0)
                y: root.presentationMode === "pinned"
                    ? (root.pinnedY >= 0 ? root.pinnedY : 36)
                    : (root.presentationMode === "expanded" ? (parent.height - height) / 2 : 0)

                width: root.presentationMode === "expanded" ? 680 : 480
                height: root.presentationMode === "expanded" ? 520 : 380

                // MouseArea for dragging in Pinned Mode & trapping clicks in Expanded Mode
                MouseArea {
                    id: containerMouseArea
                    anchors.fill: parent
                    cursorShape: (root.presentationMode === "pinned" && pressed) ? Qt.ClosedHandCursor : Qt.ArrowCursor

                    property point clickPos: "0,0"

                    onPressed: (mouse) => {
                        mouse.accepted = true;
                        clickPos = Qt.point(mouse.x, mouse.y);
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed && root.presentationMode === "pinned") {
                            var deltaX = mouse.x - clickPos.x;
                            var deltaY = mouse.y - clickPos.y;
                            var newX = Math.max(0, Math.min(floatingCardContainer.x + deltaX, overlayWindow.width - floatingCardContainer.width));
                            var newY = Math.max(0, Math.min(floatingCardContainer.y + deltaY, overlayWindow.height - floatingCardContainer.height));

                            floatingCardContainer.x = newX;
                            floatingCardContainer.y = newY;
                            root.pinnedX = newX;
                            root.pinnedY = newY;
                            Config.options.background.widgets.whatsapp.pinnedX = newX;
                            Config.options.background.widgets.whatsapp.pinnedY = newY;
                        }
                    }
                }

                // Full WhatsApp UI Component inside Overlay Window
                Loader {
                    anchors.fill: parent
                    sourceComponent: cardComponent
                }
            }
        }
    }
}
