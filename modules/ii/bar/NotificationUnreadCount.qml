import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    readonly property bool isDi: GlobalStates.dynamicIslandEnabled && (Config.options.bar.dynamicIsland.leftWidgets.includes("systemIcons")
        || Config.options.bar.dynamicIsland.rightWidgets.includes("systemIcons"))

    text: Notifications.silent ? "notifications_paused" : "notifications"
    iconSize: Appearance.font.pixelSize.larger
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    color: root.contentColorOverridden ? root.contentColor : (root.isDi ? Appearance.colors.colOnLayer1 : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))

    Rectangle {
        id: notifPing
        visible: !Notifications.silent && Notifications.unread > 0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.rounding.full
        color: root.isDi ? Appearance.colors.colOnLayer1 : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0)
        z: 1

        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) : 8
        implicitWidth: implicitHeight

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.isDi ? Appearance.colors.colOnPrimary : (root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colLayer0)
            text: Notifications.unread
        }
    }
}