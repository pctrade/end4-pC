import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : flow.implicitWidth + 4
    implicitHeight: root.vertical ? flow.implicitHeight + 4 : 32

    MouseArea {
        anchors.fill: parent
        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: isMaterial ? 2 : root.vertical ? 6 : 10

        Revealer {
            reveal: true
            Item {
                id: volumeItem
                implicitWidth: root.vertical ? volumeColLayout.implicitWidth : volumeRowLayout.implicitWidth
                implicitHeight: root.vertical ? volumeColLayout.implicitHeight : volumeRowLayout.implicitHeight
                property bool hovered: false

                RowLayout {
                    id: volumeRowLayout
                    visible: !root.vertical
                    anchors.centerIn: parent
                    spacing: 3

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            if (Audio.sink?.audio?.muted) return "volume_off"
                            return "volume_up";
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        visible: volumeItem.hovered
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.features: { "tnum": 1 }
                        color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}`
                    }
                }

                ColumnLayout {
                    id: volumeColLayout
                    visible: root.vertical
                    anchors.centerIn: parent
                    spacing: 1

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (Audio.sink?.audio?.muted) return "volume_off";
                            return "volume_up";
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: volumeItem.hovered
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}`
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onEntered: volumeItem.hovered = true
                    onExited: volumeItem.hovered = false
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) {
                            Audio.incrementVolume();
                        } else if (wheel.angleDelta.y < 0) {
                            Audio.decrementVolume();
                        }
                    }
                    onPressed: mouse => {
                        GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                    }
                }
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            MaterialSymbol {
                text: "mic_off"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        Loader {
            source: "HyprlandXkbIndicator.qml"
            onLoaded: item.color = root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            text: Network.materialSymbol
            iconSize: Appearance.font.pixelSize.larger
            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            visible: BluetoothStatus.available
            text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            iconSize: Appearance.font.pixelSize.larger
            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        Loader {
            id: notifLoader
            active: Notifications.silent || Notifications.unread > 0
            visible: active
            width: active ? item?.implicitWidth ?? 0 : 0
            height: active ? item?.implicitHeight ?? 0 : 0
            source: "NotificationUnreadCount.qml"
        }
    }
}
