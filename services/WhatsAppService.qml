pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    signal messageSendResult(string reqId, bool success, string error, var responseData)

    property bool daemonConfigured: Config.options.background.widgets.whatsapp.daemonConfigured ?? false
    property bool daemonConnected: false
    property string connectionStatus: "unconfigured"
    property var chats: []
    property var activeChatHistory: []
    property string activeChatId: ""

    readonly property string socketPath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + (Quickshell.env("UID") || "1000"));
        return runtimeDir + "/whatsapp-daemon.sock";
    }

    Process {
        id: socketProc
        command: ["socat", "-", "UNIX-CONNECT:" + root.socketPath]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                root.handleIPCMessage(line);
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.daemonConnected = false;
            root.connectionStatus = "offline";
            reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.connectToDaemon();
        }
    }

    function connectToDaemon() {
        if (socketProc.running) {
            socketProc.running = false;
        }
        socketProc.running = true;
    }

    function sendIPC(payload) {
        if (socketProc.running) {
            socketProc.write(JSON.stringify(payload) + "\n");
        }
    }

    function requestStatus() {
        sendIPC({ "action": "get_status" });
    }

    function requestUnreadChats() {
        sendIPC({ "action": "get_unread_chats" });
    }

    function handleIPCMessage(rawMessage) {
        try {
            const trimmed = rawMessage.trim();
            if (!trimmed) return;
            const msg = JSON.parse(trimmed);

            if (msg.event === "status_changed") {
                root.daemonConfigured = (msg.daemonConfigured !== undefined ? msg.daemonConfigured : (msg.configured ?? false));
                root.daemonConnected = (msg.daemonConnected !== undefined ? msg.daemonConnected : (msg.connected ?? false));
                root.connectionStatus = msg.status ?? "unconfigured";
                Config.options.background.widgets.whatsapp.daemonConfigured = root.daemonConfigured;
                Config.options.background.widgets.whatsapp.daemonConnected = root.daemonConnected;
            } else if (msg.event === "unread_chats_updated" || msg.event === "recent_chats_updated") {
                root.chats = msg.chats || [];
            } else if (msg.event === "chat_history_updated") {
                if (msg.chatId === root.activeChatId) {
                    root.activeChatHistory = (msg.messages || []).slice();
                }
            } else if (msg.event === "message_status_updated") {
                if (msg.chatId === root.activeChatId && root.activeChatHistory) {
                    let current = [];
                    for (let i = 0; i < root.activeChatHistory.length; i++) {
                        let m = root.activeChatHistory[i];
                        if (m && m.id === msg.messageId) {
                            let copy = {};
                            for (let k in m) { copy[k] = m[k]; }
                            copy.status = msg.status;
                            current.push(copy);
                        } else {
                            current.push(m);
                        }
                    }
                    root.activeChatHistory = null;
                    root.activeChatHistory = current;
                }
            } else if (msg.event === "message_received") {
                if (msg.message && msg.message.chatId === root.activeChatId) {
                    let currentHist = root.activeChatHistory ? root.activeChatHistory.slice() : [];
                    if (!currentHist.some(m => m.id === msg.message.id)) {
                        currentHist.push(msg.message);
                        root.activeChatHistory = currentHist;
                    }
                }
            } else if (msg.event === "chat_updated") {
                if (msg.chat && root.chats) {
                    let found = false;
                    let updated = root.chats.map(c => {
                        if (c.id === msg.chat.id) {
                            found = true;
                            return msg.chat;
                        }
                        return c;
                    });
                    if (!found) {
                        updated.unshift(msg.chat);
                    }
                    root.chats = updated;
                }
            } else if (msg.event === "read_state_updated") {
                if (msg.chatId && root.chats) {
                    root.chats = root.chats.map(c => c.id === msg.chatId ? Object.assign({}, c, { unreadCount: 0 }) : c);
                }
            } else if (msg.type === "response") {
                if (msg.action === "send_message") {
                    const reqId = msg.id || "";
                    const success = !!msg.success;
                    const errorMsg = msg.error || "";
                    root.messageSendResult(reqId, success, errorMsg, msg.data || null);
                }
            }
        } catch (e) {
            console.log("[WhatsAppService] IPC parse error: " + e);
        }
    }

    function sendMessage(recipient, messageText, replyToId) {
        const reqId = "send_" + Date.now() + "_" + Math.floor(Math.random() * 100000);
        let payload = {
            "action": "send_message",
            "id": reqId,
            "recipient": recipient,
            "message": messageText
        };
        if (replyToId) {
            payload["replyToMessageId"] = replyToId;
        }

        if (!root.daemonConnected) {
            Qt.callLater(() => {
                root.messageSendResult(reqId, false, "Daemon is disconnected", null);
            });
            return reqId;
        }

        sendIPC(payload);
        return reqId;
    }

    function markRead(chatId) {
        if (!chatId) return;
        sendIPC({
            "action": "mark_read",
            "chatId": chatId
        });

        if (root.chats && root.chats.length > 0) {
            let updated = [];
            for (let i = 0; i < root.chats.length; i++) {
                let c = root.chats[i];
                if (c.id === chatId || c.recipient === chatId) {
                    updated.push(Object.assign({}, c, { unreadCount: 0 }));
                } else {
                    updated.push(c);
                }
            }
            root.chats = updated;
        }
    }

    function getChatHistory(chatId, limit) {
        if (!chatId) return;
        root.activeChatId = chatId;
        root.activeChatHistory = null;
        sendIPC({
            "action": "get_chat_history",
            "chatId": chatId,
            "limit": limit || 25
        });
    }

    function syncConfig() {
        sendIPC({
            "action": "sync_config",
            "config": {
                "maxUnreadChats": Config.options.background.widgets.whatsapp.maxUnreadChats,
                "maxMessageHistory": Config.options.background.widgets.whatsapp.maxMessageHistory,
                "autoMarkAsRead": Config.options.background.widgets.whatsapp.autoMarkAsRead
            }
        });
    }

    Component.onCompleted: {
        root.connectToDaemon();
    }
}
