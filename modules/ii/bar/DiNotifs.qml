import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: diNotifsRoot
    required property Item di
    anchors.fill: parent

    readonly property var notif: root.latestNotification

    Image {
        id: notifIcon
        width: 20
        height: 20
        anchors {
            left: parent.left
            leftMargin: root.isMaterial ? 4 : 12
            verticalCenter: parent.verticalCenter
        }
        source: Quickshell.iconPath(notif?.appIcon ?? "", "notification-symbolic")
        visible: (notif?.appIcon ?? "") !== ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    MaterialShapeWrappedMaterialSymbol {
        id: notifMaterialIcon
        anchors {
            left: parent.left
            leftMargin: root.isMaterial ? 0 : 4
            verticalCenter: parent.verticalCenter
        }
        wrappedShape: MaterialShape.Shape.Cookie12Sided
        color: Appearance.colors.colPrimary
        colSymbol: Appearance.colors.colOnPrimary
        text: "notifications"
        iconSize: root.isMaterial ? 20 : 14
        fill: 1
        padding: 4
        visible: (notif?.appIcon ?? "") === ""
    }

    ColumnLayout {
        id: notifTextColumn
        anchors {
            left: notifIcon.right
            leftMargin: root.isMaterial ? 14 : 2
            verticalCenter: parent.verticalCenter
            right: nowLabel.left
            rightMargin: 8
        }
        spacing: root.isMaterial ? -2 : -4

        StyledText {
            Layout.fillWidth: true
            text: (notif?.summary ?? "").replace(/\n/g, " ")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
        StyledText {
            Layout.fillWidth: true
            text: (notif?.body ?? "").replace(/\n/g, " ")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
    }

    StyledText {
        id: nowLabel
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 10
            topMargin: 8
        }
        text: DateTime.time
        font.pixelSize: Appearance.font.pixelSize.small - 2
        color: Appearance.colors.colOnLayer0
        opacity: 0.8
    }
}