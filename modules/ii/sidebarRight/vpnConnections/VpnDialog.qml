import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    WindowDialogTitle {
        text: Translation.tr("VPN Connections")
    }
    WindowDialogSeparator {
        visible: !Vpn.isConnecting
    }
    StyledIndeterminateProgressBar {
        visible: Vpn.isConnecting
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true

        ListView {
            id: vpnListView
            anchors.fill: parent
            anchors.topMargin: -15
            anchors.bottomMargin: -16
            anchors.leftMargin: -Appearance.rounding.large
            anchors.rightMargin: -Appearance.rounding.large

            clip: true
            spacing: 0
            visible: Vpn.friendlyVpnList.length > 0

            model: ScriptModel {
                values: Vpn.friendlyVpnList
            }
            delegate: VpnConnectionItem {
                required property var modelData
                vpnConnection: modelData
                width: vpnListView.width
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: Vpn.friendlyVpnList.length === 0
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 48
                text: "vpn_key_off"
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
                text: Translation.tr("No VPN connections configured")
            }

            DialogButton {
                Layout.alignment: Qt.AlignHCenter
                buttonText: Translation.tr("Network Settings")
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", `${Config.options.apps.network}`]);
                    GlobalStates.sidebarRightOpen = false;
                }
            }
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.network}`]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        DialogButton {
            visible: Vpn.isConnected
            buttonText: Translation.tr("Disconnect")
            colBackground: Appearance.colors.colError
            colBackgroundHover: Appearance.colors.colErrorHover
            colRipple: Appearance.colors.colErrorActive
            colText: Appearance.colors.colOnError
            onClicked: Vpn.disconnectAll()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
