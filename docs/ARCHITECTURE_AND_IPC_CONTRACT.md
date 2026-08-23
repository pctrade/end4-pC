# whatsapp-widget-daemon — Daemon Architecture & IPC Contract Specification

## 1. Overview & System Boundaries

`whatsapp-widget-daemon` is a lightweight, headless, event-driven Node.js/TypeScript daemon designed for the `end4-pC` WhatsApp desktop widget (`WhatsAppWidget.qml`).

- **Decoupled Architecture:** The widget UI running inside Quickshell communicates with `whatsapp-widget-daemon` strictly over a Unix Domain Socket IPC interface.
- **WhatsApp Web Protocol:** Powered by `@whiskeysockets/baileys`, operating directly via WhatsApp Web WebSocket protocol without requiring heavy browser binaries (Puppeteer/Chromium).
- **Event-Driven & Polling-Free:** Operates 100% on asynchronous socket events for incoming messages, connection state transitions, and IPC requests.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    WhatsApp Web WS                      │
└───────────────────────────┬─────────────────────────────┘
                            │ Baileys Protocol Connection
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   whatsapp-widget-daemon                │
│                                                         │
│  ┌───────────────────────┐   ┌───────────────────────┐  │
│  │   WhatsApp Client     │   │   Message Normalizer  │  │
│  │ (Auth / Auto-reconnect)│──►│ (JID & Schema Format) │  │
│  └───────────┬───────────┘   └───────────┬───────────┘  │
│              │                           │              │
│              ▼                           ▼              │
│  ┌───────────────────────────────────────────────────┐  │
│  │                 State Manager                     │  │
│  │  - Unread Chats List (capped by maxUnreadChats)   │  │
│  │  - Ring Buffer History (capped by maxHistory)     │  │
│  │  - Persistent Cache (~/.config/.../state.json)    │  │
│  └───────────────────────┬───────────────────────────┘  │
│                          │                              │
│                          ▼                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │             IPC Server (Unix Socket)              │  │
│  │   Path: /run/user/<uid>/whatsapp-daemon.sock      │  │
│  └───────────────────────┬───────────────────────────┘  │
└──────────────────────────┼──────────────────────────────┘
                           │ Framed JSON Messages (\n)
                           ▼
┌─────────────────────────────────────────────────────────┐
│              end4-pC Quickshell Environment             │
│                 (WhatsAppWidget.qml)                    │
└──────────────────────────┴──────────────────────────────┘
```

---

## 3. Unix Socket IPC Contract Specification

### Socket Location
Primary: `/run/user/<UID>/whatsapp-daemon.sock`
Fallback: `~/.local/share/whatsapp-widget-daemon/whatsapp-daemon.sock`

### Framing Protocol
- All transport occurs via UTF-8 JSON text over Unix Domain Socket.
- Every message (inbound and outbound) is framed by a trailing newline (`\n`).

---

### A. Inbound Events (Daemon ➔ Widget)

#### 1. `status_changed`
Emitted automatically whenever the WhatsApp connection status or session state changes. Includes `daemonConfigured` and `daemonConnected` fields matching the QML widget contract.

```json
{
  "event": "status_changed",
  "daemonConfigured": true,
  "daemonConnected": true,
  "configured": true,
  "connected": true,
  "status": "connected",
  "qr": null
}
```

*Status Enum Values:*
- `"unconfigured"`: No session auth credentials exist. QR authentication required.
- `"authenticating"`: QR code generated and awaiting user scan.
- `"connected"`: Live WhatsApp Web WebSocket connection active.
- `"offline"`: Configured session exists but network or connection is down (reconnecting).

#### 2. `unread_chats_updated`
Emitted whenever unread messages arrive, messages are sent, or chats are marked as read.

```json
{
  "event": "unread_chats_updated",
  "chats": [
    {
      "id": "923001234567@s.whatsapp.net",
      "name": "Ahmed",
      "lastMessage": "Hey, did you see the update?",
      "time": "10:42 AM",
      "unreadCount": 2,
      "avatarIcon": "person",
      "timestamp": 1755910000
    }
  ]
}
```

#### 3. `chat_history_updated`
Emitted in response to `get_chat_history` or when new messages arrive for an open detail view.

```json
{
  "event": "chat_history_updated",
  "chatId": "923001234567@s.whatsapp.net",
  "messages": [
    {
      "id": "3EB0ABC12345",
      "sender": "Ahmed",
      "fromMe": false,
      "text": "Hey, did you see the update?",
      "time": "10:42 AM",
      "timestamp": 1755910000
    }
  ]
}
```

#### 4. `response`
Emitted as confirmation for outbound requests.

```json
{
  "type": "response",
  "id": "req-001",
  "action": "send_message",
  "success": true,
  "error": null
}
```

---

### B. Outbound Requests (Widget ➔ Daemon)

#### 1. `send_message`
Sends a message or reply to a recipient. Supports raw phone numbers (e.g. `"923001234567"`), `@c.us` IDs (e.g. `"12036304@c.us"`), and `@s.whatsapp.net` JIDs.

```json
{
  "id": "req-001",
  "action": "send_message",
  "recipient": "923001234567",
  "message": "Hello world",
  "replyToMessageId": "optional_quoted_id"
}
```

#### 2. `mark_read`
Marks all messages in a specific chat as read. Accepts raw phone numbers, `@c.us` IDs, and `@s.whatsapp.net` JIDs.

```json
{
  "id": "req-002",
  "action": "mark_read",
  "chatId": "12036304@c.us"
}
```

#### 3. `get_status`
Queries current daemon status immediately upon widget initialization.

```json
{
  "id": "req-003",
  "action": "get_status"
}
```

#### 4. `get_unread_chats`
Queries current list of unread chats.

```json
{
  "id": "req-004",
  "action": "get_unread_chats"
}
```

#### 5. `get_chat_history`
Queries message history ring buffer for a given chat.

```json
{
  "id": "req-005",
  "action": "get_chat_history",
  "chatId": "923001234567@s.whatsapp.net",
  "limit": 25
}
```

#### 6. `sync_config`
Pushes widget options schema parameters to daemon.

```json
{
  "id": "req-006",
  "action": "sync_config",
  "config": {
    "maxUnreadChats": 5,
    "maxMessageHistory": 25,
    "autoMarkAsRead": false
  }
}
```

---

## 4. Reconnection & Resilience Strategy

1. **Exponential Backoff:** If the WebSocket connection drops, reconnection is retried at intervals of 2s, 4s, 8s, 16s, up to max 60s.
2. **Network Offline Detection:** Listens to system network state transitions and immediately triggers connection retry when network recovers.
3. **Session Auto-Recovery:** Restores session state from `~/.config/whatsapp-widget-daemon/session/` without requiring re-authentication unless credentials are revoked.
4. **Clean Socket Lifecycle & Signal Trapping:** Traps `SIGINT`, `SIGTERM`, `SIGHUP`. On exit, unlinks socket file cleanly and closes connections gracefully.
