import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var vpnConnection
    readonly property bool isThisConnecting: Vpn.isConnecting && (Vpn.connectingUuid === (vpnConnection ? vpnConnection.uuid : ""))
    readonly property bool isActive: (vpnConnection && vpnConnection.active) ? true : false
    enabled: !Vpn.isConnecting || isThisConnecting

    active: isActive
    onClicked: {
        if (isActive) {
            Vpn.disconnectVpn(vpnConnection.uuid);
        } else if (isThisConnecting) {
            Vpn.cancelConnect();
        } else {
            Vpn.connectVpn(vpnConnection.uuid, vpnConnection.name);
        }
    }

    readonly property bool needsAuth: Vpn.isAuthRequired(vpnConnection ? vpnConnection.uuid : "")
    altAction: () => {
        if (vpnConnection && vpnConnection.uuid) {
            Vpn.connectVpnInteractive(vpnConnection.uuid, vpnConnection.name);
        }
    }

    readonly property string typeLabel: {
        const t = ((root.vpnConnection && root.vpnConnection.type) || "").toLowerCase();
        if (t === "wireguard") return "WireGuard";
        if (t === "vpn") return "VPN";
        if (t === "ipsec") return "IPsec";
        return t ? t.toUpperCase() : "VPN";
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            spacing: 12

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                text: root.isThisConnecting ? "sync" : "vpn_key"
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                fill: root.isActive ? 1 : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    font.weight: root.isActive ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    text: (root.vpnConnection && root.vpnConnection.name) ? root.vpnConnection.name : Translation.tr("Unknown")
                    textFormat: Text.PlainText
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: {
                        if (root.isThisConnecting) return Translation.tr("Connecting...");
                        if (root.isActive) return Translation.tr("Connected") + ` • ${root.typeLabel}`;
                        if (root.needsAuth) return Translation.tr("Credentials required • %1").arg(root.typeLabel);
                        return root.typeLabel;
                    }
                }
            }

            DialogButton {
                visible: root.needsAuth && !root.isActive && !root.isThisConnecting
                buttonText: Translation.tr("Log in")
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive
                colText: Appearance.colors.colOnPrimary
                onClicked: {
                    if (root.vpnConnection && root.vpnConnection.uuid) {
                        Vpn.connectVpnInteractive(root.vpnConnection.uuid, root.vpnConnection.name);
                    }
                }
            }

            MaterialSymbol {
                visible: root.isActive || root.isThisConnecting
                text: root.isThisConnecting ? "settings_ethernet" : "check"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    StyledToolTip {
        text: root.isActive
            ? Translation.tr("Click to disconnect")
            : (root.isThisConnecting
                ? Translation.tr("Connecting... Click to cancel")
                : (root.needsAuth
                    ? Translation.tr("Authentication required. Click to authenticate.")
                    : Translation.tr("Click to connect")))
    }
}
