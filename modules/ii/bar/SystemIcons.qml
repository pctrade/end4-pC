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
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    property bool isDi: GlobalStates.dynamicIslandEnabled && Config.options.bar.dynamicIsland.rightWidget === "systemIcons" 

    readonly property color iconColor: root.contentColorOverridden ? root.contentColor : (root.isDi ? Appearance.colors.colOnLayer1 : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))

    implicitWidth: root.vertical ? 32 : flow.implicitWidth + (root.isMaterial ? 12 : 4)
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
            vertical: root.vertical
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
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
                        color: root.iconColor
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        visible: false
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.features: { "tnum": 1 }
                        color: root.iconColor
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
                        color: root.iconColor
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: false
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: root.iconColor
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
            vertical: root.vertical
            MaterialSymbol {
                text: "mic_off"
                iconSize: Appearance.font.pixelSize.larger
                color: root.iconColor
            }
        }
        Loader {
            source: "HyprlandXkbIndicator.qml"
            onLoaded: item.color = root.iconColor
        }
        MaterialSymbol {
            text: Network.materialSymbol
            iconSize: Appearance.font.pixelSize.larger
            color: root.iconColor
        }
        Revealer {
            reveal: Vpn.isConnected
            vertical: root.vertical
            MaterialSymbol {
                text: "vpn_key"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        MaterialSymbol {
            visible: BluetoothStatus.available
            text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            iconSize: Appearance.font.pixelSize.larger
            color: root.iconColor
        }
        Repeater {
            model: ScriptModel {
                values: PeripheralBattery.lowDevices
                objectProp: "nativePath"
            }
            delegate: MaterialSymbol {
                id: peripheralIcon
                required property var modelData
                readonly property bool critical: PeripheralBattery.isCritical(modelData)
                property bool hovered: peripheralMouse.containsMouse
                text: {
                    switch (modelData.type) {
                    case UPowerDeviceType.Mouse: return "mouse";
                    case UPowerDeviceType.Keyboard: return "keyboard";
                    case UPowerDeviceType.Headset:
                    case UPowerDeviceType.Headphones: return "headphones";
                    case UPowerDeviceType.GamingInput: return "sports_esports";
                    case UPowerDeviceType.Phone: return "smartphone";
                    default: return "battery_alert";
                    }
                }
                iconSize: Appearance.font.pixelSize.larger
                color: critical ? Appearance.colors.colError : root.iconColor
                fill: 1

                MouseArea {
                    id: peripheralMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                StyledToolTip {
                    text: `${modelData.model || Translation.tr("Device")} • ${Math.round(modelData.percentage * 100)}%`
                }
            }
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