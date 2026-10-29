import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property bool vertical: false
    readonly property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : avatar.width + (root.isMaterial ? 0 : 8)
    implicitHeight: vertical ? avatar.height + 8 : Appearance.sizes.barHeight

    UserAvatar {
        id: avatar
        anchors.centerIn: parent
        width: root.isMaterial ? 32 : 24
        height: root.isMaterial ? 32 : 24
        iconSize: Appearance.font.pixelSize.larger
        scale: clickArea.pressed ? 0.92 : (clickArea.containsMouse ? 1.1 : 1)

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popup.active && popup.item) popup.item.close()
            else popup.active = true
        }
    }

    Loader {
        id: popup
        active: false
        sourceComponent: AvatarPopup {
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: root.barConfig.vertical
                    ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
                    : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
                edges: root.barConfig.vertical
                    ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
                    : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
            }
            onPopupClosed: popup.active = false
        }
    }
}
