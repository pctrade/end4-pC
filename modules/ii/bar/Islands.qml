import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    anchors {
        fill: parent
        topMargin: 3
    }

    Row {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: Appearance.sizes.hyprlandGapsOut + 2
        }
        spacing: 4

        BarIsland {
            LeftSidebarButton {}
            Rectangle {
                width: 1
                Layout.leftMargin: -4
                Layout.rightMargin: -3
                height: 20
                color: Appearance.colors.colSecondaryContainer
                opacity: 0.5
            }
            Workspaces {}
        }

        BarIsland {
            padding: 20
            visible: SystemTray.items.values.length > 0
            SysTray {}
        }

        BarIsland {
            padding: 4
            visible: Config.options.bar.weather.enable
            WeatherBar {}
        }


    }

    BarIsland {
        anchors.centerIn: parent
        padding: 16
        Media {
            Layout.maximumWidth: 300
        }
    }

    Row {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: Appearance.sizes.hyprlandGapsOut + 2
        }
        spacing: 4
        layoutDirection: Qt.RightToLeft

        BarIsland {
            padding: 0
            RippleButton {
                id: indicatorsIsland
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                contentItem: RowLayout {
                    id: indicatorsRowLayout
                    property real realSpacing: 10
                    spacing: 0

                    Revealer {
                        reveal: true
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Layout.leftMargin: 5
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        color: Appearance.colors.colOnLayer1
                    }
                    MaterialSymbol {
                        Layout.rightMargin: indicatorsRowLayout.realSpacing - 2
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    MaterialSymbol {
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    Revealer {
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing - 2 : 0
                        Layout.leftMargin: reveal ? 4 : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                }
            } 
        }

        BarIsland {
            padding: 26
            ClockWidget {}
        }

        BarIsland {
            padding: 8
            UtilButtons {}
        }
    }
}