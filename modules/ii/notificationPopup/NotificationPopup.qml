import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        property string position: {
            const raw = Config.options.notifications.position ?? "top_right"
            if (raw === "top") return "top_right"
            if (raw === "bottom") return "bottom_right"
            return raw
        }
        property bool isTop: position.startsWith("top")
        property bool isBottom: position.startsWith("bottom")
        property bool isCenter: position.endsWith("center")
        property bool isLeft: position.endsWith("left")
        property bool isRight: position.endsWith("right")

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth

        NotificationListView {
            id: listview
            anchors.leftMargin: root.isLeft ? 4 : 0
            anchors.rightMargin: root.isRight ? 4 : 0
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            width: Appearance.sizes.notificationPopupWidth
            popup: true
            verticalLayoutDirection: root.isBottom ? ListView.BottomToTop : ListView.TopToBottom

            states: [
                State {
                    name: "top_left"
                    when: root.position === "top_left"
                    AnchorChanges {
                        target: listview
                        anchors.left: parent.left
                        anchors.right: undefined
                        anchors.horizontalCenter: undefined
                        anchors.top: parent.top
                        anchors.bottom: undefined
                    }
                },
                State {
                    name: "top_center"
                    when: root.position === "top_center"
                    AnchorChanges {
                        target: listview
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: undefined
                    }
                },
                State {
                    name: "top_right"
                    when: root.position === "top_right"
                    AnchorChanges {
                        target: listview
                        anchors.left: undefined
                        anchors.right: parent.right
                        anchors.horizontalCenter: undefined
                        anchors.top: parent.top
                        anchors.bottom: undefined
                    }
                },
                State {
                    name: "bottom_left"
                    when: root.position === "bottom_left"
                    AnchorChanges {
                        target: listview
                        anchors.left: parent.left
                        anchors.right: undefined
                        anchors.horizontalCenter: undefined
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                    }
                },
                State {
                    name: "bottom_center"
                    when: root.position === "bottom_center"
                    AnchorChanges {
                        target: listview
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                    }
                },
                State {
                    name: "bottom_right"
                    when: root.position === "bottom_right"
                    AnchorChanges {
                        target: listview
                        anchors.left: undefined
                        anchors.right: parent.right
                        anchors.horizontalCenter: undefined
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                    }
                }
            ]
        }
    }
}