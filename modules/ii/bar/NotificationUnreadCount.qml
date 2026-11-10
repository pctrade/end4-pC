import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    readonly property bool showUnreadCount: root.barConfig.indicators.notifications.showUnreadCount
    readonly property bool isDi: Config.barHasWidget(root.barScreenName, "dynamicIsland") && root.barConfig.dynamicIsland.rightWidget === "systemIcons"

    text: Notifications.silent ? "notifications_paused" : "notifications"
    iconSize: Appearance.font.pixelSize.larger
    readonly property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    readonly property bool glassy: Config.options.background.widgets.glass.enable
    color: root.contentColorOverridden ? root.contentColor : (root.isDi ? Appearance.colors.colOnLayer1 : (root.isMaterial ? (root.glassy ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnPrimary) : Appearance.colors.colOnLayer1))

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
        color: root.isDi ? Appearance.colors.colOnLayer1 : (root.isMaterial ? (root.glassy ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnPrimary) : Appearance.colors.colOnLayer0)
        z: 1

        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) : 8
        implicitWidth: implicitHeight

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.isDi ? Appearance.colors.colOnPrimary : (root.isMaterial ? (root.glassy ? Appearance.colors.colLayer0 : Appearance.colors.colPrimary) : Appearance.colors.colLayer0)
            text: Notifications.unread
        }
    }
}
