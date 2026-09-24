import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: notifs
    required property Item di
    anchors.fill: parent

    readonly property var notif: notifs.di.shownNotification ?? notifs.di.latestNotification
    readonly property bool critical: notifs.di.latestNotificationCritical
    readonly property var parts: IslandEvents.notificationParts(notifs.notif)
    readonly property var group: Notifications.popupGroupsByAppName[notifs.notif?.appName ?? ""]
    readonly property int stackCount: notifs.group?.notifications.length ?? 1
    // Messages from the same conversation collapse into one line with a count
    // Messages from the same person in a row: counted from the history (last 15 min), not only from what's still
    // on screen, so the number keeps climbing while they keep writing
    readonly property int conversationCount: {
        const key = IslandEvents.conversationKey(notifs.notif)
        const since = Date.now() - 15 * 60000
        const recent = Notifications.list.filter(n => (n.time ?? 0) >= since && IslandEvents.conversationKey(n) === key).length
        const shown = notifs.di.visibleNotifications.filter(n => IslandEvents.conversationKey(n) === key).length
        return Math.max(1, recent, shown)
    }
    readonly property bool hasImage: (notifs.notif?.image ?? "") !== ""
    // Shared with the full view: the contact picture travels into it
    readonly property var hero: notifs.hasImage ? { key: "notif-avatar", item: avatarCircle } : null
    readonly property bool messaging: IslandEvents.isMessagingApp(notifs.parts.app)
    readonly property bool pointerOn: notifs.di.hoverArmed
    readonly property color accent: notifs.critical ? Appearance.colors.colError : IslandEvents.appColor(notifs.parts.app, Appearance.colors.colPrimary)

    Rectangle {
        anchors.fill: parent
        visible: !notifs.messaging
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.transparentize(notifs.accent, 0.7)
    }

    // "Kettily · Certo" doesn't deserve the same pill as a long message. These copies are never drawn; they only
    // measure the text, so the island can ask for the width this notification actually needs.
    Item {
        id: measure
        visible: false

        StyledText {
            id: titleMeasure
            text: notifs.parts.title || notifs.parts.app
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
        }
        StyledText {
            id: authorMeasure
            text: notifs.parts.author !== "" ? `${notifs.parts.author}:` : ""
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
        }
        StyledText {
            id: bodyMeasure
            text: notifs.parts.body
            font.pixelSize: Appearance.font.pixelSize.smallie
        }
        StyledText {
            id: countMeasure
            text: Translation.tr("%1 messages").arg(notifs.conversationCount)
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
        }
    }

    readonly property real naturalWidth: notifs.messaging ? notifs.chatWidth : notifs.lineWidth
    readonly property real chatWidth: {
        const stack = Math.min(2, notifs.stackCount - 1)
        const line1 = Math.min(300, titleMeasure.implicitWidth)
        const line2 = Math.min(300, bodyMeasure.implicitWidth + (notifs.parts.author !== "" ? authorMeasure.implicitWidth + 4 : 0)
            + (notifs.parts.media !== null ? 19 : 0))
        return (notifs.di.isMaterial ? 3 : 5) + 30 + 10 + stack * 3 + Math.max(line1, line2) + 18
    }
    readonly property real lineWidth: {
        const stack = Math.min(2, notifs.stackCount - 1)
        let width = (notifs.di.isMaterial ? 3 : 5) + 26 + 9 + stack * 3   // avatar and its margins
        width += Math.min(220, titleMeasure.implicitWidth)
        if (notifs.conversationCount === 2) width += 28
        else if (notifs.conversationCount >= 3) width += countMeasure.implicitWidth + 6
        if (notifs.parts.author !== "") width += Math.min(110, authorMeasure.implicitWidth) + 6
        if (notifs.parts.media !== null) width += 21
        if (notifs.parts.body !== "") width += Math.min(240, bodyMeasure.implicitWidth) + 6
        return width + 8 + 14   // right padding, and room for the pill's own rounding
    }

    // Arrival, kept quiet so it never gets between you and the words: the photo settles in and the two lines
    // fade up a couple of pixels, in about a quarter of a second
    property real t: 0
    readonly property string notifKey: `${notifs.notif?.notificationId ?? ""}`
    onNotifKeyChanged: arrival.restart()
    Component.onDestruction: arrival.stop()
    NumberAnimation {
        id: arrival
        target: notifs
        property: "t"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
        running: true
    }
    readonly property real popIn: notifs.t

    onNaturalWidthChanged: notifs.di.notifContentWidth = notifs.naturalWidth
    Component.onCompleted: notifs.di.notifContentWidth = notifs.naturalWidth

    // OutBack on 0..1, for the photo's pop
    function back(x) {
        const c1 = 1.9
        return 1 + (c1 + 1) * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2)
    }

    Item {
        id: avatar
        x: notifs.di.isMaterial ? 3 : 5
        scale: notifs.messaging ? 0.88 + 0.12 * notifs.popIn : 1

        DiEntrance { target: avatar }
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26

        // Stacked cards peeking behind the avatar
        Repeater {
            model: Math.min(2, notifs.stackCount - 1)
            delegate: Rectangle {
                required property int index
                x: 4 + index * 3
                y: 0
                width: 26
                height: 26
                radius: 13
                color: ColorUtils.transparentize(notifs.accent, 0.55 + index * 0.2)
            }
        }

        // Chats: how many messages in a row, on the photo; it bumps every time another one arrives
        Rectangle {
            id: countBadge
            visible: notifs.messaging && notifs.conversationCount >= 2
            z: 3
            anchors {
                right: avatarCircle.right
                top: avatarCircle.top
                rightMargin: -5
                topMargin: -4
            }
            width: Math.max(15, countBadgeText.implicitWidth + 7)
            height: 15
            radius: 7.5
            color: notifs.accent
            border.width: 1.5
            border.color: notifs.di.capsuleColor

            StyledText {
                id: countBadgeText
                anchors.centerIn: parent
                text: notifs.conversationCount > 99 ? "99+" : notifs.conversationCount
                font.pixelSize: 9
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: ColorUtils.isDark(notifs.accent) ? "white" : "black"
            }

            SequentialAnimation on scale {
                id: badgeBump
                running: false
                NumberAnimation { to: 1.35; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
        }
        Connections {
            target: notifs
            function onConversationCountChanged() { if (notifs.conversationCount >= 2) badgeBump.restart() }
        }

        // Chats: a thin ring in the app's colour instead of an outline around the whole pill
        Rectangle {
            visible: notifs.messaging
            anchors.centerIn: avatarCircle
            width: avatarCircle.width + 5
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: notifs.accent
            opacity: 0.9 * notifs.popIn
        }

        Rectangle {
            id: avatarCircle
            anchors.fill: parent
            radius: width / 2
            color: ColorUtils.transparentize(notifs.accent, 0.8)

            Loader {
                anchors.fill: parent
                active: notifs.hasImage
                sourceComponent: Item {
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatarCircle.width
                            height: avatarCircle.height
                            radius: avatarCircle.radius
                        }
                    }
                    AnimatedImage {
                        anchors.fill: parent
                        source: /\.(gif|webp)$/i.test(notifs.notif?.image ?? "") ? notifs.notif.image : ""
                        visible: source !== ""
                        fillMode: Image.PreserveAspectCrop
                    }
                    Image {
                        anchors.fill: parent
                        source: /\.(gif|webp)$/i.test(notifs.notif?.image ?? "") ? "" : (notifs.notif?.image ?? "")
                        visible: source !== ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 64
                        sourceSize.height: 64
                        asynchronous: true
                    }
                }
            }

            // No contact picture: the app's own mark, then its system icon, then a plain bell
            DiBrandIcon {
                anchors.centerIn: parent
                visible: !notifs.hasImage && notifs.parts.brand !== ""
                source: notifs.parts.brand
                size: 15
                color: notifs.accent
            }

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: !notifs.hasImage && notifs.parts.brand === "" && (notifs.notif?.appIcon ?? "") !== ""
                source: Quickshell.iconPath(notifs.notif?.appIcon ?? "", "notification-symbolic")
                sourceSize.width: 36
                sourceSize.height: 36
                asynchronous: true
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !notifs.hasImage && notifs.parts.brand === "" && (notifs.notif?.appIcon ?? "") === ""
                text: notifs.critical ? "priority_high" : "notifications"
                iconSize: 15
                fill: 1
                color: notifs.accent
            }
        }

        // App badge over the contact picture: the app's own mark (WhatsApp, Telegram…), not the browser's
        Rectangle {
            visible: notifs.hasImage && (notifs.parts.brand !== "" || (notifs.notif?.appIcon ?? "") !== "")
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: -3
                bottomMargin: -2
            }
            width: 14
            height: 14
            radius: 7
            color: Appearance.colors.colLayer0

            DiBrandIcon {
                anchors.centerIn: parent
                source: notifs.parts.brand
                size: 10
                color: notifs.accent
            }
            Image {
                anchors.centerIn: parent
                visible: notifs.parts.brand === ""
                width: 11
                height: 11
                source: Quickshell.iconPath(notifs.notif?.appIcon ?? "", "notification-symbolic")
                sourceSize.width: 22
                sourceSize.height: 22
            }
        }
    }

    // One readable line: sender (and message count), group author, media kind, message
    RowLayout {
        id: textRow
        visible: !notifs.messaging
        anchors {
            left: avatar.right
            leftMargin: 9 + Math.min(2, notifs.stackCount - 1) * 3
            right: trailing.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        StyledText {
            Layout.maximumWidth: notifs.parts.body !== "" ? textRow.width * 0.42 : textRow.width
            text: notifs.parts.title || notifs.parts.app
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
            color: notifs.critical ? Appearance.colors.colError : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Rectangle {
            visible: notifs.conversationCount === 2
            Layout.preferredWidth: Math.max(18, countText.implicitWidth + 8)
            Layout.preferredHeight: 16
            Layout.leftMargin: -2
            radius: 8
            color: ColorUtils.transparentize(notifs.accent, 0.7)

            StyledText {
                id: countText
                anchors.centerIn: parent
                text: notifs.conversationCount
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
        }

        StyledText {
            visible: notifs.parts.author !== ""
            Layout.maximumWidth: textRow.width * 0.25
            text: `${notifs.parts.author}:`
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
            color: notifs.accent
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        MaterialSymbol {
            visible: notifs.parts.media !== null
            text: notifs.parts.media?.icon ?? ""
            iconSize: 15
            fill: 1
            color: Appearance.colors.colOnLayer0
            opacity: 0.85
        }

        // Three or more from the same conversation: say how many and show only the last one, instead of
        // replacing the island on every message
        StyledText {
            visible: notifs.conversationCount >= 3
            text: Translation.tr("%1 messages").arg(notifs.conversationCount)
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.DemiBold
            color: notifs.accent
        }

        // Long messages scroll slowly while the pointer is on the island
        Item {
            id: bodyClip
            Layout.fillWidth: true
            Layout.preferredHeight: bodyText.implicitHeight
            visible: notifs.parts.body !== ""
            clip: bodyClip.scrolling

            readonly property real overflow: Math.max(0, bodyText.implicitWidth - bodyClip.width)
            readonly property bool scrolling: notifs.pointerOn && bodyClip.overflow > 4

            StyledText {
                id: bodyText
                anchors.verticalCenter: parent.verticalCenter
                width: bodyClip.scrolling ? implicitWidth : bodyClip.width
                text: notifs.parts.body
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colOnLayer0
                opacity: 0.88
                elide: bodyClip.scrolling ? Text.ElideNone : Text.ElideRight
                maximumLineCount: 1
            }

            SequentialAnimation {
                running: bodyClip.scrolling
                loops: Animation.Infinite
                onRunningChanged: if (!running) bodyText.x = 0

                PauseAnimation { duration: 900 }
                NumberAnimation {
                    target: bodyText
                    property: "x"
                    to: -bodyClip.overflow
                    duration: Math.max(1200, bodyClip.overflow * 28)
                    easing.type: Easing.InOutSine
                }
                PauseAnimation { duration: 1400 }
                NumberAnimation {
                    target: bodyText
                    property: "x"
                    to: 0
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Chats: two lines — who wrote, and then the message with the whole width to itself
    Item {
        id: chatText
        visible: notifs.messaging
        anchors {
            left: avatar.right
            leftMargin: 11 + Math.min(2, notifs.stackCount - 1) * 3
            right: trailing.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        height: chatColumn.implicitHeight

        ColumnLayout {
            id: chatColumn
            anchors {
                left: parent.left
                right: parent.right
            }
            spacing: -3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                opacity: notifs.popIn
                transform: Translate { y: (1 - notifs.popIn) * 3 }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: notifs.parts.title || notifs.parts.app
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: notifs.critical ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: chatBody.implicitHeight

                Item {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width
                    height: chatBody.implicitHeight
                    opacity: notifs.popIn
                    transform: Translate { y: (1 - notifs.popIn) * 3 }

                    RowLayout {
                        id: chatBody
                        width: chatText.width
                        spacing: 4

                        MaterialSymbol {
                            visible: notifs.parts.media !== null
                            text: notifs.parts.media?.icon ?? ""
                            iconSize: 14
                            fill: 1
                            color: notifs.accent
                        }
                        StyledText {
                            visible: notifs.parts.author !== ""
                            Layout.maximumWidth: chatText.width * 0.35
                            text: `${notifs.parts.author}:`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: notifs.accent
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: notifs.parts.body || (notifs.parts.media?.label ?? "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.85
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }
    }

    // Tapping the message goes to the app; tapping the picture opens the full view with reply
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandEvents.openNotificationSource(notifs.notif)
    }

    MouseArea {
        x: avatar.x - 4
        y: 0
        width: avatar.width + 8 + Math.min(2, notifs.stackCount - 1) * 3
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: notifs.di.toggleExpanded()
    }

    // Quick reply shortcut, only for chats and only under the pointer
    Item {
        id: trailing
        readonly property bool shown: notifs.messaging && notifs.pointerOn
        anchors {
            right: parent.right
            rightMargin: trailing.shown ? 4 : 10
            verticalCenter: parent.verticalCenter
        }
        implicitWidth: trailing.shown ? 24 : 0
        implicitHeight: 24

        Behavior on implicitWidth {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: 12
            scale: trailing.shown ? 1 : 0.6
            opacity: trailing.shown ? 1 : 0
            color: replyMouse.containsMouse ? notifs.accent : ColorUtils.transparentize(notifs.accent, 0.7)

            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "reply"
                iconSize: 15
                fill: 1
                color: replyMouse.containsMouse && !ColorUtils.isDark(notifs.accent) ? "black" : Appearance.colors.colOnLayer0
            }

            MouseArea {
                id: replyMouse
                anchors.fill: parent
                enabled: trailing.shown
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notifs.di.requestReply()
            }
        }
    }
}
